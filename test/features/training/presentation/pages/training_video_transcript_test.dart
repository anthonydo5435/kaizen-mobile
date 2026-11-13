import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sparrowkaizen/core/constants/app_colors.dart';
import 'package:sparrowkaizen/core/constants/app_strings.dart';
import 'package:sparrowkaizen/core/managers/app_manager.dart';
import 'package:sparrowkaizen/core/network/api_endpoints.dart';
import 'package:sparrowkaizen/core/preference/app_preference.dart';
import 'package:sparrowkaizen/features/compliance/domain/entities/compliance_track_item_detail.dart';
import 'package:sparrowkaizen/features/compliance/presentation/pages/training/compliance_video_screen.dart';
import 'package:sparrowkaizen/features/compliance/presentation/providers/compliance_video_controller.dart';
import 'package:sparrowkaizen/features/compliance/presentation/widgets/compliance_video_player.dart';
import 'package:sparrowkaizen/features/compliance/presentation/widgets/compliance_video_transcript_panel.dart';
import 'package:sparrowkaizen/features/login/domain/entities/user.dart';
import 'package:sparrowkaizen/features/training/domain/entities/seat_description_training_route.dart';
import 'package:sparrowkaizen/features/training/presentation/controllers/training_module_controller.dart';
import 'package:sparrowkaizen/features/training/presentation/pages/edit_training_screen.dart';
import 'package:video_player/video_player.dart';
// Use the existing player interface to drive the actual Edit Training video tab.
// ignore: depend_on_referenced_packages
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

