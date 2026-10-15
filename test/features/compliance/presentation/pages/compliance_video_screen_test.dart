import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sparrowkaizen/core/constants/app_colors.dart';
import 'package:sparrowkaizen/core/constants/app_strings.dart';
import 'package:sparrowkaizen/core/widgets/fast_circular_progress.dart';
import 'package:sparrowkaizen/features/compliance/domain/entities/compliance_track_item_detail.dart';
import 'package:sparrowkaizen/features/compliance/presentation/pages/training/compliance_video_screen.dart';
import 'package:sparrowkaizen/features/compliance/presentation/providers/compliance_video_controller.dart';
import 'package:sparrowkaizen/features/compliance/presentation/widgets/compliance_video_player.dart';

void main() {
  testWidgets('moves the purple highlight with playback and backward seeks', (
    tester,
  ) async {
    await tester.pumpWidget(
      _screen('[00:00] Introduction\n[00:05] Main point'),
    );
    await _openTranscript(tester);
    final controller = tester
        .element(find.text('Introduction'))
        .read<ComplianceVideoController>();

    controller.updatePlaybackPosition(const Duration(seconds: 1));
    await tester.pump();
    expect(
      tester.widget<Text>(_sheetText('Introduction')).style?.color,
      AppColors.secondaryColor,
    );
    expect(
      tester.widget<Text>(_sheetText('Main point')).style?.color,
      AppColors.textPrimary,
    );

    controller.updatePlaybackPosition(const Duration(seconds: 5));
    await tester.pump();
    expect(
      tester.widget<Text>(_sheetText('Introduction')).style?.color,
      AppColors.textPrimary,
    );
    expect(
      tester.widget<Text>(_sheetText('Main point')).style?.color,
      AppColors.secondaryColor,
    );
    expect(
      tester.widget<Text>(find.text('00:05')).style?.color,
      AppColors.secondaryColor,
    );

    controller.updatePlaybackPosition(Duration.zero);
    await tester.pump();
    expect(
      tester.widget<Text>(_sheetText('Introduction')).style?.color,
      AppColors.secondaryColor,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('spaces transcript rows and wraps long text on a narrow screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const firstLine =
        'A long transcript line that wraps naturally on a narrow mobile screen.';
    await tester.pumpWidget(_screen('$firstLine\nSecond line'));
    await _openTranscript(tester);

    final first = find.text(firstLine);
    final second = find.text('Second line');
    expect(tester.widget<Text>(first).style?.height, 1.6);
    expect(
      tester.getTopLeft(second).dy - tester.getBottomLeft(first).dy,
      greaterThanOrEqualTo(14),
    );
    expect(find.text('00:00'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('resets the active line when the training content changes', (
    tester,
  ) async {
    await tester.pumpWidget(_screen('[00:00] Old transcript'));
    await _openTranscript(tester);
    tester
        .element(find.text('Old transcript'))
        .read<ComplianceVideoController>()
        .updatePlaybackPosition(const Duration(seconds: 2));
    await tester.pump();

    await _closeTranscript(tester);
    await tester.pumpWidget(_screen('[00:00] New transcript'));
    await _openTranscript(tester);
    expect(find.text('Old transcript'), findsNothing);
    expect(
      tester.widget<Text>(_sheetText('New transcript')).style?.color,
      AppColors.secondaryColor,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'matches the editor video layout without editing actions and handles no transcript',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(_screen(null, videoUrl: 'http://['));
      await tester.pump();
      final playerFinder = find.byType(ComplianceVideoPlayer);
      final player = tester.widget<ComplianceVideoPlayer>(playerFinder);
      expect(
        tester
            .getSize(find.byKey(const ValueKey('training-video-frame')))
            .height,
        383,
      );
      expect(player.height, 383);
      expect(player.mediaAlignment, const Alignment(0, -0.5));
      expect(player.topControlsInset, 6);
      expect(player.fillBounds, isTrue);
      expect(player.topRightActions, isEmpty);
      expect(
        find.byTooltip(AppStrings.trainingReUploadVideoAction),
        findsNothing,
      );
      expect(find.byTooltip(AppStrings.trainingThumbnailAction), findsNothing);
      expect(
        find.byKey(const ValueKey('video-fullscreen-button')),
        findsOneWidget,
      );
      expect(find.byType(Slider), findsOneWidget);
      expect(find.text(AppStrings.trainingCc), findsOneWidget);
      await _openTranscript(tester);
      expect(
        find.text(AppStrings.trainingNoTranscriptAvailable),
        findsOneWidget,
      );
      expect(_sheetText('00:00'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'CC hides the two-line caption overlay without changing video or footer bounds',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final cue = List.filled(
        40,
        'A full transcript line that must wrap',
      ).join('\n');
      await tester.pumpWidget(_screen('[00:00 --> 00:04] $cue', textScale: 2));
      final cc = find.text(AppStrings.trainingCc);
      final action = find.text(AppStrings.trainingViewTranscript);
      final ccButton = find.ancestor(of: cc, matching: find.byType(TextButton));
      final actionButton = find.ancestor(
        of: action,
        matching: find.byType(TextButton),
      );
      final controller = tester.element(cc).read<ComplianceVideoController>();
      final video = find.byType(FastCircularProgressIndicator);
      final videoBounds = tester.getRect(video);
      expect(videoBounds.height, 281);
      expect(controller.isCcEnabled, isFalse);
      expect(tester.getTopLeft(ccButton).dx, videoBounds.left + 10);
      expect(
        tester.getBottomRight(actionButton).dx,
        videoBounds.right - ComplianceVideoPlayer.contentHorizontalInset,
      );
      controller.updatePlaybackPosition(const Duration(milliseconds: 3999));
      await tester.pump();
      final paragraph = tester.renderObject<RenderParagraph>(
        find.descendant(of: find.text(cue), matching: find.byType(RichText)),
      );
      expect(paragraph.didExceedMaxLines, isTrue);
      expect(tester.getRect(video), videoBounds);
      final overlay = tester.getRect(
        find.byKey(const ValueKey('active-video-caption')),
      );
      expect(overlay.bottom, closeTo(videoBounds.bottom - 8, 0.01));
      expect(overlay.left, videoBounds.left + 8);
      expect(overlay.right, videoBounds.right - 8);
      expect(overlay.top, greaterThanOrEqualTo(videoBounds.top + 8));
      final caption = tester.widget<Text>(find.text(cue));
      expect(caption.maxLines, 2);
      expect(caption.overflow, TextOverflow.ellipsis);
      final actionBounds = tester.getRect(actionButton);

      await tester.tap(cc);
      await tester.pump();
      expect(controller.isCcEnabled, isTrue);
      expect(find.text(cue), findsNothing);
      expect(tester.getRect(actionButton), actionBounds);
      expect(tester.getTopLeft(actionButton).dy, videoBounds.bottom + 6);
      expect(tester.getRect(video), videoBounds);
      await _openTranscript(tester);
      expect(_sheetText(cue), findsOneWidget);
      await _closeTranscript(tester);
      await tester.tap(cc);
      await tester.pump();
      expect(find.text(cue), findsOneWidget);
      controller.updatePlaybackPosition(const Duration(seconds: 4));
      await tester.pump();
      expect(find.text(cue), findsNothing);
      expect(tester.getTopLeft(actionButton).dy, videoBounds.bottom + 6);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('centers the active row and keeps the start free of empty space', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final texts = List.generate(
      90,
      (index) =>
          'Line $index ${List.filled(index % 3 + 1, 'wrapping text').join(' ')}',
    );
    final transcript = List.generate(90, (index) {
      final minutes = (index ~/ 60).toString().padLeft(2, '0');
      final seconds = (index % 60).toString().padLeft(2, '0');
      return '[$minutes:$seconds] ${texts[index]}';
    }).join('\n');
    await tester.pumpWidget(_screen(transcript, textScale: 1.5));
    final controller = tester
        .element(find.text(AppStrings.trainingViewTranscript))
        .read<ComplianceVideoController>();
    for (final index in [70, 0, 89]) {
      controller.updatePlaybackPosition(Duration(seconds: index));
      await tester.pump();
      await _openTranscript(tester);
      final list = find.descendant(
        of: find.byType(BottomSheet),
        matching: find.byType(CustomScrollView),
      );
      final row = find
          .ancestor(
            of: _sheetText(texts[index]),
            matching: find.byType(InkWell),
          )
          .first;
      if (index == 0) {
        expect(
          tester.getTopLeft(row).dy,
          closeTo(tester.getTopLeft(list).dy + 4, 1),
        );
      } else {
        expect(tester.getCenter(row).dy, closeTo(tester.getCenter(list).dy, 1));
      }
      final scrollable = find.descendant(
        of: list,
        matching: find.byType(Scrollable),
      );
      await tester.scrollUntilVisible(
        _sheetText(texts.first),
        -400,
        scrollable: scrollable,
        maxScrolls: 100,
      );
      final position = tester.state<ScrollableState>(scrollable).position;
      position.jumpTo(position.minScrollExtent);
      await tester.pump();
      final firstRow = find
          .ancestor(of: _sheetText(texts.first), matching: find.byType(InkWell))
          .first;
      expect(
        tester.getTopLeft(firstRow).dy,
        closeTo(tester.getTopLeft(list).dy + 4, 1),
      );
      await _closeTranscript(tester);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'seeks before closing with stable progress placement and retry feedback',
    (tester) async {
      await tester.pumpWidget(_screen('Untimed note\n[00:05] Main point'));
      final controller = tester
          .element(find.text(AppStrings.trainingViewTranscript))
          .read<ComplianceVideoController>();
      final completion = Completer<bool>();
      final positions = <Duration>[];
      controller.setSeekHandler((position) async {
        positions.add(position);
        return completion.future;
      });
      await _openTranscript(tester);
      await tester.tap(_sheetText('Untimed note'));
      expect(positions, isEmpty);
      final originalBounds = tester.getRect(_sheetText('Main point'));
      await tester.tap(_sheetText('Main point'));
      await tester.pump();
      expect(positions, [const Duration(seconds: 5)]);
      expect(tester.getRect(_sheetText('Main point')), originalBounds);
      final loader = find.descendant(
        of: find.byType(BottomSheet),
        matching: find.byType(FastCircularProgressIndicator),
      );
      expect(loader, findsOneWidget);
      expect(
        tester.getTopLeft(loader).dx,
        closeTo(tester.getBottomRight(_sheetText('00:05')).dx + 6, 0.01),
      );
      completion.complete(false);
      await tester.pump();
      expect(
        find.text(AppStrings.trainingTranscriptSeekFailed),
        findsOneWidget,
      );
      expect(find.byType(BottomSheet), findsOneWidget);
      controller.setSeekHandler((position) async {
        controller.updatePlaybackPosition(position);
        return true;
      });
      await tester.tap(_sheetText('Main point'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(BottomSheet), findsNothing);
      expect(find.text('Main point'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  test('waits for player registration and cancels on disposal', () async {
    final controller = ComplianceVideoController('[00:05] Main point');
    final seek = controller.seekToTranscriptLine(0);
    controller.setSeekHandler(
      (position) async => position == const Duration(seconds: 5),
    );
    expect(await seek, isTrue);
    controller.setSeekHandler(null);
    final pending = controller.seekToTranscriptLine(0);
    controller.dispose();
    expect(await pending, isFalse);
  });

  test('only notifies when the active transcript row changes', () {
    final controller = ComplianceVideoController(
      '[00:00] First\n[00:05] Second',
    );
    addTearDown(controller.dispose);
    var notifications = 0;
    controller.addListener(() => notifications++);

    controller.updatePlaybackPosition(Duration.zero);
    controller.updatePlaybackPosition(const Duration(seconds: 1));
    controller.updatePlaybackPosition(const Duration(seconds: 4));
    expect(notifications, 1);
    controller.updatePlaybackPosition(const Duration(seconds: 5));
    expect(notifications, 2);
  });
}

Widget _screen(String? transcript, {double textScale = 1, String? videoUrl}) {
  return MaterialApp(
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: TextScaler.linear(textScale),
        // Caption pacing is covered by the shared player tests.
        disableAnimations: true,
      ),
      child: child!,
    ),
    home: Scaffold(
      body: ComplianceVideoScreen(
        detail: ComplianceTrackItemDetail(
          uuid: 'item',
          position: 1,
          trainingModuleUuid: 'module',
          title: 'Training',
          quizStatus: '',
          videoUrl: videoUrl,
          videoDuration: 10,
          videoTranscript: transcript,
          videoThumbnailLink: null,
          trainingDocument: null,
          quizCompletionPercentage: 0,
        ),
      ),
    ),
  );
}

Finder _sheetText(String text) =>
    find.descendant(of: find.byType(BottomSheet), matching: find.text(text));

Future<void> _openTranscript(WidgetTester tester) async {
  await tester.tap(find.text(AppStrings.trainingViewTranscript));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

Future<void> _closeTranscript(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.close_rounded));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}
