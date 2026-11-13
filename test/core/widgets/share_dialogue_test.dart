import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sparrowkaizen/core/constants/app_strings.dart';
import 'package:sparrowkaizen/core/widgets/app_gradient_action_button.dart';
import 'package:sparrowkaizen/core/widgets/app_overlay_close_button.dart';
import 'package:sparrowkaizen/core/widgets/fast_circular_progress.dart';
import 'package:sparrowkaizen/core/widgets/share_dialogue.dart';

void main() {
  testWidgets('missing link shows module copy and only the create action', (
    tester,
  ) async {
    var creates = 0;
    await tester.pumpWidget(
      _app(
        ShareDialogue(
          contentLabel: AppStrings.shareSeatProfileContent,
          link: '  ',
          onCreateLink: () => creates++,
        ),
      ),
    );

    expect(find.text(AppStrings.sharePublicLinkTitle), findsOneWidget);
    expect(
      find.text(
        AppStrings.shareCreateLinkDescription(
          AppStrings.shareSeatProfileContent,
        ),
      ),
      findsOneWidget,
    );
    expect(find.byTooltip(AppStrings.shareCopyLinkAction), findsNothing);
    expect(find.text(AppStrings.shareRevokeLinkAction), findsNothing);
    expect(find.byType(AppGradientActionButton), findsOneWidget);
    await tester.tap(find.text(AppStrings.shareCreateLinkAction));
    expect(creates, 1);
  });

  testWidgets('existing link exposes copy and revoke callbacks', (
    tester,
  ) async {
    var copies = 0;
    var revokes = 0;
    const link = 'https://dev.kaizenteams.ai/shared/existing-link';
    await tester.pumpWidget(
      _app(
        ShareDialogue(
          contentLabel: AppStrings.sharePaygradesContent,
          link: link,
          onCopyLink: () => copies++,
          onRevokeLink: () => revokes++,
        ),
      ),
    );

    expect(find.text(link), findsOneWidget);
    expect(
      find.text(
        AppStrings.sharePublicLinkDescription(AppStrings.sharePaygradesContent),
      ),
      findsOneWidget,
    );
    expect(find.text(AppStrings.shareCreateLinkAction), findsNothing);
    await tester.tap(find.byTooltip(AppStrings.shareCopyLinkAction));
    await tester.tap(find.text(AppStrings.shareRevokeLinkAction));
    expect(copies, 1);
    expect(revokes, 1);
  });

  testWidgets('working state prevents duplicate create and revoke actions', (
    tester,
  ) async {
    var actions = 0;
    var closes = 0;
    await tester.pumpWidget(
      _app(
        ShareDialogue(
          contentLabel: AppStrings.shareLessonsContent,
          onCreateLink: () => actions++,
          onClose: () => closes++,
        ),
      ),
    );
    final createButton = find.byType(AppGradientActionButton);
    final createButtonSize = tester.getSize(createButton);
    await tester.pumpWidget(
      _app(
        ShareDialogue(
          contentLabel: AppStrings.shareLessonsContent,
          isWorking: true,
          onCreateLink: () => actions++,
          onClose: () => closes++,
        ),
      ),
    );
    expect(find.byType(FastCircularProgressIndicator), findsOneWidget);
    expect(tester.getSize(createButton), createButtonSize);
    expect(find.byType(AppOverlayCloseButton), findsOneWidget);
    await tester.tap(createButton);
    await tester.tap(find.byType(AppOverlayCloseButton));
    expect(actions, 0);
    expect(closes, 0);

    await tester.pumpWidget(
      _app(
        ShareDialogue(
          contentLabel: AppStrings.shareLessonsContent,
          link: 'https://dev.kaizenteams.ai/shared/lesson',
          isWorking: true,
          onRevokeLink: () => actions++,
          onCopyLink: () => actions++,
          onClose: () => closes++,
        ),
      ),
    );
    expect(find.byType(FastCircularProgressIndicator), findsOneWidget);
    await tester.tap(find.text(AppStrings.shareRevokeLinkAction));
    await tester.tap(find.byTooltip(AppStrings.shareCopyLinkAction));
    expect(actions, 0);
    expect(find.byType(AppOverlayCloseButton), findsOneWidget);
    await tester.pumpWidget(
      _app(
        ShareDialogue(
          contentLabel: AppStrings.shareLessonsContent,
          onClose: () => closes++,
        ),
      ),
    );
    await tester.tap(find.byType(AppOverlayCloseButton));
    expect(closes, 1);
  });

  testWidgets('both states fit a small phone with larger text', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    for (final link in [
      null,
      'https://dev.kaizenteams.ai/shared/a-long-link',
    ]) {
      await tester.pumpWidget(
        _app(
          ShareDialogue(
            contentLabel: AppStrings.shareLessonsContent,
            link: link,
            onCreateLink: () {},
            onRevokeLink: () {},
            onCopyLink: () {},
          ),
          textScale: 2,
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
  });
}

Widget _app(Widget dialog, {double textScale = 1}) => MaterialApp(
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(
      context,
    ).copyWith(textScaler: TextScaler.linear(textScale)),
    child: child!,
  ),
  home: Scaffold(body: dialog),
);
