import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';
import 'package:sparrowkaizen/core/constants/app_colors.dart';
import 'package:sparrowkaizen/core/constants/app_strings.dart';
import 'package:sparrowkaizen/core/widgets/app_back_button.dart';
import 'package:sparrowkaizen/features/compliance/presentation/pages/training/compliance_full_screen_video_view.dart';
import 'package:sparrowkaizen/features/compliance/presentation/providers/compliance_video_controller.dart';
import 'package:video_player/video_player.dart';
// ignore: depend_on_referenced_packages
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

void main() {
  const fullscreenChannel = MethodChannel('kaizenteams/video_fullscreen');
  late VideoPlayerPlatform originalPlatform;
  late _VideoPlatform platform;
  late VideoPlayerController controller;
  final orientationRequests = <List<dynamic>>[];
  const fullscreenOrientations = [
    'DeviceOrientation.portraitUp',
    'DeviceOrientation.landscapeLeft',
    'DeviceOrientation.landscapeRight',
  ];
  final fullscreenRequests = <bool>[];
  final systemUiRequests = <String>[];

  setUp(() {
    originalPlatform = VideoPlayerPlatform.instance;
    platform = _VideoPlatform();
    VideoPlayerPlatform.instance = platform;
    orientationRequests.clear();
    fullscreenRequests.clear();
    systemUiRequests.clear();
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'SystemChrome.setPreferredOrientations') {
        orientationRequests.add(call.arguments as List<dynamic>);
      } else if (call.method == 'SystemChrome.setEnabledSystemUIMode') {
        systemUiRequests.add(call.arguments as String);
      }
      return null;
    });
    messenger.setMockMethodCallHandler(fullscreenChannel, (call) async {
      fullscreenRequests.add((call.arguments as Map)['enabled'] as bool);
      return null;
    });
  });

  tearDown(() async {
    await controller.dispose();
    VideoPlayerPlatform.instance = originalPlatform;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, null);
    messenger.setMockMethodCallHandler(fullscreenChannel, null);
  });

  Future<void> openPlayer(
    WidgetTester tester, {
    bool playing = true,
    ComplianceVideoController? transcriptController,
    double textScale = 1,
    Duration initialPosition = const Duration(seconds: 20),
    bool disableAnimations = false,
  }) async {
    controller = VideoPlayerController.networkUrl(
      Uri.parse('https://example.com/video.mp4'),
    );
    await tester.runAsync(() async {
      await controller.initialize();
      await controller.seekTo(initialPosition);
      if (playing) await controller.play();
    });
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(textScale),
            disableAnimations: disableAnimations,
          ),
          child: child!,
        ),
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () => Navigator.of(context).push<void>(
                MaterialPageRoute(
                  builder: (_) {
                    final view = ComplianceFullScreenVideoView(
                      controller: controller,
                      title: 'Lesson',
                      initialPosition: controller.value.position,
                    );
                    return transcriptController == null
                        ? view
                        : ChangeNotifierProvider<
                            ComplianceVideoController
                          >.value(value: transcriptController, child: view);
                  },
                ),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  Future<void> tapVideo(WidgetTester tester) async {
    await tester.tapAt(const Offset(80, 80));
    await tester.pump();
  }

  Future<void> revealPlayingControls(WidgetTester tester) async {
    await tapVideo(tester);
    expect(controller.value.isPlaying, isFalse);
    await tapVideo(tester);
    expect(controller.value.isPlaying, isTrue);
  }

  void expectControls({required bool visible}) {
    expect(find.byType(AppBackButton), findsNothing);
    final matcher = visible ? findsOneWidget : findsNothing;
    for (final finder in [
      find.text('Lesson'),
      find.text(AppStrings.trainingViewTranscript),
      find.byType(Slider),
      find.byIcon(Icons.replay_10_rounded),
      find.byIcon(Icons.forward_10_rounded),
      find.byIcon(
        controller.value.isPlaying
            ? Icons.pause_rounded
            : Icons.play_arrow_rounded,
      ),
      find.byKey(const ValueKey('video-exit-fullscreen-button')),
    ]) {
      expect(finder.hitTestable(), matcher);
    }
  }

  for (final screenSize in [const Size(390, 844), const Size(844, 390)]) {
    testWidgets(
      'fullscreen video and black area taps toggle playback and reveal controls at $screenSize',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = screenSize;
        addTearDown(tester.view.reset);
        await openPlayer(tester, playing: false);
        final video = find.byType(VideoPlayer);
        final videoState = tester.state(video);
        final blackArea = screenSize.width < screenSize.height
            ? const Offset(80, 80)
            : const Offset(20, 100);
        expect(tester.getRect(video).contains(blackArea), isFalse);

        await tester.tapAt(blackArea);
        await tester.pump();
        expect(controller.value.isPlaying, isTrue);
        expectControls(visible: true);
        final videoBounds = tester.getRect(video);
        await tester.tapAt(
          videoBounds.topLeft +
              Offset(videoBounds.width * 0.25, videoBounds.height * 0.25),
        );
        await tester.pump(const Duration(seconds: 4));
        expect(controller.value.isPlaying, isFalse);
        expectControls(visible: true);
        await tester.tapAt(blackArea);
        await tester.pump();
        expect(controller.value.isPlaying, isTrue);
        expectControls(visible: true);
        await tester.pump(const Duration(milliseconds: 2999));
        expectControls(visible: true);
        await tester.pump(const Duration(milliseconds: 1));
        expectControls(visible: false);
        expect(controller.value.position, const Duration(seconds: 20));
        expect(tester.state(video), same(videoState));
        await tester.pumpWidget(const SizedBox.shrink());
        await controller.pause();
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'fullscreen captions keep a bottom gap during playback and restore on reveal at $screenSize',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = screenSize;
        addTearDown(tester.view.reset);
        final transcript = ComplianceVideoController(
          '[00:10 --> 00:30] Active caption',
        );
        addTearDown(transcript.dispose);
        await openPlayer(tester, transcriptController: transcript);
        final caption = find.byKey(
          const ValueKey('fullscreen-active-transcript'),
        );
        final hiddenCaptionBounds = tester.getRect(caption);
        final videoState = tester.state(find.byType(VideoPlayer));
        expectControls(visible: false);
        expect(find.text('Active caption').hitTestable(), findsOneWidget);

        await tester.tap(caption);
        await tester.pump();
        expect(controller.value.isPlaying, isFalse);
        expectControls(visible: true);
        final visibleCaptionBounds = tester.getRect(caption);
        final titleRow = find
            .ancestor(of: find.text('Lesson'), matching: find.byType(Row))
            .first;
        final seekRow = find
            .ancestor(of: find.byType(Slider), matching: find.byType(Row))
            .first;
        final seekBounds = tester.getRect(seekRow);
        expect(
          hiddenCaptionBounds.bottom,
          closeTo(seekBounds.bottom - 8, 0.01),
        );
        expect(hiddenCaptionBounds.size, visibleCaptionBounds.size);
        expect(hiddenCaptionBounds.top, greaterThan(visibleCaptionBounds.top));
        expect(
          tester.getTopLeft(titleRow).dy - visibleCaptionBounds.bottom,
          closeTo(6, 0.01),
        );
        await tester.pump(const Duration(seconds: 4));
        expectControls(visible: true);
        await tester.tap(caption);
        await tester.pump();
        expect(controller.value.isPlaying, isTrue);
        await tester.pump(const Duration(milliseconds: 2999));
        expectControls(visible: true);
        await tester.pump(const Duration(milliseconds: 1));
        expectControls(visible: false);
        expect(tester.getRect(caption), hiddenCaptionBounds);
        expect(find.text('Active caption').hitTestable(), findsOneWidget);

        await tapVideo(tester);
        expect(tester.getRect(caption), visibleCaptionBounds);
        expect(tester.getRect(seekRow), seekBounds);
        await tester.pump(const Duration(seconds: 2));
        await tapVideo(tester);
        await tester.pump(const Duration(milliseconds: 2999));
        expectControls(visible: true);
        await tester.pump(const Duration(milliseconds: 1));
        expectControls(visible: false);
        expect(tester.getRect(caption), hiddenCaptionBounds);
        expect(tester.state(find.byType(VideoPlayer)), same(videoState));
        expect(controller.value.isPlaying, isTrue);
        await tester.pumpWidget(const SizedBox.shrink());
        await controller.pause();
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'fullscreen keeps paused and completed controls visible and hides on replay',
    (tester) async {
      await openPlayer(tester, playing: false);
      await tester.pump(const Duration(seconds: 4));
      expectControls(visible: true);
      await tester.tap(find.byIcon(Icons.play_arrow_rounded));
      await tester.pump();
      expectControls(visible: false);

      await revealPlayingControls(tester);
      await tester.tap(find.byIcon(Icons.pause_rounded));
      await tester.pump(const Duration(seconds: 4));
      expect(controller.value.isPlaying, isFalse);
      expectControls(visible: true);
      await tester.tap(find.byIcon(Icons.play_arrow_rounded));
      await tester.pump();
      expectControls(visible: false);

      await revealPlayingControls(tester);
      await tester.runAsync(() async {
        platform._events.add(VideoEvent(eventType: VideoEventType.completed));
        await Future<void>.delayed(Duration.zero);
      });
      await tester.pump(const Duration(seconds: 4));
      expect(controller.value.position, controller.value.duration);
      expectControls(visible: true);
      await tester.tap(find.byIcon(Icons.play_arrow_rounded));
      await tester.pump();
      expect(controller.value.position, Duration.zero);
      expect(controller.value.isPlaying, isTrue);
      expectControls(visible: false);

      await revealPlayingControls(tester);
      await tester.pumpWidget(const SizedBox.shrink());
      await controller.pause();
      await tester.pump(const Duration(seconds: 4));
      expect(tester.takeException(), isNull);
    },
  );

  for (final playing in [false, true]) {
    testWidgets(
      'fullscreen 10-second skips preserve playback, clamp at the ends, and restart hiding (playing: $playing)',
      (tester) async {
        await openPlayer(tester, playing: playing);
        if (playing) await revealPlayingControls(tester);

        await tester.tap(find.byIcon(Icons.forward_10_rounded));
        await tester.pump();
        expect(controller.value.position, const Duration(seconds: 30));
        expect(controller.value.isPlaying, playing);
        await tester.pump(const Duration(seconds: 2));
        expectControls(visible: true);

        await tester.tap(find.byIcon(Icons.replay_10_rounded));
        await tester.pump();
        expect(controller.value.position, const Duration(seconds: 20));
        expect(controller.value.isPlaying, playing);
        await tester.pump(const Duration(milliseconds: 2999));
        expectControls(visible: true);
        await tester.pump(const Duration(milliseconds: 1));
        expectControls(visible: !playing);

        if (playing) await revealPlayingControls(tester);
        await controller.seekTo(const Duration(seconds: 5));
        await tester.pump();
        await tester.tap(find.byIcon(Icons.replay_10_rounded));
        await tester.pump();
        expect(controller.value.position, Duration.zero);
        expect(controller.value.isPlaying, playing);

        await controller.seekTo(const Duration(seconds: 55));
        await tester.pump();
        await tester.tap(find.byIcon(Icons.forward_10_rounded));
        await tester.pump();
        expect(controller.value.position, controller.value.duration);
        expect(controller.value.isPlaying, playing);
        expectControls(visible: true);

        await tester.pumpWidget(const SizedBox.shrink());
        await controller.pause();
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'fullscreen keeps controls visible while scrubbing and restarts the hide timer on release',
    (tester) async {
      await openPlayer(tester);
      await revealPlayingControls(tester);
      final slider = find.byType(Slider);
      final gesture = await tester.startGesture(tester.getCenter(slider));
      await gesture.moveBy(const Offset(20, 0));
      await tester.pump(const Duration(seconds: 4));
      expectControls(visible: true);
      await gesture.up();
      await tester.pump();
      expect(
        controller.value.position,
        greaterThan(const Duration(seconds: 20)),
      );
      expect(controller.value.isPlaying, isTrue);
      await tester.pump(const Duration(milliseconds: 2999));
      expectControls(visible: true);
      await tester.pump(const Duration(milliseconds: 1));
      expectControls(visible: false);
      await tester.pumpWidget(const SizedBox.shrink());
      await controller.pause();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'fullscreen captions write left to right with playback and pause with the video',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.reset);
      const firstCue = 'First second\nthird fourth';
      final transcript = ComplianceVideoController(
        '[00:00 --> 00:05] $firstCue\n[00:06 --> 00:08] Next caption',
      );
      addTearDown(transcript.dispose);
      await openPlayer(
        tester,
        playing: false,
        initialPosition: Duration.zero,
        transcriptController: transcript,
      );
      expect(find.text('First'), findsOneWidget);
      expect(tester.widget<Text>(find.text('First')).textAlign, TextAlign.left);
      final captionLeft = tester.getTopLeft(find.text('First')).dx;
      await tester.pump(const Duration(seconds: 2));
      expect(find.text('First'), findsOneWidget);

      await controller.play();
      platform.position = const Duration(milliseconds: 1250);
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();
      expect(find.text('First second'), findsOneWidget);
      expect(tester.getTopLeft(find.text('First second')).dx, captionLeft);
      await controller.pause();
      await tester.pump(const Duration(seconds: 2));
      expect(find.text('First second'), findsOneWidget);

      await controller.seekTo(const Duration(milliseconds: 2500));
      await tester.pump();
      expect(find.text('First second\nthird'), findsOneWidget);
      await controller.seekTo(const Duration(milliseconds: 3750));
      await tester.pump();
      expect(find.text(firstCue), findsOneWidget);
      expect(tester.getTopLeft(find.text(firstCue)).dx, captionLeft);
      await controller.seekTo(Duration.zero);
      await tester.pump();
      expect(find.text('First'), findsOneWidget);
      transcript.toggleCc();
      await controller.seekTo(const Duration(milliseconds: 2500));
      await tester.pump();
      expect(
        find.byKey(const ValueKey('fullscreen-active-transcript')),
        findsNothing,
      );
      transcript.toggleCc();
      await tester.pump();
      expect(find.text('First second\nthird'), findsOneWidget);
      await controller.seekTo(const Duration(seconds: 5));
      await tester.pump();
      expect(
        find.byKey(const ValueKey('fullscreen-active-transcript')),
        findsNothing,
      );
      await controller.seekTo(const Duration(seconds: 6));
      await tester.pump();
      expect(find.text('Next'), findsOneWidget);

      await tester.tap(find.text(AppStrings.trainingViewTranscript));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(BottomSheet),
          matching: find.text(firstCue),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(BottomSheet),
          matching: find.text('Next caption'),
        ),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'fullscreen reduced motion shows the complete caption immediately',
    (tester) async {
      const cue = 'First second third fourth';
      final transcript = ComplianceVideoController('[00:00 --> 00:05] $cue');
      addTearDown(transcript.dispose);
      await openPlayer(
        tester,
        playing: false,
        initialPosition: Duration.zero,
        transcriptController: transcript,
        disableAnimations: true,
      );
      expect(find.text(cue), findsOneWidget);
      expect(transcript.activeTranscriptText, cue);
      await tester.pumpWidget(const SizedBox.shrink());
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'fullscreen captions sit above the title and transcript rows seek playback',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.reset);
      final transcript = ComplianceVideoController(
        '[00:00 --> 00:05] Introduction\n[00:10 --> 00:30] Active caption',
      );
      addTearDown(transcript.dispose);
      transcript.setSeekHandler((position) async {
        await controller.seekTo(position);
        await controller.play();
        return true;
      });
      await openPlayer(
        tester,
        playing: false,
        transcriptController: transcript,
      );
      final titleRow = find
          .ancestor(of: find.text('Lesson'), matching: find.byType(Row))
          .first;
      final titleBounds = tester.getRect(titleRow);
      final captionContainer = find.byKey(
        const ValueKey('fullscreen-active-transcript'),
      );
      expect(
        tester.getTopLeft(titleRow).dy -
            tester.getBottomLeft(captionContainer).dy,
        closeTo(6, 0.01),
      );
      final action = find.ancestor(
        of: find.text(AppStrings.trainingViewTranscript),
        matching: find.byType(TextButton),
      );
      expect(tester.getBottomRight(action).dx, titleBounds.right);
      final captionBounds = tester.getRect(find.text('Active caption'));
      expect(captionBounds.left, titleBounds.left + 16);
      expect(captionBounds.right, titleBounds.right - 16);
      expect(
        tester.getCenter(find.byIcon(Icons.play_arrow_rounded)).dx,
        tester.getCenter(find.byType(VideoPlayer)).dx,
      );
      expect(
        tester.getBottomRight(find.text(AppStrings.trainingViewTranscript)).dx,
        titleBounds.right,
      );
      final exitButton = find.byKey(
        const ValueKey('video-exit-fullscreen-button'),
      );
      expect(tester.getBottomRight(exitButton).dx, titleBounds.right);
      expect(
        tester.getBottomRight(find.text('00:20/01:00')).dx,
        lessThanOrEqualTo(tester.getTopLeft(exitButton).dx),
      );

      await controller.seekTo(const Duration(seconds: 35));
      await tester.pump();
      expect(find.text('Active caption'), findsNothing);
      expect(tester.getRect(titleRow), titleBounds);
      await controller.seekTo(const Duration(seconds: 20));
      await tester.pump();
      transcript.toggleCc();
      await tester.pump();
      expect(find.text('Active caption'), findsNothing);
      expect(tester.getRect(titleRow), titleBounds);
      transcript.toggleCc();
      await tester.pump();
      await tester.tap(action);
      await tester.pumpAndSettle();
      final activeSheetCaption = find.descendant(
        of: find.byType(BottomSheet),
        matching: find.text('Active caption'),
      );
      expect(
        tester.widget<Text>(activeSheetCaption).style?.color,
        AppColors.secondaryColor,
      );
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
      expect(find.text('Introduction'), findsOneWidget);
      expect(
        tester.getBottomLeft(captionContainer).dy,
        tester
            .getBottomLeft(
              find.byKey(const ValueKey('fullscreen-video-footer')),
            )
            .dy,
      );
      await tester.tap(captionContainer);
      await tester.pump();
      expect(
        tester.getTopLeft(titleRow).dy -
            tester.getBottomLeft(captionContainer).dy,
        closeTo(6, 0.01),
      );
      await controller.pause();
      await tester.pumpWidget(const SizedBox.shrink());
      expect(tester.takeException(), isNull);
    },
  );

  for (final screenSize in [const Size(320, 640), const Size(844, 390)]) {
    testWidgets(
      'long fullscreen captions retain their scroll position as words appear at $screenSize',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = screenSize;
        addTearDown(tester.view.reset);
        final cue = List.filled(
          30,
          'Long caption content that wraps across the display',
        ).join('\n');
        final transcript = ComplianceVideoController('[00:00 --> 01:00] $cue');
        addTearDown(transcript.dispose);
        await openPlayer(
          tester,
          playing: false,
          transcriptController: transcript,
          textScale: 2,
        );
        expect(transcript.activeTranscriptText, isNot(cue));
        final caption = find.text(transcript.activeTranscriptText!);
        final paragraph = tester.renderObject<RenderParagraph>(
          find.descendant(of: caption, matching: find.byType(RichText)),
        );
        expect(paragraph.didExceedMaxLines, isFalse);
        final viewport = find.ancestor(
          of: caption,
          matching: find.byType(SingleChildScrollView),
        );
        expectControls(visible: true);
        expect(
          tester.getTopLeft(viewport).dy,
          greaterThan(
            tester.getBottomLeft(find.byIcon(Icons.play_arrow_rounded)).dy,
          ),
        );
        final titleRow = find
            .ancestor(of: find.text('Lesson'), matching: find.byType(Row))
            .first;
        expect(
          tester.getTopLeft(titleRow).dy -
              tester
                  .getBottomLeft(
                    find.byKey(const ValueKey('fullscreen-active-transcript')),
                  )
                  .dy,
          closeTo(6, 0.01),
        );
        final scrollable = find.descendant(
          of: viewport,
          matching: find.byType(Scrollable),
        );
        final position = tester.state<ScrollableState>(scrollable).position;
        expect(position.maxScrollExtent, greaterThan(0));
        await tester.drag(viewport, Offset(0, -position.maxScrollExtent - 100));
        await tester.pumpAndSettle();
        expect(controller.value.isPlaying, isFalse);
        expect(position.pixels, closeTo(position.maxScrollExtent, 1));
        final scrollOffset = position.pixels;
        await controller.seekTo(const Duration(seconds: 21));
        await tester.pump();
        final updatedScrollable = find.descendant(
          of: find.byKey(const ValueKey('fullscreen-active-transcript')),
          matching: find.byType(Scrollable),
        );
        expect(
          tester.state<ScrollableState>(updatedScrollable).position.pixels,
          closeTo(scrollOffset, 1),
        );
        final captionContainer = find.byKey(
          const ValueKey('fullscreen-active-transcript'),
        );
        final captionBounds = tester.getRect(captionContainer);
        await controller.play();
        await tester.pump();
        expectControls(visible: false);
        final hiddenCaptionBounds = tester.getRect(captionContainer);
        expect(hiddenCaptionBounds.top, greaterThan(captionBounds.top));
        expect(hiddenCaptionBounds.size, captionBounds.size);
        expect(
          hiddenCaptionBounds.bottom,
          tester
              .getBottomLeft(
                find.byKey(const ValueKey('fullscreen-video-footer')),
              )
              .dy,
        );
        await tester.tap(captionContainer);
        await tester.pump();
        expect(controller.value.isPlaying, isFalse);
        expectControls(visible: true);
        expect(tester.getRect(captionContainer), captionBounds);
        await tester.pump(const Duration(seconds: 4));
        expectControls(visible: true);
        await tester.tap(captionContainer);
        await tester.pump();
        expect(controller.value.isPlaying, isTrue);
        await tester.pump(const Duration(seconds: 3));
        expectControls(visible: false);
        expect(tester.getRect(captionContainer), hiddenCaptionBounds);
        expect(
          tester.state<ScrollableState>(updatedScrollable).position.pixels,
          closeTo(scrollOffset, 1),
        );
        await tester.tap(captionContainer);
        await tester.pump();
        expect(tester.getRect(captionContainer), captionBounds);
        await tester.tap(find.text(AppStrings.trainingViewTranscript));
        await tester.pumpAndSettle();
        expect(find.byType(BottomSheet), findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(BottomSheet),
            matching: find.text(cue),
          ),
          findsOneWidget,
        );
        await tester.pumpWidget(const SizedBox.shrink());
        await controller.pause();
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('fullscreen transcript action handles empty content', (
    tester,
  ) async {
    await openPlayer(tester, playing: false);
    await tester.tap(find.text(AppStrings.trainingViewTranscript));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.trainingNoTranscriptAvailable), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
  });

  for (final useSystemBack in [false, true]) {
    testWidgets(
      'fullscreen allows phone rotation and restores portrait on ${useSystemBack ? 'system back' : 'exit icon'}',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(390, 844);
        tester.view.padding = FakeViewPadding(
          left: 30,
          right: 30,
          top: 24,
          bottom: 20,
        );
        addTearDown(tester.view.reset);
        await openPlayer(tester);

        expect(orientationRequests.single, fullscreenOrientations);
        expect(fullscreenRequests, [true]);
        final video = find.byType(VideoPlayer);
        expect(tester.getSize(video).width, 390);
        expect(find.byIcon(Icons.screen_rotation_outlined), findsNothing);
        final size = tester.getSize(video);
        expect(size.height, closeTo(390 * 9 / 16, 0.01));
        expect(tester.getTopLeft(video).dx, 0);
        expect(find.byType(AppBackButton), findsNothing);
        final exitButton = find.byKey(
          const ValueKey('video-exit-fullscreen-button'),
        );
        expect(tester.getTopLeft(exitButton).dx, greaterThanOrEqualTo(30));
        expect(
          tester.getBottomRight(exitButton).dx,
          lessThanOrEqualTo(390 - 30),
        );
        expect(
          tester.getBottomRight(exitButton).dy,
          lessThanOrEqualTo(844 - 20),
        );
        expect(tester.widget<VideoPlayer>(video).controller, same(controller));
        expect(controller.value.position, const Duration(seconds: 20));
        expect(controller.value.isPlaying, isTrue);

        tester.view.physicalSize = const Size(844, 390);
        await tester.pumpAndSettle();
        expect(orientationRequests, [fullscreenOrientations]);
        expect(find.byIcon(Icons.screen_rotation_outlined), findsNothing);
        final landscapeVideoSize = tester.getSize(video);
        expect(landscapeVideoSize.height, 390);
        expect(landscapeVideoSize.width, closeTo(390 * 16 / 9, 0.01));
        expect(tester.widget<VideoPlayer>(video).controller, same(controller));
        expect(controller.value.isPlaying, isTrue);
        expect(controller.value.position, const Duration(seconds: 20));

        if (useSystemBack) {
          await tester.binding.handlePopRoute();
        } else {
          await revealPlayingControls(tester);
          await tester.tap(exitButton);
        }
        await tester.pump();
        expect(orientationRequests.last, ['DeviceOrientation.portraitUp']);
        expect(fullscreenRequests, [true, false]);
        // Native orientation requests update the viewport on a real phone.
        tester.view.physicalSize = const Size(390, 844);
        await tester.pumpAndSettle();
        expect(find.byType(ComplianceFullScreenVideoView), findsNothing);
        expect(orientationRequests, [
          fullscreenOrientations,
          ['DeviceOrientation.portraitUp'],
        ]);
        expect(find.byIcon(Icons.screen_rotation_outlined), findsNothing);
        expect(fullscreenRequests, [true, false]);
        expect(controller.value.isPlaying, isTrue);
        expect(controller.value.position, const Duration(seconds: 20));
        await tester.pumpWidget(const SizedBox.shrink());
        await controller.pause();
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'phone rotation preserves playback without a rotate control',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.reset);
      await openPlayer(tester);
      final video = find.byType(VideoPlayer);

      expect(orientationRequests.single, fullscreenOrientations);
      expect(find.byIcon(Icons.screen_rotation_outlined), findsNothing);
      tester.view.physicalSize = const Size(844, 390);
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.screen_rotation_outlined), findsNothing);
      expect(tester.widget<VideoPlayer>(video).controller, same(controller));
      expect(controller.value.isPlaying, isTrue);
      expect(controller.value.position, const Duration(seconds: 20));

      tester.view.physicalSize = const Size(390, 844);
      await tester.pumpAndSettle();
      expect(orientationRequests, [fullscreenOrientations]);
      expect(find.byIcon(Icons.screen_rotation_outlined), findsNothing);
      expect(tester.widget<VideoPlayer>(video).controller, same(controller));
      expect(controller.value.isPlaying, isTrue);
      expect(controller.value.position, const Duration(seconds: 20));
      expect(
        fullscreenRequests,
        defaultTargetPlatform == TargetPlatform.android ? [true] : isEmpty,
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      expect(orientationRequests.last, ['DeviceOrientation.portraitUp']);
      if (defaultTargetPlatform == TargetPlatform.android) {
        expect(fullscreenRequests, [true, false]);
      } else {
        expect(systemUiRequests, [
          'SystemUiMode.immersiveSticky',
          'SystemUiMode.edgeToEdge',
        ]);
      }
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant({
      TargetPlatform.android,
      TargetPlatform.iOS,
    }),
  );

  testWidgets('portrait video fits the screen and remains seekable', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);
    platform.size = const Size(360, 640);
    await openPlayer(tester, playing: false);
    expect(orientationRequests.single, fullscreenOrientations);
    final size = tester.getSize(find.byType(VideoPlayer));
    expect(size.width, 390);
    expect(size.height, closeTo(390 * 16 / 9, 0.01));
    expect(controller.value.isPlaying, isFalse);

    await tester.drag(find.byType(Slider), const Offset(40, 0));
    await tester.pumpAndSettle();
    expect(controller.value.position, greaterThan(const Duration(seconds: 20)));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    expect(orientationRequests.last, ['DeviceOrientation.portraitUp']);
    expect(fullscreenRequests, isEmpty);
    expect(systemUiRequests, [
      'SystemUiMode.immersiveSticky',
      'SystemUiMode.edgeToEdge',
    ]);
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
}

class _VideoPlatform extends VideoPlayerPlatform {
  final _events = StreamController<VideoEvent>();
  Size size = const Size(640, 360);
  Duration position = Duration.zero;

  @override
  Future<void> init() async {}

  @override
  Future<int> createWithOptions(VideoCreationOptions options) async {
    _events.add(
      VideoEvent(
        eventType: VideoEventType.initialized,
        duration: const Duration(minutes: 1),
        size: size,
      ),
    );
    return 1;
  }

  @override
  Stream<VideoEvent> videoEventsFor(int playerId) => _events.stream;

  @override
  Future<void> setLooping(int playerId, bool looping) async {}

  @override
  Future<void> setVolume(int playerId, double volume) async {}

  @override
  Future<void> setPlaybackSpeed(int playerId, double speed) async {}

  @override
  Future<void> play(int playerId) async {}

  @override
  Future<void> pause(int playerId) async {}

  @override
  Future<void> seekTo(int playerId, Duration position) async {
    this.position = position;
  }

  @override
  Future<Duration> getPosition(int playerId) async => position;

  @override
  Widget buildViewWithOptions(VideoViewOptions options) => const SizedBox();

  @override
  Future<void> dispose(int playerId) async => _events.close();
}
