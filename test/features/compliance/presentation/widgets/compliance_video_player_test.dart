import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sparrowkaizen/core/constants/app_strings.dart';
import 'package:sparrowkaizen/core/widgets/app_back_button.dart';
import 'package:sparrowkaizen/features/compliance/presentation/pages/training/compliance_full_screen_video_view.dart';
import 'package:sparrowkaizen/features/compliance/presentation/providers/compliance_video_controller.dart';
import 'package:sparrowkaizen/features/compliance/presentation/widgets/compliance_video_player.dart';
import 'package:sparrowkaizen/features/compliance/presentation/widgets/compliance_video_transcript_panel.dart';
import 'package:video_player/video_player.dart';
// Use video_player's existing platform interface to simulate native playback.
// ignore: depend_on_referenced_packages
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

void main() {
  late VideoPlayerPlatform originalPlatform;
  late _FakeVideoPlatform platform;
  late Directory videoDirectory;
  late String videoPath;

  setUp(() {
    originalPlatform = VideoPlayerPlatform.instance;
    platform = _FakeVideoPlatform();
    VideoPlayerPlatform.instance = platform;
    videoDirectory = Directory.systemTemp.createTempSync(
      'video-controls-test-',
    );
    videoPath = '${videoDirectory.path}/video.mp4';
    File(videoPath).writeAsBytesSync([0]);
  });

  tearDown(() {
    VideoPlayerPlatform.instance = originalPlatform;
    videoDirectory.deleteSync(recursive: true);
  });

  Future<VideoPlayerController> mountPlayer(
    WidgetTester tester, {
    ValueChanged<Future<bool> Function(Duration)?>? onSeekHandlerChanged,
    String? transcript,
    double textScale = 1,
    bool disableAnimations = true,
    int activeCaptionMaxLines = 2,
  }) async {
    await tester.runAsync(() async {
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(textScale),
              // Layout checks use complete captions; pacing is verified separately.
              disableAnimations: disableAnimations,
            ),
            child: child!,
          ),
          home: Scaffold(
            body: transcript == null
                ? ComplianceVideoPlayer(
                    videoUrl: '',
                    localVideoPath: videoPath,
                    title: 'Lesson',
                    onSeekHandlerChanged: onSeekHandlerChanged,
                  )
                : ComplianceVideoTranscriptPanel(
                    videoId: 'lesson',
                    videoUrl: 'https://example.test/video.mp4',
                    localVideoPath: videoPath,
                    title: 'Lesson',
                    transcript: transcript,
                    activeCaptionMaxLines: activeCaptionMaxLines,
                  ),
          ),
        ),
      );
      await platform.initialized.future;
      await Future<void>.delayed(Duration.zero);
    });
    await tester.pump();
    await tester.pump(); // Apply the measured video edge to the shared footer.
    final controller = tester
        .widget<VideoPlayer>(find.byType(VideoPlayer))
        .controller;
    return controller;
  }

  Future<void> disposePlayer(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    // The playback service retains released controllers for three minutes.
    await tester.pump(const Duration(minutes: 3));
    await tester.pump();
    expect(tester.takeException(), isNull);
  }

  Future<void> tapVideo(WidgetTester tester) async {
    final origin = tester.getTopLeft(find.byType(ComplianceVideoPlayer));
    await tester.tapAt(origin + const Offset(30, 50));
    await tester.pump();
  }

  Future<void> completeVideo(WidgetTester tester) async {
    await tester.runAsync(() async {
      platform.events.add(VideoEvent(eventType: VideoEventType.completed));
      await Future<void>.delayed(Duration.zero);
    });
    await tester.pump();
  }

  void expectCaptionOverlay(WidgetTester tester, Finder caption) {
    final media = tester.getRect(find.byType(VideoPlayer));
    final overlay = tester.getRect(
      find.byKey(const ValueKey('active-video-caption')),
    );
    expect(overlay.left, closeTo(media.left + 8, 0.01));
    expect(overlay.right, closeTo(media.right - 8, 0.01));
    expect(overlay.bottom, closeTo(media.bottom - 8, 0.01));
    expect(overlay.top, greaterThanOrEqualTo(media.top + 8));
    final text = tester.widget<Text>(caption);
    expect(text.maxLines, 2);
    expect(text.overflow, TextOverflow.ellipsis);
  }

  void expectControls({required bool visible, bool playing = true}) {
    final matcher = visible ? findsOneWidget : findsNothing;
    expect(find.byType(Slider), matcher);
    expect(find.text('Lesson'), matcher);
    expect(find.text('/'), matcher);
    expect(find.text('01:00'), visible ? findsWidgets : findsNothing);
    expect(find.byIcon(Icons.replay_10_rounded), matcher);
    expect(find.byIcon(Icons.forward_10_rounded), matcher);
    expect(
      find.byIcon(playing ? Icons.pause_rounded : Icons.play_arrow_rounded),
      matcher,
    );
  }

  void expectSeekActionGap(WidgetTester tester) {
    final actionButton = find.ancestor(
      of: find.text(AppStrings.trainingViewTranscript),
      matching: find.byType(TextButton),
    );
    expect(
      tester.getTopLeft(actionButton).dy -
          tester.getBottomLeft(find.byType(Slider)).dy,
      closeTo(6, 0.01),
    );
  }

  for (final disableAnimations in [false, true]) {
    testWidgets(
      'single-line captions advance through every word with reduced motion $disableAnimations',
      (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        const words = [
          'First',
          'second',
          'third',
          'fourth',
          'fifth',
          'sixth',
          'seventh',
          'eighth',
          'ninth',
          'tenth',
          'eleventh',
          'twelfth',
        ];
        final cue = words.join(' ');
        final controller = await mountPlayer(
          tester,
          transcript: '[00:00 --> 00:24] $cue',
          textScale: 2,
          disableAnimations: disableAnimations,
          activeCaptionMaxLines: 1,
        );
        final seenWords = <String>{};
        String? firstPage;
        String? finalPage;
        for (var index = 0; index < words.length; index++) {
          await controller.seekTo(Duration(seconds: index * 2));
          await tester.pump();
          final text = find.descendant(
            of: find.byKey(const ValueKey('active-video-caption')),
            matching: find.byType(Text),
          );
          final caption = tester.widget<Text>(text);
          final visibleText = caption.data!;
          expect(visibleText, contains(words[index]));
          expect(caption.maxLines, 1);
          expect(
            tester
                .renderObject<RenderParagraph>(
                  find.descendant(of: text, matching: find.byType(RichText)),
                )
                .didExceedMaxLines,
            isFalse,
          );
          seenWords.addAll(visibleText.split(RegExp(r'\s+')));
          firstPage ??= visibleText;
          finalPage = visibleText;
        }
        expect(seenWords, containsAll(words));
        expect(finalPage, isNot(contains('First')));
        await tester.pump(const Duration(seconds: 3));
        expect(find.text(finalPage!), findsOneWidget);
        await controller.seekTo(Duration.zero);
        await tester.pump();
        expect(find.text(firstPage!), findsOneWidget);
        await tester.tap(find.text(AppStrings.trainingCc));
        await tester.pump();
        expect(
          find.byKey(const ValueKey('active-video-caption')),
          findsNothing,
        );
        await tester.tap(find.text(AppStrings.trainingCc));
        await tester.pump();
        expect(find.text(firstPage), findsOneWidget);

        await tester.tap(find.text(AppStrings.trainingViewTranscript));
        await tester.pumpAndSettle();
        expect(
          find.descendant(
            of: find.byType(BottomSheet),
            matching: find.text(cue),
          ),
          findsOneWidget,
        );
        await disposePlayer(tester);
      },
    );
  }

  for (final preview in [
    (thumbnail: const Size(640, 360), video: const Size(640, 360)),
    (thumbnail: const Size(360, 640), video: const Size(640, 360)),
    (thumbnail: const Size(640, 640), video: const Size(640, 360)),
    (thumbnail: const Size(800, 300), video: const Size(640, 360)),
    (thumbnail: const Size(640, 360), video: const Size(360, 640)),
    (thumbnail: const Size(640, 640), video: const Size(360, 640)),
  ]) {
    final thumbnailSize = preview.thumbnail;
    testWidgets(
      'centers the whole $thumbnailSize thumbnail in ${preview.video} playback bounds',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        platform.autoInitialize = false;
        platform.videoSize = preview.video;
        final originalImageClientProvider = debugNetworkImageHttpClientProvider;
        final releaseThumbnail = Completer<void>();

        await tester.runAsync(() async {
          final recorder = ui.PictureRecorder();
          Canvas(recorder).drawColor(Colors.white, BlendMode.src);
          final picture = recorder.endRecording();
          final image = await picture.toImage(
            thumbnailSize.width.toInt(),
            thumbnailSize.height.toInt(),
          );
          final bytes = (await image.toByteData(
            format: ui.ImageByteFormat.png,
          ))!.buffer.asUint8List();
          image.dispose();
          picture.dispose();
          final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
          server.listen((request) async {
            await releaseThumbnail.future;
            request.response.headers.contentType = ContentType('image', 'png');
            request.response.add(bytes);
            unawaited(request.response.close());
          });
          final client = HttpOverrides.runWithHttpOverrides(
            HttpClient.new,
            _LocalImageHttpOverrides(),
          );
          debugNetworkImageHttpClientProvider = () => client;
          addTearDown(() async {
            if (!releaseThumbnail.isCompleted) releaseThumbnail.complete();
            debugNetworkImageHttpClientProvider = originalImageClientProvider;
            client.close(force: true);
            await server.close(force: true);
          });
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: RepaintBoundary(
                  key: const ValueKey('video-preview-pixels'),
                  child: ComplianceVideoTranscriptPanel(
                    videoId: 'lesson',
                    videoUrl: 'https://example.test/video.mp4',
                    localVideoPath: videoPath,
                    title: 'Lesson',
                    thumbnailLink:
                        'http://127.0.0.1:${server.port}/thumbnail.png',
                    transcript: '[00:10] Later caption',
                    topRightActions: const [
                      SizedBox(
                        key: ValueKey('thumbnail-edit-action'),
                        width: 60,
                        height: 56,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
          await platform.created.future;
        });
        await tester
            .pump(); // Apply the measured action row before image decoding.
        final frame = find.byKey(const ValueKey('training-video-frame'));
        final frameBounds = tester.getRect(frame);
        final surface = find
            .descendant(
              of: find.byType(ComplianceVideoTranscriptPanel),
              matching: find.byType(Material),
            )
            .first;
        final initialSurfaceBounds = tester.getRect(surface);
        final initialTitleBounds = tester.getRect(find.text('Lesson'));
        final previewBottom =
            frameBounds.top + 68 + frameBounds.width / (16 / 9);
        expect(initialTitleBounds.top, closeTo(previewBottom + 10, 0.01));
        await tester.pump();
        expect(tester.getRect(surface), initialSurfaceBounds);
        expect(tester.getRect(find.text('Lesson')), initialTitleBounds);
        releaseThumbnail.complete();
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
        final rawImage = tester.widget<RawImage>(thumbnail);
        expect(rawImage.fit, BoxFit.contain);
        expect(rawImage.alignment, Alignment.center);
        final thumbnailBounds = tester.getRect(thumbnail);
        final paintedThumbnailBounds = Alignment.center.inscribe(
          applyBoxFit(
            BoxFit.contain,
            thumbnailSize,
            thumbnailBounds.size,
          ).destination,
          thumbnailBounds,
        );
        expect(tester.getRect(surface), initialSurfaceBounds);
        expect(tester.getRect(find.text('Lesson')), initialTitleBounds);
        expect(thumbnailBounds.left, greaterThanOrEqualTo(frameBounds.left));
        expect(thumbnailBounds.center.dx, closeTo(frameBounds.center.dx, 0.01));
        expect(thumbnailBounds.right, lessThanOrEqualTo(frameBounds.right));
        expect(
          thumbnailBounds.width / thumbnailBounds.height,
          closeTo(16 / 9, 0.01),
        );
        expect(
          thumbnailBounds.top -
              tester
                  .getBottomLeft(
                    find.byKey(const ValueKey('thumbnail-edit-action')),
                  )
                  .dy,
          closeTo(6, 0.01),
        );
        expect(thumbnailBounds.bottom, lessThanOrEqualTo(frameBounds.bottom));
        expect(find.text('Later caption'), findsNothing);
        expect(
          tester.getTopLeft(find.text('Lesson')).dy - thumbnailBounds.bottom,
          closeTo(10, 0.01),
        );
        expectSeekActionGap(tester);
        expect(find.byType(VideoPlayer), findsNothing);

        final captions = tester
            .element(find.text(AppStrings.trainingViewTranscript))
            .read<ComplianceVideoController>();
        captions.updatePlaybackPosition(
          const Duration(seconds: 10),
          animate: false,
        );
        await tester.pump();
        final captionBounds = tester.getRect(
          find.byKey(const ValueKey('active-video-caption')),
        );
        final edgePoint = Offset(
          thumbnailBounds.left + 2,
          thumbnailBounds.bottom - 4,
        );
        final colors = await _previewPixelColors(tester, [
          Offset(
            paintedThumbnailBounds.center.dx,
            paintedThumbnailBounds.top + 8,
          ),
          edgePoint,
          Offset(captionBounds.left + 4, captionBounds.center.dy),
        ]);
        expect(
          colors,
          [
            Colors.white,
            paintedThumbnailBounds.contains(edgePoint)
                ? Colors.white
                : Colors.black,
            Colors.black,
          ],
          reason:
              'The centered thumbnail stays bright, unused space stays black, and captions remain opaque.',
        );
        captions.updatePlaybackPosition(Duration.zero, animate: false);
        await tester.pump();

        await tester.runAsync(() async {
          platform.initialize();
          await platform.initialized.future;
          await Future<void>.delayed(Duration.zero);
        });
        await tester.pump();
        await tester.pump();
        final readyThumbnailBounds = tester.getRect(thumbnail);
        expect(find.text('Later caption'), findsNothing);
        expect(find.text('01:00'), findsOneWidget);
        expect(
          readyThumbnailBounds.width / readyThumbnailBounds.height,
          closeTo(platform.videoSize.width / platform.videoSize.height, 0.01),
        );
        expect(
          tester.getTopLeft(find.text('Lesson')).dy -
              readyThumbnailBounds.bottom,
          closeTo(10, 0.01),
        );
        await tester.tap(find.byIcon(Icons.play_arrow_rounded));
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump();
        expect(find.byType(Slider), findsNothing);
        expect(find.text('Later caption'), findsNothing);
        final runningVideoBounds = tester.getRect(find.byType(VideoPlayer));
        expect(runningVideoBounds, readyThumbnailBounds);
        expect(
          runningVideoBounds.height,
          closeTo(
            preview.video.aspectRatio >=
                    frameBounds.width / (frameBounds.height - 68)
                ? frameBounds.width / preview.video.aspectRatio
                : frameBounds.height - 68,
            0.01,
          ),
        );
        expect(
          runningVideoBounds.top -
              tester
                  .getBottomLeft(
                    find.byKey(const ValueKey('thumbnail-edit-action')),
                  )
                  .dy,
          closeTo(6, 0.01),
        );
        expect(
          runningVideoBounds.width / runningVideoBounds.height,
          closeTo(platform.videoSize.width / platform.videoSize.height, 0.01),
        );
        final actions = find.ancestor(
          of: find.text(AppStrings.trainingViewTranscript),
          matching: find.byType(TextButton),
        );
        expect(
          tester.getTopLeft(actions).dy -
              tester.getBottomLeft(find.byType(VideoPlayer)).dy,
          closeTo(6, 0.01),
        );
        expect(tester.getRect(frame), frameBounds);
        await disposePlayer(tester);
        debugNetworkImageHttpClientProvider = originalImageClientProvider;
      },
    );
  }

  testWidgets(
    'shared panel keeps its transcript and playback controller in fullscreen',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = await mountPlayer(
        tester,
        transcript: '[00:00] Introduction\n[00:15] Active caption',
      );
      await controller.seekTo(const Duration(seconds: 20));
      await tester.pump();
      final transcript = tester
          .element(find.text('Active caption'))
          .read<ComplianceVideoController>();
      await tester.tap(find.byKey(const ValueKey('video-fullscreen-button')));
      await tester.pumpAndSettle();
      expect(find.byType(ComplianceFullScreenVideoView), findsOneWidget);
      expect(find.text('Active caption'), findsOneWidget);
      expect(
        tester
            .element(find.text(AppStrings.trainingViewTranscript))
            .read<ComplianceVideoController>(),
        same(transcript),
      );
      expect(
        tester.widget<VideoPlayer>(find.byType(VideoPlayer)).controller,
        same(controller),
      );
      await tester.tap(find.text(AppStrings.trainingViewTranscript));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(BottomSheet),
          matching: find.text('Introduction'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsNothing);
      expect(controller.value.position, Duration.zero);
      expect(controller.value.isPlaying, isTrue);
      expect(find.byType(AppBackButton), findsNothing);
      final exitButton = find.byKey(
        const ValueKey('video-exit-fullscreen-button'),
      );
      expect(exitButton.hitTestable(), findsNothing);
      await tester.tap(find.text('Introduction'));
      await tester.pump();
      expect(exitButton.hitTestable(), findsOneWidget);
      await tester.tap(exitButton);
      await tester.pumpAndSettle();
      expect(find.byType(ComplianceFullScreenVideoView), findsNothing);
      expect(find.text('Introduction'), findsOneWidget);
      expect(
        tester.widget<VideoPlayer>(find.byType(VideoPlayer)).controller,
        same(controller),
      );
      await disposePlayer(tester);
    },
  );

  testWidgets(
    'caption writing follows native playback and freezes when paused',
    (tester) async {
      final controller = await mountPlayer(
        tester,
        transcript: '[00:00 --> 00:05] First second third fourth',
        disableAnimations: false,
      );
      expect(find.text('First'), findsOneWidget);
      await tester.pump(const Duration(seconds: 2));
      expect(find.text('First'), findsOneWidget);

      await controller.play();
      await tester.pump();
      platform.position = const Duration(milliseconds: 1250);
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();
      expect(find.text('First second'), findsOneWidget);

      await controller.pause();
      await tester.pump(const Duration(seconds: 2));
      expect(find.text('First second'), findsOneWidget);
      await controller.play();
      platform.position = const Duration(milliseconds: 2500);
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();
      expect(find.text('First second third'), findsOneWidget);

      await controller.pause();
      await tester.tap(find.byKey(const ValueKey('video-fullscreen-button')));
      await tester.pumpAndSettle();
      expect(find.byType(ComplianceFullScreenVideoView), findsOneWidget);
      expect(find.text('First second third'), findsOneWidget);
      expect(
        tester.widget<Text>(find.text('First second third')).textAlign,
        TextAlign.left,
      );
      await controller.seekTo(Duration.zero);
      await tester.pump();
      expect(find.text('First'), findsOneWidget);
      await controller.seekTo(const Duration(milliseconds: 3750));
      await tester.pump();
      expect(find.text('First second third fourth'), findsOneWidget);
      await tester.tap(
        find.byKey(const ValueKey('video-exit-fullscreen-button')),
      );
      await tester.pumpAndSettle();
      expect(find.byType(ComplianceFullScreenVideoView), findsNothing);
      expect(find.text('First second third fourth'), findsOneWidget);
      expect(
        tester.widget<VideoPlayer>(find.byType(VideoPlayer)).controller,
        same(controller),
      );
      await disposePlayer(tester);
    },
  );

  testWidgets(
    'captions overlay the image through playback, CC, timing gaps and completion',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      const secondCaption = 'Second caption\nA second line\nAnd a third line';
      final controller = await mountPlayer(
        tester,
        transcript: '[00:00 --> 00:04] First caption\n[00:10] $secondCaption',
      );
      final frame = find.byKey(const ValueKey('training-video-frame'));
      final frameBounds = tester.getRect(frame);
      expect(frameBounds.width, 390);
      expect(frameBounds.height, 383);
      final seekBounds = tester.getRect(find.byType(Slider));
      final titleBounds = tester.getRect(find.text('Lesson'));
      final mediaBounds = tester.getRect(find.byType(VideoPlayer));
      expect(mediaBounds.left, closeTo(frameBounds.left, 0.01));
      expect(mediaBounds.right, closeTo(frameBounds.right, 0.01));
      expect(mediaBounds.top, greaterThanOrEqualTo(frameBounds.top));
      expect(mediaBounds.bottom, lessThanOrEqualTo(frameBounds.bottom));
      expect(mediaBounds.width / mediaBounds.height, closeTo(16 / 9, 0.01));
      expect(titleBounds.top - mediaBounds.bottom, closeTo(10, 0.01));
      final surface = find
          .descendant(
            of: find.byType(ComplianceVideoTranscriptPanel),
            matching: find.byType(Material),
          )
          .first;
      final expandedHeight = tester.getSize(surface).height;
      expectCaptionOverlay(tester, find.text('First caption'));
      expectSeekActionGap(tester);
      final overlayBounds = tester.getRect(
        find.byKey(const ValueKey('active-video-caption')),
      );

      await tester.tap(find.byIcon(Icons.play_arrow_rounded));
      await tester.pump();
      expectControls(visible: false);
      expectCaptionOverlay(tester, find.text('First caption'));
      final collapsedHeight = tester.getSize(surface).height;
      expect(collapsedHeight, lessThan(expandedHeight));
      expect(tester.getRect(frame), frameBounds);
      expect(tester.getRect(find.byType(VideoPlayer)), mediaBounds);

      await tester.tap(find.text('First caption'));
      await tester.pump();
      expectControls(visible: true);
      expect(tester.getRect(find.byType(Slider)), seekBounds);
      expect(tester.getRect(find.text('Lesson')), titleBounds);
      expect(
        tester.getRect(find.byKey(const ValueKey('active-video-caption'))),
        overlayBounds,
      );
      await tester.pump(const Duration(milliseconds: 2999));
      expectControls(visible: true);
      await tester.pump(const Duration(milliseconds: 1));
      expectControls(visible: false);

      await controller.seekTo(const Duration(seconds: 15));
      await tester.pump();
      final caption = find.text(secondCaption);
      expectCaptionOverlay(tester, caption);
      final paragraph = tester.renderObject<RenderParagraph>(
        find.descendant(of: caption, matching: find.byType(RichText)),
      );
      expect(paragraph.didExceedMaxLines, isTrue);
      expect(tester.getSize(surface).height, collapsedHeight);
      await tester.tap(find.text(AppStrings.trainingCc));
      await tester.pump();
      expect(caption, findsNothing);
      expect(find.byKey(const ValueKey('active-video-caption')), findsNothing);
      expect(tester.getSize(surface).height, collapsedHeight);
      expect(controller.value.isPlaying, isTrue);

      await tapVideo(tester);
      expectControls(visible: true);
      expectSeekActionGap(tester);
      expect(tester.getRect(find.byType(Slider)), seekBounds);
      await tester.tap(find.text(AppStrings.trainingCc));
      await tester.pump();
      expectCaptionOverlay(tester, caption);
      await tester.tap(find.byIcon(Icons.pause_rounded));
      await tester.pump(const Duration(seconds: 4));
      expectControls(visible: true, playing: false);
      expect(tester.getSize(surface).height, expandedHeight);
      expectCaptionOverlay(tester, caption);
      await tester.tap(find.byIcon(Icons.play_arrow_rounded));
      await tester.pump();
      await completeVideo(tester);
      expectControls(visible: true, playing: false);
      expectCaptionOverlay(tester, caption);
      expect(tester.getRect(frame), frameBounds);
      expect(
        tester.widget<VideoPlayer>(find.byType(VideoPlayer)).controller,
        same(controller),
      );

      await controller.seekTo(const Duration(seconds: 5));
      await tester.pump();
      expect(caption, findsNothing);
      expectSeekActionGap(tester);
      expect(tester.getRect(find.byType(Slider)), seekBounds);
      await disposePlayer(tester);
    },
  );

  testWidgets(
    'portrait videos preserve their sides and keep captions within the image',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      platform.videoSize = const Size(360, 640);
      await mountPlayer(tester, transcript: '[00:00] Portrait caption');
      final frame = tester.getRect(
        find.byKey(const ValueKey('training-video-frame')),
      );
      final media = tester.getRect(find.byType(VideoPlayer));
      expect(media.height, closeTo(frame.height - 46, 0.01));
      expect(media.top - frame.top, closeTo(46, 0.01));
      expect(
        media.top -
            tester
                .getBottomLeft(
                  find.byKey(const ValueKey('video-fullscreen-button')),
                )
                .dy,
        greaterThanOrEqualTo(6),
      );
      expect(media.width / media.height, closeTo(9 / 16, 0.01));
      expect(media.left, greaterThan(frame.left));
      expect(media.right, lessThan(frame.right));
      expect(media.center.dx, closeTo(frame.center.dx, 0.01));
      expectCaptionOverlay(tester, find.text('Portrait caption'));
      expect(
        tester.getTopLeft(find.text('Lesson')).dy - media.bottom,
        closeTo(10, 0.01),
      );
      await tester.tap(find.byIcon(Icons.play_arrow_rounded));
      await tester.pump();
      expectCaptionOverlay(tester, find.text('Portrait caption'));
      expect(tester.getRect(find.byType(VideoPlayer)), media);
      await disposePlayer(tester);
    },
  );

  testWidgets(
    'long scaled captions ellipsize inside the image while the transcript keeps full text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final cue = List.filled(
        30,
        'A complete long transcript line that wraps naturally',
      ).join('\n');
      final controller = await mountPlayer(
        tester,
        transcript: '[00:00] $cue',
        textScale: 2,
      );
      final frame = find.byKey(const ValueKey('training-video-frame'));
      final frameBounds = tester.getRect(frame);
      final seekBounds = tester.getRect(find.byType(Slider));
      expect(frameBounds.width, 320);
      expect(frameBounds.height, 281);
      await tester.tap(find.byIcon(Icons.play_arrow_rounded));
      await tester.pump();
      final caption = find.text(cue);
      expectCaptionOverlay(tester, caption);
      final paragraph = tester.renderObject<RenderParagraph>(
        find.descendant(of: caption, matching: find.byType(RichText)),
      );
      expect(paragraph.didExceedMaxLines, isTrue);
      await tester.tap(caption);
      await tester.pump();
      expect(find.byType(Slider), findsOneWidget);
      expect(tester.getRect(find.byType(Slider)), seekBounds);
      expectCaptionOverlay(tester, caption);
      await tester.tap(find.byType(Slider));
      await tester.pump();
      expect(controller.value.position, greaterThan(Duration.zero));
      expect(tester.getRect(frame), frameBounds);
      await tester.tap(find.text(AppStrings.trainingViewTranscript));
      await tester.pumpAndSettle();
      expect(
        find.descendant(of: find.byType(BottomSheet), matching: find.text(cue)),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();
      await disposePlayer(tester);
    },
  );

  testWidgets(
    'transcript jumps retry temporary native seek and play failures',
    (tester) async {
      Future<bool> Function(Duration)? seek;
      final controller = await mountPlayer(
        tester,
        onSeekHandlerChanged: (handler) => seek = handler,
      );
      platform.seekFailures = 1;
      platform.playFailures = 1;
      expect(await seek!(const Duration(seconds: 15)), isTrue);
      await tester.pump();
      expect(controller.value.position, const Duration(seconds: 15));
      expect(controller.value.isPlaying, isTrue);
      expectControls(visible: true);
      expect(
        find.byKey(const ValueKey('video-fullscreen-button')),
        findsOneWidget,
      );
      await disposePlayer(tester);
      expect(seek, isNull);
    },
  );

  testWidgets(
    'failed transcript jumps remain retryable and clamp to the video duration',
    (tester) async {
      Future<bool> Function(Duration)? seek;
      final controller = await mountPlayer(
        tester,
        onSeekHandlerChanged: (handler) => seek = handler,
      );
      platform.seekFailures = 3;
      expect(await seek!(const Duration(seconds: 10)), isFalse);
      expect(await seek!(const Duration(minutes: 2)), isTrue);
      await tester.pump();
      expect(controller.value.position, const Duration(minutes: 1));
      expect(controller.value.isPlaying, isFalse);
      await disposePlayer(tester);
    },
  );

  testWidgets(
    'transcript jumps wait for initialization before seeking and playing',
    (tester) async {
      platform.autoInitialize = false;
      Future<bool> Function(Duration)? seek;
      await tester.runAsync(() async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ComplianceVideoPlayer(
                videoUrl: '',
                localVideoPath: videoPath,
                title: 'Lesson',
                onSeekHandlerChanged: (handler) => seek = handler,
              ),
            ),
          ),
        );
        final pending = seek!(const Duration(seconds: 12));
        await platform.created.future;
        expect(platform.position, Duration.zero);
        platform.initialize();
        expect(await pending, isTrue);
      });
      await tester.pump();
      final controller = tester
          .widget<VideoPlayer>(find.byType(VideoPlayer))
          .controller;
      expect(controller.value.position, const Duration(seconds: 12));
      expect(controller.value.isPlaying, isTrue);
      await disposePlayer(tester);
    },
  );

  testWidgets('hides on play and reveals controls for exactly three seconds', (
    tester,
  ) async {
    final controller = await mountPlayer(tester);
    expectControls(visible: true, playing: false);

    await tester.tap(find.byIcon(Icons.play_arrow_rounded));
    await tester.pump();
    expect(controller.value.isPlaying, isTrue);
    expectControls(visible: false);

    await tapVideo(tester);
    expectControls(visible: true);
    expect(controller.value.isPlaying, isTrue);
    await tester.pump(const Duration(milliseconds: 2999));
    expectControls(visible: true);
    await tester.pump(const Duration(milliseconds: 1));
    expectControls(visible: false);

    await disposePlayer(tester);
  });

  testWidgets('tapping again and skipping restart the three-second timer', (
    tester,
  ) async {
    final controller = await mountPlayer(tester);
    await tester.tap(find.byIcon(Icons.play_arrow_rounded));
    await tester.pump();
    await tapVideo(tester);
    await tester.pump(const Duration(seconds: 2));
    await tapVideo(tester);
    await tester.pump(const Duration(seconds: 2));
    expectControls(visible: true);

    await tester.tap(find.byIcon(Icons.forward_10_rounded));
    await tester.pump();
    expect(controller.value.position, const Duration(seconds: 10));
    await tester.pump(const Duration(seconds: 2));
    expectControls(visible: true);
    await tester.tap(find.byIcon(Icons.replay_10_rounded));
    await tester.pump();
    expect(controller.value.position, Duration.zero);
    await tester.pump(const Duration(milliseconds: 2999));
    expectControls(visible: true);
    await tester.pump(const Duration(milliseconds: 1));
    expectControls(visible: false);

    await disposePlayer(tester);
  });

  testWidgets('keeps paused controls visible and hides them again on resume', (
    tester,
  ) async {
    final controller = await mountPlayer(tester);
    await tester.tap(find.byIcon(Icons.play_arrow_rounded));
    await tester.pump();
    await tapVideo(tester);
    await tester.tap(find.byIcon(Icons.pause_rounded));
    await tester.pump(const Duration(seconds: 4));
    expect(controller.value.isPlaying, isFalse);
    expectControls(visible: true, playing: false);

    await tester.tap(find.byIcon(Icons.play_arrow_rounded));
    await tester.pump();
    expectControls(visible: false);
    await tapVideo(tester);
    // Removing a player with a pending hide timer must also cancel that timer.
    await disposePlayer(tester);
  });

  testWidgets('restores controls at completion and hides them on replay', (
    tester,
  ) async {
    final controller = await mountPlayer(tester);
    await tester.tap(find.byIcon(Icons.play_arrow_rounded));
    await tester.pump();
    await completeVideo(tester);
    await tester.pump(const Duration(seconds: 4));
    expectControls(visible: true, playing: false);
    expect(controller.value.position, controller.value.duration);

    await tester.tap(find.byIcon(Icons.play_arrow_rounded));
    await tester.pump();
    expect(controller.value.position, Duration.zero);
    expect(controller.value.isPlaying, isTrue);
    expectControls(visible: false);
    await tapVideo(tester);
    await completeVideo(tester);
    await tester.pump(const Duration(seconds: 4));
    expectControls(visible: true, playing: false);

    await disposePlayer(tester);
  });

  testWidgets(
    'keeps the overlay visible while scrubbing and hides after release',
    (tester) async {
      final controller = await mountPlayer(tester);
      await tester.tap(find.byIcon(Icons.play_arrow_rounded));
      await tester.pump();
      await tapVideo(tester);

      final slider = find.byType(Slider);
      final center = tester.getCenter(slider);
      final gesture = await tester.startGesture(center);
      await gesture.moveBy(const Offset(20, 0));
      await tester.pump(const Duration(seconds: 4));
      expectControls(visible: true);
      await gesture.up();
      await tester.pump();
      expect(controller.value.position, greaterThan(Duration.zero));
      expect(controller.value.isPlaying, isTrue);

      await tester.pump(const Duration(milliseconds: 2999));
      expectControls(visible: true);
      await tester.pump(const Duration(milliseconds: 1));
      expectControls(visible: false);
      await disposePlayer(tester);
    },
  );
}

