import 'dart:async';
import 'dart:convert';

import 'package:cached_video_player_plus/cached_video_player_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
// Use the existing video cache contract without touching native cache storage.
// ignore: depend_on_referenced_packages
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
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
import 'package:sparrowkaizen/features/compliance/presentation/pages/training/compliance_training_screen.dart';
import 'package:sparrowkaizen/features/compliance/presentation/providers/compliance_training_controller.dart';
import 'package:sparrowkaizen/features/compliance/presentation/providers/compliance_video_controller.dart';
import 'package:sparrowkaizen/features/compliance/presentation/widgets/compliance_video_player.dart';
import 'package:sparrowkaizen/features/login/domain/entities/user.dart';
import 'package:video_player/video_player.dart';
// ignore: depend_on_referenced_packages
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

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
  bool physicalPortrait = true;
  bool hasVideo = true;
  int lessonSequence = 0;
  Completer<bool>? portraitWait;
  int portraitWaitRequests = 0;
  int portraitWaitCancellations = 0;
  late VideoPlayerPlatform originalPlatform;
  late _VideoPlatform platform;
  late _NavigationObserver navigation;

  Map<String, Object?> module() => {
    'uuid': 'module',
    'title': 'LTC Lesson',
    'training_video': hasVideo
        ? {
            'uuid': 'video',
            'url': 'https://example.test/ltc-$lessonSequence.mp4',
            'transcript': '[00:00 --> 01:00] Procedure caption',
            'duration': 60,
          }
        : null,
    'training_document': '<p>LTC document</p>',
  };

  final client = MockClient((request) async {
    if (request.method != 'GET') {
      writes.add(request);
      return http.Response(
        jsonEncode({'uuid': 'attempt', 'time_spent': 0}),
        200,
      );
    }
    final path = request.url.path;
    Object body;
    if (path.endsWith(
      ApiEndPoints.learningTrackAssignmentDetail('assignment'),
    )) {
      body = {
        'name': 'Track',
        'items': [
          {'uuid': 'item', 'training_module': module()},
        ],
      };
    } else if (path.endsWith(
      '${ApiEndPoints.learningTrackAssignmentDetail('assignment')}items/item',
    )) {
      body = {'uuid': 'item', 'position': 1, 'training_module': module()};
    } else if (path.endsWith(
      ApiEndPoints.complianceQuizQuestions(
        trackAssignmentUuid: 'assignment',
        trainingModuleUuid: 'module',
      ),
    )) {
      body = {'questions': [], 'time_spent': 0};
    } else if (path.endsWith(
      ApiEndPoints.complianceQuizResult(
        trackAssignmentUuid: 'assignment',
        trainingModuleUuid: 'module',
      ),
    )) {
      body = {'uuid': 'result', 'is_passed': false};
    } else {
      throw StateError('Unexpected request: $path');
    }
    return http.Response(jsonEncode(body), 200);
  });
  tearDownAll(client.close);

  setUp(() async {
    lessonSequence++;
    hasVideo = true;
    physicalPortrait = true;
    portraitWait = null;
    portraitWaitRequests = 0;
    portraitWaitCancellations = 0;
    orientations.clear();
    fullscreen.clear();
    writes.clear();
    SharedPreferences.setMockInitialValues({});
    await AppPreference.init();
    await AppPreference.setAuthToken('test-token');
    ApiCallExecutor.clearGetCache();
    AppManager.instance.resetSessionState();
    AppManager.instance.updateCurrentUser(User(uuid: 'learner'));
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    originalPlatform = VideoPlayerPlatform.instance;
    CachedVideoPlayerPlus.cacheManager = _EmptyVideoCache();
    platform = _VideoPlatform();
    VideoPlayerPlatform.instance = platform;
    navigation = _NavigationObserver();
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'SystemChrome.setPreferredOrientations') {
        orientations.add(call.arguments as List<dynamic>);
      } else if (call.method == 'SystemChrome.setEnabledSystemUIMode') {
        fullscreen.add(call.arguments == 'SystemUiMode.immersiveSticky');
      }
      return null;
    });
    messenger.setMockMethodCallHandler(
      const MethodChannel('kaizenteams/video_fullscreen'),
      (call) async {
        if (call.method == 'waitForPortrait') {
          portraitWaitRequests++;
          if (physicalPortrait) return true;
          portraitWait = Completer<bool>();
          return portraitWait!.future;
        }
        if (call.method == 'cancelWaitForPortrait') {
          portraitWaitCancellations++;
          if (portraitWait?.isCompleted == false) portraitWait!.complete(false);
          portraitWait = null;
          return null;
        }
        fullscreen.add((call.arguments as Map)['enabled'] as bool);
        return null;
      },
    );
  });

  tearDown(() {
    VideoPlayerPlatform.instance = originalPlatform;
    AppManager.instance.resetSessionState();
    ApiCallExecutor.clearGetCache();
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, null);
    messenger.setMockMethodCallHandler(
      const MethodChannel('kaizenteams/video_fullscreen'),
      null,
    );
  });

  Future<void> mount(WidgetTester tester) async {
    tester.view.physicalSize = portrait;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(minutes: 3));
      await tester.pump();
    });
    await http.runWithClient(() async {
      await tester.pumpWidget(
        ChangeNotifierProvider<AppManager>.value(
          value: AppManager.instance,
          child: MaterialApp(
            navigatorObservers: [navigation],
            home: const ComplianceTrainingScreen(
              trackAssignmentUuid: 'assignment',
              itemUuid: 'item',
            ),
          ),
        ),
      );
      for (var attempt = 0; attempt < 100; attempt++) {
        await tester.pump();
        if ((!hasVideo && find.byType(TabBar).evaluate().isNotEmpty) ||
            platform.initialized.isCompleted) {
          break;
        }
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
      }
      await tester.pump();
      if (hasVideo) {
        await tester.pumpAndSettle();
      } else {
        await tester.pump(const Duration(milliseconds: 350));
      }
    }, () => client);
  }

  Future<void> rotate(WidgetTester tester, Size size) async {
    physicalPortrait = size.height > size.width;
    if (physicalPortrait && portraitWait?.isCompleted == false) {
      portraitWait!.complete(true);
      portraitWait = null;
    }
    tester.view.physicalSize = size;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
  }

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(minutes: 3));
    await tester.pump();
    expect(orientations.last, ['DeviceOrientation.portraitUp']);
    expect(tester.takeException(), isNull);
  }

  for (final playing in [false, true]) {
    testWidgets(
      'LTC landscape preserves the mounted video and playback (playing: $playing)',
      (tester) async {
        await mount(tester);
        expect(orientations.last, rotationAllowed);
        final playerState = tester.state(find.byType(ComplianceVideoPlayer));
        final videoState = tester.state(find.byType(VideoPlayer));
        final video = tester
            .widget<VideoPlayer>(find.byType(VideoPlayer))
            .controller;
        final captions = tester
            .element(find.byType(VideoPlayer))
            .read<ComplianceVideoController>();
        final route = ModalRoute.of(tester.element(find.byType(VideoPlayer)));
        final pushes = navigation.pushes;
        await tester.runAsync(() async {
          await video.seekTo(const Duration(seconds: 12));
          if (playing) await video.play();
        });
        for (var repeat = 0; repeat < 2; repeat++) {
          await rotate(tester, landscape);
          final fullscreenView = tester.widget<ComplianceFullScreenVideoView>(
            find.byType(ComplianceFullScreenVideoView),
          );
          expect(fullscreenView.controller, same(video));
          expect(fullscreenView.isEmbedded, isTrue);
          expect(navigation.pushes, pushes);
          expect(
            ModalRoute.of(
              tester.element(find.byType(ComplianceFullScreenVideoView)),
            ),
            same(route),
          );
          expect(
            tester.state(find.byType(ComplianceVideoPlayer)),
            same(playerState),
          );
          expect(tester.state(find.byType(VideoPlayer)), same(videoState));
          expect(
            tester
                .element(find.byType(VideoPlayer))
                .read<ComplianceVideoController>(),
            same(captions),
          );
          expect(find.byType(AppBar), findsNothing);
          expect(find.byType(AppBackButton), findsNothing);
          expect(find.byType(TabBar), findsNothing);
          expect(find.text(AppStrings.trainingTrackModules), findsNothing);
          expect(
            tester.getRect(
              find.byKey(const ValueKey('training-inline-fullscreen-video')),
            ),
            Offset.zero & landscape,
          );
          expect(video.value.position, const Duration(seconds: 12));
          expect(video.value.isPlaying, playing);
          await rotate(tester, portrait);
          expect(find.byType(ComplianceFullScreenVideoView), findsNothing);
          expect(
            tester.state(find.byType(ComplianceVideoPlayer)),
            same(playerState),
          );
          expect(tester.state(find.byType(VideoPlayer)), same(videoState));
          expect(find.byType(TabBar), findsOneWidget);
          expect(find.text(AppStrings.trainingTrackModules), findsOneWidget);
          expect(video.value.position, const Duration(seconds: 12));
          expect(video.value.isPlaying, playing);
        }
        expect(platform.creations, 1);
        expect(platform.seeks, [const Duration(seconds: 12)]);
        expect(fullscreen, [true, false, true, false]);
        expect(writes, isEmpty);
        await close(tester);
      },
      variant: TargetPlatformVariant({
        TargetPlatform.android,
        TargetPlatform.iOS,
      }),
    );
  }

  testWidgets('LTC landscape rejects new and already-started tab swipes', (
    tester,
  ) async {
    await mount(tester);
    final playerState = tester.state(find.byType(ComplianceVideoPlayer));
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(TabBarView)),
    );
    await gesture.moveBy(const Offset(-100, 0));
    await tester.pump();
    await rotate(tester, landscape);
    await gesture.up();
    await tester.pumpAndSettle();
    for (var attempt = 0; attempt < 2; attempt++) {
      await tester.drag(find.byType(TabBarView), const Offset(-650, 0));
      await tester.pumpAndSettle();
      expect(find.byType(ComplianceFullScreenVideoView), findsOneWidget);
      expect(
        tester.getRect(
          find.byKey(const ValueKey('training-inline-fullscreen-video')),
        ),
        Offset.zero & landscape,
      );
      expect(
        tester.state(find.byType(ComplianceVideoPlayer)),
        same(playerState),
      );
    }
    await rotate(tester, portrait);
    await tester.drag(find.byType(TabBarView), const Offset(-350, 0));
    await tester.pumpAndSettle();
    expect(tester.widget<TabBar>(find.byType(TabBar)).controller!.index, 1);
    expect(orientations.last, ['DeviceOrientation.portraitUp']);
    expect(find.text('LTC document'), findsOneWidget);
    await tester.tap(_tab(AppStrings.trainingVideoTab));
    await tester.pumpAndSettle();
    expect(orientations.last, rotationAllowed);
    await close(tester);
  });

  for (final systemBack in [false, true]) {
    testWidgets(
      'LTC ${systemBack ? 'system back' : 'exit icon'} waits for physical portrait',
      (tester) async {
        await mount(tester);
        final video = tester
            .widget<VideoPlayer>(find.byType(VideoPlayer))
            .controller;
        await tester.runAsync(() async {
          await video.seekTo(const Duration(seconds: 12));
          await video.play();
        });
        await rotate(tester, landscape);
        final pushes = navigation.pushes;
        if (systemBack) {
          await tester.binding.handlePopRoute();
        } else {
          await tester.tap(
            find.byKey(const ValueKey('fullscreen-active-transcript')),
          );
          await tester.pump();
          await tester.tap(
            find.byKey(const ValueKey('video-exit-fullscreen-button')),
          );
        }
        await tester.pump();
        expect(portraitWaitRequests, 1);
        expect(orientations.last, ['DeviceOrientation.portraitUp']);
        expect(navigation.pushes, pushes);
        tester.view.physicalSize = portrait;
        await tester.pumpAndSettle();
        expect(find.byType(ComplianceFullScreenVideoView), findsNothing);
        expect(orientations.last, ['DeviceOrientation.portraitUp']);
        expect(fullscreen, [true, false]);
        expect(video.value.position, const Duration(seconds: 12));
        expect(portraitWait?.isCompleted, isFalse);
        physicalPortrait = true;
        portraitWait!.complete(true);
        portraitWait = null;
        await tester.pumpAndSettle();
        expect(orientations.last, rotationAllowed);
        await rotate(tester, landscape);
        expect(find.byType(ComplianceFullScreenVideoView), findsOneWidget);
        expect(platform.seeks, [const Duration(seconds: 12)]);
        await close(tester);
      },
      variant: TargetPlatformVariant({
        TargetPlatform.android,
        TargetPlatform.iOS,
      }),
    );
  }

  testWidgets(
    'LTC leaving Video cancels the pending physical orientation wait',
    (tester) async {
      await mount(tester);
      await rotate(tester, landscape);
      await tester.tap(
        find.byKey(const ValueKey('video-exit-fullscreen-button')),
      );
      await tester.pump();
      tester.view.physicalSize = portrait;
      await tester.pumpAndSettle();
      await tester.tap(_tab(AppStrings.trainingDocumentTab));
      await tester.pumpAndSettle();
      expect(portraitWaitCancellations, 1);
      expect(portraitWait, isNull);
      expect(orientations.last, ['DeviceOrientation.portraitUp']);
      await tester.tap(_tab(AppStrings.trainingVideoTab));
      await tester.pumpAndSettle();
      expect(orientations.last, rotationAllowed);
      await close(tester);
    },
  );

  testWidgets('LTC without a video keeps portrait locked', (tester) async {
    hasVideo = false;
    await mount(tester);
    expect(orientations.last, ['DeviceOrientation.portraitUp']);
    expect(find.byType(ComplianceFullScreenVideoView), findsNothing);
    await close(tester);
  });

  testWidgets(
    'LTC Document and Quiz stay portrait and preserve the quiz start flow',
    (tester) async {
      await mount(tester);
      await tester.tap(_tab(AppStrings.trainingDocumentTab));
      await tester.pumpAndSettle();
      expect(orientations.last, ['DeviceOrientation.portraitUp']);
      expect(find.text('LTC document'), findsOneWidget);
      await tester.tap(_tab(AppStrings.trainingQuizTab));
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.trainingWelcomeQuizTitle), findsOneWidget);
      expect(orientations.last, ['DeviceOrientation.portraitUp']);
      await tester.tap(find.text(AppStrings.start));
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.trainingWelcomeQuizTitle), findsNothing);
      final view = tester.element(find.byType(TabBarView));
      expect(view.read<ComplianceTrainingController>().selectedTabIndex, 2);
      expect(
        tester.widget<TabBarView>(find.byType(TabBarView)).controller!.index,
        2,
      );
      expect(orientations.last, ['DeviceOrientation.portraitUp']);
      expect(writes.single.url.path, endsWith('/start_quiz/'));
      await close(tester);
    },
  );

  testWidgets('LTC closing the screen cancels its physical portrait wait', (
    tester,
  ) async {
    await mount(tester);
    await rotate(tester, landscape);
    await tester.tap(
      find.byKey(const ValueKey('video-exit-fullscreen-button')),
    );
    await tester.pump();
    expect(portraitWait?.isCompleted, isFalse);
    await close(tester);
    expect(portraitWaitCancellations, 1);
    expect(portraitWait, isNull);
    expect(fullscreen, [true, false]);
  });
}

Finder _tab(String label) =>
    find.descendant(of: find.byType(TabBar), matching: find.text(label));

class _EmptyVideoCache extends Fake implements CacheManager {
  @override
  Future<FileInfo?> getFileFromCache(
    String key, {
    bool ignoreMemCache = false,
  }) async => null;
}

class _VideoPlatform extends VideoPlayerPlatform {
  final initialized = Completer<void>();
  final events = StreamController<VideoEvent>();
  Duration position = Duration.zero;
  int creations = 0;
  final seeks = <Duration>[];

  @override
  Future<void> init() async {}
  @override
  Future<int> createWithOptions(VideoCreationOptions options) async {
    creations++;
    events.add(
      VideoEvent(
        eventType: VideoEventType.initialized,
        duration: const Duration(minutes: 1),
        size: const Size(640, 360),
      ),
    );
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
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) => pushes++;
}
