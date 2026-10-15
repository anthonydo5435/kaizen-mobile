import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sparrowkaizen/core/constants/app_strings.dart';
import 'package:sparrowkaizen/core/managers/app_manager.dart';
import 'package:sparrowkaizen/core/network/api_endpoints.dart';
import 'package:sparrowkaizen/core/network/api_processor.dart';
import 'package:sparrowkaizen/core/preference/app_preference.dart';
import 'package:sparrowkaizen/core/widgets/app_back_button.dart';
import 'package:sparrowkaizen/features/compliance/presentation/pages/training/compliance_full_screen_video_view.dart';
import 'package:sparrowkaizen/features/compliance/presentation/widgets/compliance_video_player.dart';
import 'package:sparrowkaizen/features/login/domain/entities/user.dart';
import 'package:sparrowkaizen/features/training/domain/entities/seat_description_training_route.dart';
import 'package:sparrowkaizen/features/training/presentation/controllers/training_module_controller.dart';
import 'package:sparrowkaizen/features/training/presentation/pages/edit_training_screen.dart';
import 'package:sparrowkaizen/features/training/presentation/widgets/training_sop_document_view.dart';
import 'package:video_player/video_player.dart';
// ignore: depend_on_referenced_packages
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

import '../../fixtures/tiptap_sop_fixture.dart';