void main() {
  for (final screenSize in [const Size(390, 844), const Size(320, 640)]) {
    testWidgets(
      'Edit Training keeps $screenSize thumbnail and playback bounds consistent and matches LTC',
      (tester) async {
        tester.view.physicalSize = screenSize;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        const mainCaption = 'Main point\nA second line\nAnd a third line';
        final originalPlatform = VideoPlayerPlatform.instance;
        final platform = _TrainingVideoPlatform();
        VideoPlayerPlatform.instance = platform;
        final directory = Directory.systemTemp.createTempSync(
          'edit-training-video-',
        );
        final videoFile = File('${directory.path}/video.mp4')
          ..writeAsBytesSync([0]);
        final originalImageClientProvider = debugNetworkImageHttpClientProvider;
        final thumbnailServer = (await tester.runAsync(() async {
          final recorder = ui.PictureRecorder();
          Canvas(recorder).drawColor(Colors.white, BlendMode.src);
          final picture = recorder.endRecording();
          final image = await picture.toImage(640, 640);
          final bytes = (await image.toByteData(
            format: ui.ImageByteFormat.png,
          ))!.buffer.asUint8List();
          image.dispose();
          picture.dispose();
          final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
          server.listen((request) {
            request.response.headers.contentType = ContentType('image', 'png');
            request.response.add(bytes);
            unawaited(request.response.close());
          });
          final imageClient = HttpOverrides.runWithHttpOverrides(
            HttpClient.new,
            _ThumbnailHttpOverrides(),
          );
          debugNetworkImageHttpClientProvider = () => imageClient;
          addTearDown(() async {
            debugNetworkImageHttpClientProvider = originalImageClientProvider;
            imageClient.close(force: true);
            await server.close(force: true);
          });
          return server;
        }))!;
        addTearDown(() {
          VideoPlayerPlatform.instance = originalPlatform;
          directory.deleteSync(recursive: true);
        });
        SharedPreferences.setMockInitialValues({});
        await AppPreference.init();
        AppManager.instance.resetSessionState();
        AppManager.instance.updateCurrentUser(
          User(uuid: 'owner', isOwner: true, organizationUuid: 'org-id'),
        );
        addTearDown(AppManager.instance.resetSessionState);

        final client = MockClient((request) async {
          expect(request.method, 'GET');
          final endpoint = request.url.path.replaceFirst(
            ApiEndPoints.version,
            '',
          );
          final Object response;
          if (endpoint ==
              ApiEndPoints.seatDescriptionTrainingModules('description')) {
            response = [
              {'uuid': 'lesson', 'title': 'Lesson'},
              {'uuid': 'next-lesson', 'title': 'Next lesson'},
            ];
          } else if (endpoint == ApiEndPoints.trainingModuleDetail('lesson') ||
              endpoint == ApiEndPoints.trainingModuleDetail('next-lesson')) {
            final isNext =
                endpoint == ApiEndPoints.trainingModuleDetail('next-lesson');
            response = {
              'uuid': isNext ? 'next-lesson' : 'lesson',
              'title': isNext ? 'Next lesson' : 'Lesson',
              'description': 'The summary stays available',
              'thumbnail_link': isNext
                  ? null
                  : 'http://127.0.0.1:${thumbnailServer.port}/thumbnail.png',
              'training_video': {
                'uuid': isNext ? 'next-video' : 'video',
                'title': 'Video',
                // The selected video's local preview is attached after the API load.
                'url': 'http://[',
                'duration': 60,
                'transcript': isNext
                    ? '[00:00] Next caption'
                    : '[00:00] Introduction\n[00:05] $mainCaption',
              },
            };
          } else if (endpoint == ApiEndPoints.lmsPublicLink('description')) {
            response = {'active': false};
          } else {
            throw StateError('Unexpected API request: $endpoint');
          }
          return http.Response(
            jsonEncode(response),
            200,
            headers: {'content-type': 'application/json'},
          );
        });
        addTearDown(client.close);

        await http.runWithClient(() async {
          await tester.pumpWidget(
            ChangeNotifierProvider<AppManager>.value(
              value: AppManager.instance,
              child: const MaterialApp(
                home: EditTrainingScreen(
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
          final action = find.text(AppStrings.trainingViewTranscript);
          final controller = tester
              .element(action)
              .read<ComplianceVideoController>();
          final moduleController = tester
              .element(action)
              .read<TrainingModuleController>();
          moduleController.applyBackgroundUploadedVideo(
            moduleId: 'lesson',
            video: moduleController.selectedModuleDetail!.trainingVideo!,
            localVideoPath: videoFile.path,
          );
          await tester.pump();
          expect(
            tester
                .widget<ComplianceVideoPlayer>(
                  find.byType(ComplianceVideoPlayer),
                )
                .localVideoPath,
            videoFile.path,
          );
          // File I/O runs outside the test clock; pump native initialization callbacks
          // between waits because this player is already mounted when its source changes.
          for (
            var attempt = 0;
            attempt < 100 && !platform.initialized.isCompleted;
            attempt++
          ) {
            await tester.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 50)),
            );
            await tester.pump();
          }
          expect(platform.initialized.isCompleted, isTrue);
          await tester.pump();
          await tester.pump();
          final player = find.byType(ComplianceVideoPlayer);
          final frame = find.byKey(const ValueKey('training-video-frame'));
          final bounds = tester.getRect(frame);
          final thumbnail = find.descendant(
            of: find.byKey(const ValueKey('video-thumbnail-preview')),
            matching: find.byType(RawImage),
          );
          for (
            var attempt = 0;
            attempt < 100 && tester.widget<RawImage>(thumbnail).image == null;
            attempt++
          ) {
            await tester.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 10)),
            );
            await tester.pump();
          }
          expect(tester.widget<RawImage>(thumbnail).image, isNotNull);
          await tester.pump();
          final thumbnailBounds = tester.getRect(thumbnail);
          final initialSeekBounds = tester.getRect(find.byType(Slider));
          expect(find.byType(VideoPlayer), findsNothing);
          await tester.tap(find.byIcon(Icons.play_arrow_rounded));
          await tester.pump(const Duration(milliseconds: 300));
          await tester.pump();
          final video = find.byType(VideoPlayer);
          final nativeController = tester.widget<VideoPlayer>(video).controller;
          await nativeController.pause();
          await tester.pump();
          await tester.pump();
          final mediaBounds = tester.getRect(video);
          expect(mediaBounds, thumbnailBounds);
          expect(tester.getRect(find.byType(Slider)), initialSeekBounds);
          final slider = find.byType(Slider);
          final controls = find
              .ancestor(of: slider, matching: find.byType(Column))
              .first;
          final seekBounds = tester.getRect(slider);
          final cc = find.text(AppStrings.trainingCc);
          final actions = find
              .ancestor(of: cc, matching: find.byType(Row))
              .first;
          final ccButton = find.ancestor(
            of: cc,
            matching: find.byType(TextButton),
          );
          final transcriptButton = find.ancestor(
            of: action,
            matching: find.byType(TextButton),
          );
          final surface = find
              .descendant(
                of: find.byType(ComplianceVideoTranscriptPanel),
                matching: find.byType(Material),
              )
              .first;
          final expectedFrameHeight =
              (screenSize.height / 2).clamp(320.0, 520.0) - 39;
          expect(bounds.height, expectedFrameHeight);
          expect(bounds.left, 0);
          expect(bounds.right, screenSize.width);
          expect(
            tester.widget<ComplianceVideoPlayer>(player).height,
            expectedFrameHeight,
          );
          expect(mediaBounds.left, closeTo(bounds.left, 0.01));
          expect(mediaBounds.right, closeTo(bounds.right, 0.01));
          expect(mediaBounds.width / mediaBounds.height, closeTo(16 / 9, 0.01));
          expect(mediaBounds.top, greaterThanOrEqualTo(bounds.top));
          final topActions = [
            find.byTooltip(AppStrings.trainingThumbnailAction),
            find.byTooltip(AppStrings.trainingReUploadVideoAction),
            find.byKey(const ValueKey('video-fullscreen-button')),
          ];
          for (final topAction in topActions) {
            expect(
              mediaBounds.top - tester.getBottomLeft(topAction).dy,
              greaterThanOrEqualTo(6),
            );
          }
          expect(mediaBounds.bottom, lessThanOrEqualTo(bounds.bottom));
          expect(
            tester.widget<ComplianceVideoPlayer>(player).fillBounds,
            isTrue,
          );
          expect(controller.transcriptLines.map((line) => line.text), [
            'Introduction',
            mainCaption,
          ]);
          expect(controller.isCcEnabled, isFalse);
          expect(
            find.byTooltip(AppStrings.trainingThumbnailAction),
            findsOneWidget,
          );
          expect(
            find.byTooltip(AppStrings.trainingReUploadVideoAction),
            findsOneWidget,
          );
          expect(find.text(AppStrings.trainingSummaryLabel), findsOneWidget);

          expect(find.text('Introduction'), findsOneWidget);
          _expectGap(tester, video, controls, 10);
          _expectCaptionOverlay(tester, mediaBounds, find.text('Introduction'));
          _expectGap(tester, slider, actions, 6);
          expect(tester.getTopLeft(ccButton).dx, bounds.left + 10);
          expect(
            tester.getBottomRight(transcriptButton).dx,
            bounds.right - ComplianceVideoPlayer.contentHorizontalInset,
          );
          final expandedHeight = tester.getSize(surface).height;

          await tester.tap(find.byIcon(Icons.play_arrow_rounded));
          await tester.pump();
          expect(nativeController.value.isPlaying, isTrue);
          expect(slider, findsNothing);
          _expectCaptionOverlay(tester, mediaBounds, find.text('Introduction'));
          _expectGap(tester, video, actions, 6);
          final playingHeight = tester.getSize(surface).height;
          expect(playingHeight, lessThan(expandedHeight));
          expect(tester.getRect(frame), bounds);
          expect(tester.getRect(video), mediaBounds);
          for (final topAction in topActions) {
            expect(
              tester.getRect(topAction).bottom + 6,
              lessThanOrEqualTo(mediaBounds.top),
            );
          }

          await tester.tap(find.text('Introduction'));
          await tester.pump();
          _expectGap(tester, video, controls, 10);
          _expectCaptionOverlay(tester, mediaBounds, find.text('Introduction'));
          expect(tester.getRect(slider), seekBounds);
          await tester.pump(const Duration(milliseconds: 2999));
          expect(slider, findsOneWidget);
          await tester.pump(const Duration(milliseconds: 1));
          expect(slider, findsNothing);

          await tester.tap(cc);
          await tester.pump();
          expect(find.text('Introduction'), findsNothing);
          _expectGap(tester, video, actions, 6);
          expect(tester.getSize(surface).height, playingHeight);
          expect(tester.getRect(frame), bounds);
          await tester.tapAt(bounds.topLeft + const Offset(20, 50));
          await tester.pump();
          _expectGap(tester, video, controls, 10);
          _expectGap(tester, slider, actions, 6);
          await tester.pump(const Duration(seconds: 3));
          expect(slider, findsNothing);
          _expectGap(tester, video, actions, 6);

          await tester.tap(action);
          await tester.pumpAndSettle();
          final introduction = find.descendant(
            of: find.byType(BottomSheet),
            matching: find.text('Introduction'),
          );
          expect(
            tester.widget<Text>(introduction).style?.color,
            AppColors.secondaryColor,
          );
          await tester.tap(find.text(mainCaption));
          await tester.pumpAndSettle();
          expect(nativeController.value.position, const Duration(seconds: 5));
          expect(nativeController.value.isPlaying, isTrue);
          expect(find.byType(BottomSheet), findsNothing);
          expect(find.text(mainCaption), findsNothing);
          await tester.tap(cc);
          await tester.pump();
          expect(find.text('Main'), findsOneWidget);
          await nativeController.seekTo(const Duration(milliseconds: 5450));
          await tester.pump();
          expect(find.text('Main point'), findsOneWidget);
          await nativeController.seekTo(const Duration(milliseconds: 5900));
          await tester.pump();
          expect(find.text('A'), findsOneWidget);
          expect(find.text('Main point'), findsNothing);
          await nativeController.seekTo(const Duration(milliseconds: 6800));
          await tester.pump();
          expect(find.text('A second line'), findsOneWidget);
          await nativeController.seekTo(const Duration(seconds: 9));
          await tester.pump();
          final caption = find.text('And a third line');
          expect(caption, findsOneWidget);
          _expectCaptionOverlay(tester, mediaBounds, caption);
          _expectGap(tester, slider, actions, 6);
          final paragraph = tester.renderObject<RenderParagraph>(
            find.descendant(of: caption, matching: find.byType(RichText)),
          );
          expect(paragraph.didExceedMaxLines, isFalse);
          expect(tester.getSize(surface).height, expandedHeight);
          await tester.pump(const Duration(seconds: 3));
          expect(slider, findsNothing);
          _expectCaptionOverlay(tester, mediaBounds, caption);
          _expectGap(tester, video, actions, 6);
          expect(tester.getSize(surface).height, playingHeight);
          await tester.tap(caption);
          await tester.pump();
          await tester.tap(find.byIcon(Icons.pause_rounded));
          await tester.pump(const Duration(seconds: 4));
          expect(slider, findsOneWidget);
          expect(nativeController.value.isPlaying, isFalse);
          _expectGap(tester, video, controls, 10);
          _expectCaptionOverlay(tester, mediaBounds, caption);
          expect(tester.getRect(frame), bounds);
          expect(tester.getRect(video), mediaBounds);

          await tester.tap(cc);
          await tester.pump();
          _expectGap(tester, slider, actions, 6);
          await moduleController.selectModule('next-lesson');
          await tester.pumpAndSettle();
          final nextController = tester
              .element(action)
              .read<ComplianceVideoController>();
          expect(identical(nextController, controller), isFalse);
          expect(nextController.isCcEnabled, isFalse);
          expect(nextController.activeTranscriptIndex, isNull);
          expect(nextController.transcriptLines.single.text, 'Next caption');
          expect(find.text(mainCaption), findsNothing);
          expect(tester.takeException(), isNull);

          // Compare the actual LTC tab against the rendered Edit Training panel.
          await tester.pumpWidget(
            const MaterialApp(
              home: Scaffold(
                body: ComplianceVideoScreen(
                  detail: ComplianceTrackItemDetail(
                    uuid: 'ltc-video',
                    position: 1,
                    trainingModuleUuid: 'lesson',
                    title: 'Lesson',
                    quizStatus: '',
                    videoUrl: 'http://[',
                    videoDuration: 60,
                    videoTranscript: null,
                    videoThumbnailLink: null,
                    trainingDocument: null,
                    quizCompletionPercentage: 0,
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.getSize(frame).height, bounds.height);
          expect(tester.getSize(surface).height, expandedHeight);
          final ltcController = tester
              .element(action)
              .read<ComplianceVideoController>();
          ltcController.updatePlaybackControlsVisibility(false);
          await tester.pump();
          expect(tester.getSize(surface).height, playingHeight);
          expect(
            find.byTooltip(AppStrings.trainingReUploadVideoAction),
            findsNothing,
          );
          expect(
            find.byTooltip(AppStrings.trainingThumbnailAction),
            findsNothing,
          );
          await tester.pumpWidget(const SizedBox.shrink());
          // Let the playback service release its retained native controller.
          await tester.pump(const Duration(minutes: 3));
          await tester.pump();
        }, () => client);
        debugNetworkImageHttpClientProvider = originalImageClientProvider;
      },
    );
  }
}

class _ThumbnailHttpOverrides extends HttpOverrides {}

void _expectGap(WidgetTester tester, Finder above, Finder below, double gap) {
  expect(
    tester.getTopLeft(below).dy - tester.getBottomLeft(above).dy,
    closeTo(gap, 0.01),
  );
}

void _expectCaptionOverlay(
  WidgetTester tester,
  Rect videoBounds,
  Finder caption,
) {
  final overlay = tester.getRect(
    find.byKey(const ValueKey('active-video-caption')),
  );
  expect(overlay.bottom, closeTo(videoBounds.bottom - 8, 0.01));
  expect(overlay.left, videoBounds.left + 8);
  expect(overlay.right, videoBounds.right - 8);
  expect(overlay.top, greaterThanOrEqualTo(videoBounds.top + 8));
  expect(tester.widget<Text>(caption).maxLines, 1);
  expect(tester.widget<Text>(caption).overflow, TextOverflow.ellipsis);
}

class _TrainingVideoPlatform extends VideoPlayerPlatform {
  final initialized = Completer<void>();
  final events = StreamController<VideoEvent>();
  Duration position = Duration.zero;

  @override
  Future<void> init() async {}

  @override
  Future<int> createWithOptions(VideoCreationOptions options) async {
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
  Future<void> seekTo(int playerId, Duration value) async => position = value;

  @override
  Future<Duration> getPosition(int playerId) async => position;

  @override
  Widget buildViewWithOptions(VideoViewOptions options) => const SizedBox();

  @override
  Future<void> dispose(int playerId) async => events.close();
}