Future<List<Color>> _previewPixelColors(
  WidgetTester tester,
  List<Offset> points,
) async {
  final boundaryFinder = find.byKey(const ValueKey('video-preview-pixels'));
  final boundary = tester.renderObject<RenderRepaintBoundary>(boundaryFinder);
  final origin = tester.getTopLeft(boundaryFinder);
  return (await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1);
    try {
      final bytes = (await image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      ))!.buffer.asUint8List();
      return points.map((point) {
        final local = point - origin;
        final index = (local.dy.floor() * image.width + local.dx.floor()) * 4;
        return Color.fromARGB(
          bytes[index + 3],
          bytes[index],
          bytes[index + 1],
          bytes[index + 2],
        );
      }).toList();
    } finally {
      image.dispose();
    }
  }))!;
}

class _LocalImageHttpOverrides extends HttpOverrides {}

class _FakeVideoPlatform extends VideoPlayerPlatform {
  final initialized = Completer<void>();
  final created = Completer<void>();
  bool autoInitialize = true;
  Size videoSize = const Size(640, 360);
  int seekFailures = 0;
  int playFailures = 0;
  final events = StreamController<VideoEvent>();
  Duration position = Duration.zero;

  @override
  Future<void> init() async {}

  @override
  Future<int> createWithOptions(VideoCreationOptions options) async {
    if (autoInitialize) initialize();
    created.complete();
    return 1;
  }

  void initialize() {
    events.add(
      VideoEvent(
        eventType: VideoEventType.initialized,
        duration: const Duration(minutes: 1),
        size: videoSize,
      ),
    );
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
  Future<void> play(int playerId) async {
    if (playFailures > 0) {
      playFailures--;
      throw StateError('Temporary native play failure');
    }
  }

  @override
  Future<void> pause(int playerId) async {}

  @override
  Future<void> seekTo(int playerId, Duration position) async {
    if (seekFailures > 0) {
      seekFailures--;
      throw StateError('Temporary native seek failure');
    }
    this.position = position;
  }

  @override
  Future<Duration> getPosition(int playerId) async => position;

  @override
  Widget buildViewWithOptions(VideoViewOptions options) => const SizedBox();

  @override
  Future<void> dispose(int playerId) async => events.close();
}