void main() {
  const portrait = Size(390, 844);
  const landscape = Size(844, 390);
  const rotationAllowed = [
    'DeviceOrientation.portraitUp',
    'DeviceOrientation.landscapeLeft',
    'DeviceOrientation.landscapeRight',
  ];
  final orientations = <List<dynamic>>[];
  final fullscreen = <bool>[];
  final writes = <http.Request>[];
  bool physicalDevicePortrait = true;
  Completer<bool>? portraitWait;
  int portraitWaitRequests = 0;
  int portraitWaitCancellations = 0;
  late VideoPlayerPlatform originalPlatform;
  late _VideoPlatform platform;
  late Directory directory;
  late File videoFile;
  late TiptapSopFixture sop;
  late _NavigationObserver navigationObserver;
  final client = MockClient((request) async {
    if (request.method != 'GET') {
      writes.add(request);
      return http.Response('', 204);
    }
    final path = request.url.path;
    Object response;
    if (path.endsWith(ApiEndPoints.seatDescriptionTrainingModules('description'))) {
      response = [
        {'uuid': 'lesson', 'title': 'Lesson'},
      ];
    } else if (path.endsWith(ApiEndPoints.trainingModuleDetail('lesson'))) {
      response = {
        'uuid': 'lesson',
        'title': 'Lesson',
        'training_video': {'uuid': 'video', 'url': 'http://[', 'transcript': '[00:00] Procedure'},
      };
    } else if (path.endsWith(ApiEndPoints.trainingModuleDocument('lesson'))) {
      response = {'uuid': 'document', 'text': '<p>Procedure</p>'};
    } else if (path.endsWith(ApiEndPoints.trainingModuleQuestions('lesson'))) {
      response = <Object>[];
    } else if (path.endsWith(ApiEndPoints.lmsPublicLink('description'))) {
      response = {'active': false};
    } else {
      throw StateError('Unexpected request: $path');
    }
    return http.Response(jsonEncode(response), 200);
  });
  tearDownAll(client.close);

  setUp(() async {
    orientations.clear();
    fullscreen.clear();
    writes.clear();
    physicalDevicePortrait = true;
    portraitWait = null;
    portraitWaitRequests = 0;
    portraitWaitCancellations = 0;
    SharedPreferences.setMockInitialValues({});
    await AppPreference.init();
    await AppPreference.setAuthToken('test-token');
    ApiCallExecutor.clearGetCache();
    AppManager.instance.resetSessionState();
    AppManager.instance.updateCurrentUser(User(isOwner: true, uuid: 'owner'));
    originalPlatform = VideoPlayerPlatform.instance;
    platform = _VideoPlatform();
    VideoPlayerPlatform.instance = platform;
    directory = Directory.systemTemp.createTempSync('training-orientation-');
    videoFile = File('${directory.path}/video.mp4')..writeAsBytesSync([0]);
    sop = TiptapSopFixture();
    navigationObserver = _NavigationObserver();
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'SystemChrome.setPreferredOrientations') {
        orientations.add(call.arguments as List<dynamic>);
      }
      return null;
    });
    messenger.setMockMethodCallHandler(const MethodChannel('kaizenteams/video_fullscreen'), (
      call,
    ) async {
      if (call.method == 'waitForPortrait') {
        portraitWaitRequests += 1;
        if (physicalDevicePortrait) return true;
        portraitWait = Completer<bool>();
        return portraitWait!.future;
      }
      if (call.method == 'cancelWaitForPortrait') {
        portraitWaitCancellations += 1;
        if (portraitWait?.isCompleted == false) portraitWait!.complete(false);
        portraitWait = null;
        return null;
      }
      fullscreen.add((call.arguments as Map)['enabled'] as bool);
      return null;
    });
  });

  tearDown(() {
    VideoPlayerPlatform.instance = originalPlatform;
    directory.deleteSync(recursive: true);
    AppManager.instance.resetSessionState();
    ApiCallExecutor.clearGetCache();
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, null);
    messenger.setMockMethodCallHandler(const MethodChannel('kaizenteams/video_fullscreen'), null);
  });

  Future<VideoPlayerController> openTraining(
    WidgetTester tester, {
    Future<void> Function()? beforeInitialization,
  }) async {
    tester.view.physicalSize = portrait;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(minutes: 3));
      await tester.pump();
    });
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AppManager>.value(value: AppManager.instance),
          Provider<TrainingSopEditorFactory>.value(value: sop.create),
        ],
        child: MaterialApp(
          navigatorObservers: [navigationObserver],
          home: const EditTrainingScreen(
            trainingRoute: SeatDescriptionTrainingRoute(
              job: 'seat',
              category: 'category',
              description: 'description',
            ),
            canManageTraining: true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(orientations.last, rotationAllowed);
    final module = tester
        .element(find.byType(ComplianceVideoPlayer))
        .read<TrainingModuleController>();
    module.applyBackgroundUploadedVideo(
      moduleId: 'lesson',
      video: module.selectedModuleDetail!.trainingVideo!,
      localVideoPath: videoFile.path,
    );
    await tester.pump();
    await beforeInitialization?.call();
    for (var attempt = 0; attempt < 100 && !platform.initialized.isCompleted; attempt++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump();
    }
    expect(platform.initialized.isCompleted, isTrue);
    await tester.pump();
    await tester.pump();
    return tester.widget<VideoPlayer>(find.byType(VideoPlayer)).controller;
  }

  Future<void> rotate(WidgetTester tester, Size size) async {
    physicalDevicePortrait = size.height > size.width;
    if (physicalDevicePortrait && portraitWait?.isCompleted == false) {
      portraitWait!.complete(true);
      portraitWait = null;
    }
    tester.view.physicalSize = size;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
  }

  Future<void> closeTraining(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(minutes: 3));
    await tester.pump();
    expect(orientations.last, ['DeviceOrientation.portraitUp']);
    expect(tester.takeException(), isNull);
  }

  for (final playing in [false, true]) {
    testWidgets(
      'Video rotation fills the current tab without navigation or remounting (playing: $playing)',
      (tester) async {
        await http.runWithClient(() async {
          final controller = await openTraining(tester);
          final playerState = tester.state(find.byType(ComplianceVideoPlayer));
          final videoState = tester.state(find.byType(VideoPlayer));
          final route = ModalRoute.of(tester.element(find.byType(ComplianceVideoPlayer)));
          final initialPushes = navigationObserver.pushes;
          await tester.runAsync(() async {
            await controller.seekTo(const Duration(seconds: 12));
            if (playing) await controller.play();
          });
          for (var repeat = 0; repeat < 2; repeat++) {
            await rotate(tester, landscape);
            final view = tester.widget<ComplianceFullScreenVideoView>(
              find.byType(ComplianceFullScreenVideoView),
            );
            expect(view.controller, same(controller));
            expect(view.isEmbedded, isTrue);
            expect(navigationObserver.pushes, initialPushes);
            expect(
              ModalRoute.of(tester.element(find.byType(ComplianceFullScreenVideoView))),
              same(route),
            );
            expect(tester.state(find.byType(ComplianceVideoPlayer)), same(playerState));
            expect(tester.state(find.byType(VideoPlayer)), same(videoState));
            expect(find.byType(TrainingTabs), findsNothing);
            expect(find.text(AppStrings.trainingSummaryLabel), findsNothing);
            expect(
              tester.getRect(find.byKey(const ValueKey('training-inline-fullscreen-video'))),
              Offset.zero & landscape,
            );
            expect(controller.value.position, const Duration(seconds: 12));
            expect(controller.value.isPlaying, playing);
            expect(tester.getSize(find.byType(Scaffold).last), landscape);
            await rotate(tester, portrait);
            expect(find.byType(ComplianceFullScreenVideoView), findsNothing);
            expect(find.byType(ComplianceVideoPlayer), findsOneWidget);
            expect(tester.state(find.byType(ComplianceVideoPlayer)), same(playerState));
            expect(tester.state(find.byType(VideoPlayer)), same(videoState));
            expect(
              tester.widget<TrainingTabs>(find.byType(TrainingTabs)).navigation.selectedIndex,
              0,
            );
            expect(orientations.last, rotationAllowed);
            expect(controller.value.position, const Duration(seconds: 12));
            expect(controller.value.isPlaying, playing);
          }
          expect(fullscreen, [true, false, true, false]);
          expect(platform.creations, 1);
          expect(platform.seeks, [const Duration(seconds: 12)]);
          await closeTraining(tester);
        }, () => client);
      },
    );
  }

  testWidgets('inline fullscreen system back requests portrait without changing routes', (
    tester,
  ) async {
    await http.runWithClient(() async {
      await openTraining(tester);
      final initialPushes = navigationObserver.pushes;
      await rotate(tester, landscape);
      expect(find.byType(AppBackButton), findsNothing);
      expect(find.byKey(const ValueKey('video-exit-fullscreen-button')), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      expect(orientations.last, ['DeviceOrientation.portraitUp']);
      expect(navigationObserver.pushes, initialPushes);
      expect(fullscreen, [true]);
      await rotate(tester, portrait);
      expect(find.byType(ComplianceFullScreenVideoView), findsNothing);
      expect(fullscreen, [true, false]);
      expect(orientations.last, rotationAllowed);
      await rotate(tester, landscape);
      expect(find.byType(ComplianceFullScreenVideoView), findsOneWidget);
      await rotate(tester, portrait);
      await closeTraining(tester);
    }, () => client);
  });

  testWidgets('fullscreen rejects tab swipes and normal portrait restores them', (tester) async {
    await http.runWithClient(() async {
      final controller = await openTraining(tester);
      final videoState = tester.state(find.byType(VideoPlayer));
      final pageController = tester.widget<PageView>(find.byType(PageView)).controller!;
      await rotate(tester, landscape);
      for (final direction in [-1.0, 1.0]) {
        await tester.dragFrom(const Offset(422, 120), Offset(direction * 500, 0));
        await tester.pumpAndSettle();
        expect(pageController.page, 0);
        expect(
          tester
              .widget<TrainingTabs>(find.byType(TrainingTabs, skipOffstage: false))
              .navigation
              .selectedIndex,
          0,
        );
        expect(find.byKey(const ValueKey('training-inline-fullscreen-video')), findsOneWidget);
        expect(tester.state(find.byType(VideoPlayer)), same(videoState));
        expect(tester.widget<VideoPlayer>(find.byType(VideoPlayer)).controller, same(controller));
      }
      await rotate(tester, portrait);
      await tester.dragFrom(const Offset(280, 280), const Offset(-300, 0));
      await tester.pumpAndSettle();
      expect(tester.widget<TrainingTabs>(find.byType(TrainingTabs)).navigation.selectedIndex, 1);
      expect(find.byType(TrainingSopDocumentView), findsOneWidget);
      await closeTraining(tester);
    }, () => client);
  });

  for (final playing in [false, true]) {
    testWidgets(
      'white exit icon waits for physical portrait and allows the next landscape (playing: $playing)',
      (tester) async {
        await http.runWithClient(() async {
          final controller = await openTraining(tester);
          final videoState = tester.state(find.byType(VideoPlayer));
          final initialPushes = navigationObserver.pushes;
          await tester.runAsync(() async {
            await controller.seekTo(const Duration(seconds: 12));
            if (playing) await controller.play();
          });
          for (var repeat = 0; repeat < 2; repeat++) {
            await rotate(tester, landscape);
            final exit = find.byKey(const ValueKey('video-exit-fullscreen-button'));
            final icon = tester.widget<Icon>(
              find.descendant(of: exit, matching: find.byType(Icon)),
            );
            expect(icon.icon, Icons.fullscreen_exit_rounded);
            expect(icon.color, Colors.white);
            expect(tester.getCenter(exit).dx, greaterThan(landscape.width * 0.8));
            if (playing) {
              expect(exit.hitTestable(), findsNothing);
              await tester.tapAt(const Offset(80, 80));
              await tester.pump();
              expect(controller.value.isPlaying, isFalse);
              await tester.tapAt(const Offset(80, 80));
              await tester.pump();
              expect(controller.value.isPlaying, isTrue);
            }
            expect(exit.hitTestable(), findsOneWidget);
            await tester.tap(exit);
            await tester.pumpAndSettle();
            expect(orientations.last, ['DeviceOrientation.portraitUp']);
            expect(portraitWait?.isCompleted, isFalse);

            // The OS rotates the interface while the phone is still held sideways.
            tester.view.physicalSize = portrait;
            await tester.pumpAndSettle();
            await tester.pump(const Duration(seconds: 1));
            expect(find.byType(ComplianceFullScreenVideoView), findsNothing);
            expect(find.byType(TrainingTabs), findsOneWidget);
            expect(orientations.last, ['DeviceOrientation.portraitUp']);
            expect(physicalDevicePortrait, isFalse);
            expect(controller.value.position, const Duration(seconds: 12));
            expect(controller.value.isPlaying, playing);
            expect(tester.state(find.byType(VideoPlayer)), same(videoState));

            // Only a physical portrait sensor event releases that temporary lock.
            await rotate(tester, portrait);
            expect(orientations.last, rotationAllowed);
            expect(navigationObserver.pushes, initialPushes);
          }
          expect(portraitWaitRequests, 2);
          await rotate(tester, landscape);
          expect(find.byKey(const ValueKey('training-inline-fullscreen-video')), findsOneWidget);
          expect(tester.state(find.byType(VideoPlayer)), same(videoState));
          expect(platform.creations, 1);
          expect(platform.seeks, [const Duration(seconds: 12)]);
          await rotate(tester, portrait);
          await closeTraining(tester);
        }, () => client);
      },
    );
  }

  testWidgets('leaving Training cancels a pending physical portrait wait', (tester) async {
    await http.runWithClient(() async {
      await openTraining(tester);
      await rotate(tester, landscape);
      await tester.tap(find.byKey(const ValueKey('video-exit-fullscreen-button')));
      await tester.pumpAndSettle();
      expect(portraitWait?.isCompleted, isFalse);
      await closeTraining(tester);
      expect(portraitWaitCancellations, 1);
      expect(portraitWait, isNull);
    }, () => client);
  });

  testWidgets('manual portrait fullscreen returns to the Video tab after a landscape rotation', (
    tester,
  ) async {
    await http.runWithClient(() async {
      final controller = await openTraining(tester);
      await tester.tap(find.byKey(const ValueKey('video-fullscreen-button')));
      await tester.pumpAndSettle();
      expect(find.byType(ComplianceFullScreenVideoView), findsOneWidget);
      await rotate(tester, landscape);
      expect(fullscreen, [true]);
      await rotate(tester, portrait);
      expect(find.byType(ComplianceFullScreenVideoView), findsNothing);
      expect(tester.widget<VideoPlayer>(find.byType(VideoPlayer)).controller, same(controller));
      expect(fullscreen, [true, false]);
      await closeTraining(tester);
    }, () => client);
  });

  testWidgets('rotation during initialization stays in the current Video tab', (tester) async {
    platform.holdInitialization = true;
    await http.runWithClient(() async {
      await openTraining(
        tester,
        beforeInitialization: () async {
          tester.view.physicalSize = landscape;
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 350));
          expect(find.byKey(const ValueKey('training-inline-fullscreen-video')), findsOneWidget);
          expect(navigationObserver.pushes, 1);
          tester.view.physicalSize = portrait;
          await tester.pump();
          platform.sendInitialized();
        },
      );
      await tester.pumpAndSettle();
      expect(find.byType(ComplianceFullScreenVideoView), findsNothing);
      expect(fullscreen, [true, false]);
      await closeTraining(tester);
    }, () => client);
  });

  testWidgets('SOP rotates in place, preserves edits, and other tabs restore portrait', (
    tester,
  ) async {
    await http.runWithClient(() async {
      await openTraining(tester);
      await tester.tap(_tab(AppStrings.trainingSopTab));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump();
      expect(find.byType(TrainingSopDocumentView), findsOneWidget);
      final editor = sop.editors.single;
      await tester.tap(find.byTooltip(AppStrings.trainingBoldAction));
      await tester.pump();
      await rotate(tester, landscape);
      expect(find.byType(ComplianceFullScreenVideoView), findsNothing);
      expect(tester.getSize(find.byType(Scaffold).first), landscape);
      expect(tester.widget<TrainingTabs>(find.byType(TrainingTabs)).navigation.selectedIndex, 1);
      expect(sop.editors.single, same(editor));
      expect(editor.disposed, isFalse);
      expect(editor.html, '<p><strong>Procedure</strong></p>');
      expect(writes, hasLength(1));
      await rotate(tester, portrait);
      await tester.tap(_tab(AppStrings.trainingQuizTab));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      expect(orientations.last, ['DeviceOrientation.portraitUp']);
      await tester.tap(_tab(AppStrings.trainingVideoTab));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      expect(orientations.last, rotationAllowed);
      expect(fullscreen, isEmpty);
      await closeTraining(tester);
    }, () => client);
  });
}

Finder _tab(String label) =>
    find.descendant(of: find.byType(TrainingTabs), matching: find.text(label));

class _VideoPlatform extends VideoPlayerPlatform {
  final initialized = Completer<void>();
  final events = StreamController<VideoEvent>();
  Duration position = Duration.zero;
  bool holdInitialization = false;
  int creations = 0;
  final seeks = <Duration>[];

  void sendInitialized() {
    events.add(
      VideoEvent(
        eventType: VideoEventType.initialized,
        duration: const Duration(minutes: 1),
        size: const Size(640, 360),
      ),
    );
  }

  @override
  Future<void> init() async {}
  @override
  Future<int> createWithOptions(VideoCreationOptions options) async {
    creations += 1;
    if (!holdInitialization) sendInitialized();
    return 1;
  }

  @override
  Stream<VideoEvent> videoEventsFor(int playerId) => events.stream;
  @override
  Future<void> setLooping(int playerId, bool looping) async {}
  @override
  Future<void> setVolume(int playerId, double volume) async {
    if (!initialized.isCompleted) initialized.complete();
  }

  @override
  Future<void> setPlaybackSpeed(int playerId, double speed) async {}
  @override
  Future<void> play(int playerId) async {}
  @override
  Future<void> pause(int playerId) async {}
  @override
  Future<void> seekTo(int playerId, Duration value) async {
    seeks.add(value);
    position = value;
  }

  @override
  Future<Duration> getPosition(int playerId) async => position;
  @override
  Widget buildViewWithOptions(VideoViewOptions options) => const SizedBox();
  @override
  Future<void> dispose(int playerId) async => events.close();
}

class _NavigationObserver extends NavigatorObserver {
  int pushes = 0;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushes += 1;
  }
}
