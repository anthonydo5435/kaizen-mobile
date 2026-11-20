import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sparrowkaizen/core/constants/app_strings.dart';
import 'package:sparrowkaizen/core/managers/app_manager.dart';
import 'package:sparrowkaizen/core/managers/models/company_billing_details.dart';
import 'package:sparrowkaizen/core/constants/app_colors.dart';
import 'package:sparrowkaizen/core/widgets/app_button.dart';
import 'package:sparrowkaizen/core/widgets/app_gradient_action_button.dart';
import 'package:sparrowkaizen/features/check_in/presentation/pages/check_in_single_description.dart';
import 'package:sparrowkaizen/features/check_in/presentation/providers/check_in_controller.dart';
import 'package:sparrowkaizen/features/check_in/domain/entities/audit_description_audit.dart';

import '../../support/single_description_fixtures.dart';

void main() {
  setUp(() {
    AppManager.instance.saveBillingDetails(
      CompanyBillingDetails.fromApiJson({'status': 'paid'}),
    );
  });
  tearDown(() => AppManager.instance.saveBillingDetails(null));

  late SingleDescriptionRepository repository;
  late CheckInController checkIn;

  setUp(() {
    repository = SingleDescriptionRepository();
    checkIn = singleDescriptionCheckInController(repository);
  });
  tearDown(() => checkIn.dispose());

  Future<void> answerConfirmation(
    WidgetTester tester, {
    bool general = false,
    bool accept = true,
  }) async {
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(
      find.text(
        general
            ? AppStrings.auditGeneralAssignmentConfirmTitle
            : AppStrings.auditMemberAssignmentConfirmTitle,
      ),
      findsOneWidget,
    );
    expect(
      find.text(
        general
            ? AppStrings.auditGeneralAssignmentConfirmMessage
            : AppStrings.auditMemberAssignmentConfirmMessage,
      ),
      findsOneWidget,
    );
    final gradientButtons = tester.widgetList<AppGradientActionButton>(
      find.byType(AppGradientActionButton),
    );
    expect(gradientButtons.map((button) => button.label), [
      AppStrings.auditAssignmentConfirmYes,
    ]);
    expect(
      find.widgetWithText(AppButton, AppStrings.auditAssignmentConfirmNo),
      findsOneWidget,
    );
    await tester.tap(
      find.text(
        accept
            ? AppStrings.auditAssignmentConfirmYes
            : AppStrings.auditAssignmentConfirmNo,
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> mount(
    WidgetTester tester, {
    bool isGeneralSeatAudit = false,
    Size size = const Size(400, 844),
    double textScale = 1,
    bool settle = true,
    int daysAgo = 0,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final audit = singleDescriptionQuarterlyAudit();
    await tester.pumpWidget(
      ChangeNotifierProvider<CheckInController>.value(
        value: checkIn,
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: SingleDescriptionDetails(
            audit: audit,
            descriptions: audit.descriptions,
            initialDescriptionIndex: 0,
            initialRatingCounts: const {'great': 7},
            date: singleDescriptionDate(daysAgo: daysAgo),
            isOwner: true,
            isGeneralSeatAudit: isGeneralSeatAudit,
          ),
        ),
      ),
    );
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
    }
  }

  testWidgets(
    'an older General Seat check-in supports confirmed assignment while ratings stay read-only',
    (tester) async {
      await mount(tester, isGeneralSeatAudit: true, daysAgo: 30);
      final ratingTap = find
          .ancestor(of: find.text('7'), matching: find.byType(InkWell))
          .first;
      expect(tester.widget<InkWell>(ratingTap).onTap, isNull);
      expect(repository.saves, isEmpty);
      await tester.ensureVisible(find.text(AppStrings.auditAssignToTeamMember));
      await tester.tap(find.text(AppStrings.auditAssignToTeamMember));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Member one'));
      await tester.pump();
      await tester.tap(find.text(AppStrings.auditAssignTeamMembers));
      await answerConfirmation(tester);
      expect(repository.assignments.single.profileJobIds, ['profile-job-one']);
      expect(repository.saves, isEmpty);
      await tester.tap(find.text(AppStrings.auditAddToGeneralCheckIn));
      await answerConfirmation(tester, general: true);
      expect(repository.assignments.last.profileJobIds, isEmpty);
      expect(repository.saves, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'assignment card opens during audit loading and restores selected people when ready',
    (tester) async {
      final pending = Completer<AuditDescriptionAudit>();
      repository.pendingLoads.add(pending.future);
      await mount(tester, isGeneralSeatAudit: true, settle: false);
      await tester.ensureVisible(find.text(AppStrings.auditAssignToTeamMember));
      await tester.tap(find.text(AppStrings.auditAssignToTeamMember));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(Dialog), findsOneWidget);
      expect(repository.memberRequests, ['seat']);
      expect(
        tester
            .widget<AppButton>(
              find.widgetWithText(AppButton, AppStrings.auditAssignTeamMembers),
            )
            .onPressed,
        isNull,
      );
      pending.complete(
        singleDescriptionAudit(assignments: ['profile-job-two']),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widgetList<Checkbox>(find.byType(Checkbox))
            .map((tile) => tile.value),
        [false, true],
      );
      await tester.tap(find.text('Member one'));
      await tester.pump();
      await tester.tap(find.text(AppStrings.auditAssignTeamMembers));
      await answerConfirmation(tester);
      expect(repository.assignments.single.profileJobIds, [
        'profile-job-two',
        'profile-job-one',
      ]);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'assignment card opens after an audit load failure and retries before saving',
    (tester) async {
      final pending = Completer<AuditDescriptionAudit>();
      repository.pendingLoads.add(pending.future);
      await mount(tester, isGeneralSeatAudit: true, settle: false);
      pending.completeError(StateError('Audit unavailable'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text(AppStrings.auditAssignToTeamMember));
      await tester.tap(find.text(AppStrings.auditAssignToTeamMember));
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(Dialog),
          matching: find.text(AppStrings.auditUnableToLoadDescriptionDetails),
        ),
        findsOneWidget,
      );
      await tester.tap(find.text(AppStrings.auditAssignmentRetry));
      await tester.pumpAndSettle();
      expect(find.byType(Checkbox), findsNWidgets(2));
      await tester.tap(find.text('Member one'));
      await tester.pump();
      await tester.tap(find.text(AppStrings.auditAssignTeamMembers));
      await answerConfirmation(tester);
      expect(repository.assignments.single.id, 'resolved-audit');
      expect(repository.assignments.single.profileJobIds, ['profile-job-one']);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'General Seat defaults to general and saves multiple selected people',
    (tester) async {
      repository.response = singleDescriptionAudit(isMirror: true);
      await mount(tester, isGeneralSeatAudit: true);
      expect(find.text(AppStrings.auditGeneralSeatRatingLabel), findsNothing);
      expect(find.text(AppStrings.auditAssignToTeamMemberHint), findsOneWidget);
      await tester.ensureVisible(
        find.text(AppStrings.auditAddToGeneralCheckIn),
      );
      final generalMaterial = tester.widget<Material>(
        find
            .ancestor(
              of: find.text(AppStrings.auditAddToGeneralCheckIn),
              matching: find.byType(Material),
            )
            .first,
      );
      expect(
        (generalMaterial.shape! as RoundedRectangleBorder).side.color,
        AppColors.progressColor,
      );
      await tester.tap(find.text(AppStrings.auditAssignToTeamMember));
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsOneWidget);
      expect(
        tester.getSize(find.byType(Dialog)).height,
        greaterThan(844 * 0.6),
      );
      expect(repository.memberRequests, ['seat']);
      await tester.tap(find.text('Member one'));
      await tester.tap(find.text('Member two'));
      await tester.enterText(find.byType(TextField), 'two@example');
      await tester.pump();
      expect(find.text('Member one'), findsNothing);
      expect(find.text('Member two'), findsOneWidget);
      await tester.tap(find.text(AppStrings.auditAssignTeamMembers));
      await answerConfirmation(tester);
      expect(find.byType(Dialog), findsNothing);
      expect(repository.assignments.single.id, 'resolved-audit');
      expect(repository.assignments.single.profileJobIds, [
        'profile-job-one',
        'profile-job-two',
      ]);
      expect(find.text('Assigned To: 2 Team Members'), findsOneWidget);
      await tester.tap(find.text(AppStrings.auditAddToGeneralCheckIn));
      await answerConfirmation(tester, general: true);
      expect(repository.assignments.last.profileJobIds, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'API assignments show the count and matching people selected in member cards',
    (tester) async {
      repository.response = singleDescriptionAudit(
        assignments: ['profile-job-two'],
      );
      await mount(tester, isGeneralSeatAudit: true);
      expect(find.text('Assigned To: 1 Team Member'), findsOneWidget);
      expect(repository.memberRequests, isEmpty);
      await tester.ensureVisible(find.text(AppStrings.auditAssignToTeamMember));
      await tester.tap(find.text(AppStrings.auditAssignToTeamMember));
      await tester.pumpAndSettle();
      final tiles = tester.widgetList<Checkbox>(find.byType(Checkbox)).toList();
      expect(tiles.first.value, isFalse);
      expect(tiles.last.value, isTrue);
      expect(find.byIcon(Icons.person_rounded), findsNWidgets(2));
      expect(repository.assignments, isEmpty);
      await tester.tap(find.byTooltip(AppStrings.auditAssignmentClose));
      await tester.pumpAndSettle();
      expect(find.text('Assigned To: 1 Team Member'), findsOneWidget);
      await tester.tap(find.text(AppStrings.auditAssignToTeamMember));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(Checkbox).first);
      await tester.pump();
      await tester.tap(find.text(AppStrings.auditAssignTeamMembers));
      await answerConfirmation(tester);
      expect(repository.assignments.single.profileJobIds, [
        'profile-job-two',
        'profile-job-one',
      ]);
      expect(find.text('Assigned To: 2 Team Members'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'people dialog discards drafts and keeps failed saves open for retry',
    (tester) async {
      await mount(tester, isGeneralSeatAudit: true);
      await tester.ensureVisible(find.text(AppStrings.auditAssignToTeamMember));
      await tester.tap(find.text(AppStrings.auditAssignToTeamMember));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Member one'));
      await tester.tap(find.byTooltip(AppStrings.auditAssignmentClose));
      await tester.pumpAndSettle();
      expect(repository.assignments, isEmpty);
      await tester.tap(find.text(AppStrings.auditAssignToTeamMember));
      await tester.pumpAndSettle();
      expect(
        tester.widget<Checkbox>(find.byType(Checkbox).first).value,
        isFalse,
      );
      await tester.tap(find.text('Member one'));
      await tester.pump();
      repository.failAssignment = true;
      await tester.tap(find.text(AppStrings.auditAssignTeamMembers));
      await answerConfirmation(tester);
      expect(find.byType(Dialog), findsOneWidget);
      expect(find.text(AppStrings.auditAssignmentSaveFailed), findsOneWidget);
      expect(
        tester.widget<Checkbox>(find.byType(Checkbox).first).value,
        isTrue,
      );
      repository.failAssignment = false;
      await tester.tap(find.text(AppStrings.auditAssignTeamMembers));
      await answerConfirmation(tester);
      expect(find.byType(Dialog), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('General confirmation No keeps assignments and Yes clears them', (
    tester,
  ) async {
    repository.response = singleDescriptionAudit(
      assignments: ['profile-job-one'],
    );
    await mount(tester, isGeneralSeatAudit: true);
    await tester.ensureVisible(find.text(AppStrings.auditAddToGeneralCheckIn));
    await tester.tap(find.text(AppStrings.auditAddToGeneralCheckIn));
    expect(repository.assignments, isEmpty);
    await answerConfirmation(tester, general: true, accept: false);
    expect(repository.assignments, isEmpty);
    expect(find.text('Assigned To: 1 Team Member'), findsOneWidget);
    await tester.tap(find.text(AppStrings.auditAddToGeneralCheckIn));
    await answerConfirmation(tester, general: true);
    expect(repository.assignments.single.profileJobIds, isEmpty);
    expect(find.text(AppStrings.auditAssignToTeamMemberHint), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'member confirmation No keeps multiple draft selections and does not save',
    (tester) async {
      await mount(tester, isGeneralSeatAudit: true);
      await tester.ensureVisible(find.text(AppStrings.auditAssignToTeamMember));
      await tester.tap(find.text(AppStrings.auditAssignToTeamMember));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Member one'));
      await tester.tap(find.text('Member two'));
      await tester.pump();
      await tester.tap(find.text(AppStrings.auditAssignTeamMembers));
      expect(repository.assignments, isEmpty);
      await answerConfirmation(tester, accept: false);
      expect(repository.assignments, isEmpty);
      expect(find.byType(Checkbox), findsNWidgets(2));
      expect(
        tester
            .widgetList<Checkbox>(find.byType(Checkbox))
            .every((tile) => tile.value == true),
        isTrue,
      );
      await tester.tap(find.text(AppStrings.auditAssignTeamMembers));
      await answerConfirmation(tester);
      expect(repository.assignments.single.profileJobIds, [
        'profile-job-one',
        'profile-job-two',
      ]);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('assignment confirmation fits a small screen with enlarged text', (
    tester,
  ) async {
    repository.response = singleDescriptionAudit(
      assignments: ['profile-job-one'],
    );
    await mount(tester, isGeneralSeatAudit: true, size: const Size(320, 568));
    await tester.ensureVisible(find.text(AppStrings.auditAddToGeneralCheckIn));
    await tester.tap(find.text(AppStrings.auditAddToGeneralCheckIn));
    await tester.pumpAndSettle();
    final confirmation = tester.widget<AlertDialog>(find.byType(AlertDialog));
    // Check the confirmation at large text sizes independently of the page cards.
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 568),
            textScaler: TextScaler.linear(2),
          ),
          child: confirmation,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text(AppStrings.auditGeneralAssignmentConfirmTitle),
      findsOneWidget,
    );
    expect(find.byType(AppGradientActionButton), findsOneWidget);
    expect(
      find.widgetWithText(AppButton, AppStrings.auditAssignmentConfirmNo),
      findsOneWidget,
    );
    expect(repository.assignments, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('mirror rating header is locked only on the member entry', (
    tester,
  ) async {
    repository.response = singleDescriptionAudit(isMirror: true);
    await mount(tester);
    expect(find.text(AppStrings.auditAssignTo), findsNothing);
    await tester.ensureVisible(find.text(AppStrings.auditSelectRatings));
    expect(find.text(AppStrings.auditGeneralSeatRatingLabel), findsOneWidget);
    expect(find.byIcon(Icons.lock_outline_rounded), findsOneWidget);
    await tester.tap(find.text('7'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(repository.saves, isEmpty);
  });

  testWidgets(
    'assignment dialog fits a small screen with scaled text and keyboard',
    (tester) async {
      await mount(
        tester,
        isGeneralSeatAudit: true,
        size: const Size(320, 568),
        textScale: 1.5,
      );
      await tester.ensureVisible(find.text(AppStrings.auditAssignToTeamMember));
      await tester.tap(find.text(AppStrings.auditAssignToTeamMember));
      await tester.pumpAndSettle();
      tester.view.viewInsets = const FakeViewPadding(bottom: 220);
      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();
      expect(find.byType(AppButton), findsWidgets);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'paging preserves each description draft, scroll and arrow boundaries',
    (tester) async {
      await mount(tester);
      final previous = find.widgetWithIcon(
        IconButton,
        Icons.arrow_back_rounded,
      );
      final next = find.widgetWithIcon(IconButton, Icons.arrow_forward_rounded);
      expect(tester.widget<IconButton>(previous).onPressed, isNull);
      expect(
        find.text(AppStrings.auditDescriptionPagePosition(1, 2)),
        findsOneWidget,
      );
      await tester.ensureVisible(find.text('7'));
      await tester.tap(find.text('7'));
      await tester.pump();
      expect(find.text('8'), findsOneWidget);
      await tester.tap(next);
      await tester.pumpAndSettle();
      expect(
        find.text(AppStrings.auditDescriptionPagePosition(2, 2)),
        findsOneWidget,
      );
      expect(tester.widget<IconButton>(next).onPressed, isNull);
      expect(checkIn.state.selectedQuarterlyAuditDescriptionUuid, 'second');
      expect(repository.saves.single.counts['great'], 8);
      await tester.tap(previous);
      await tester.pumpAndSettle();
      expect(find.text('8').hitTestable(), findsOneWidget);
      expect(repository.loads.where((id) => id == 'first'), hasLength(1));
      await tester.drag(find.byType(PageView), const Offset(-360, 0));
      await tester.pumpAndSettle();
      expect(
        find.text(AppStrings.auditDescriptionPagePosition(2, 2)),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'closing the actual detail page saves a tap still inside its debounce',
    (tester) async {
      await mount(tester);
      await tester.ensureVisible(find.text('7'));
      await tester.tap(find.text('7'));
      expect(repository.saves, isEmpty);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 200));
      expect(repository.saves, hasLength(1));
      expect(repository.saves.single.id, 'resolved-audit');
      expect(repository.saves.single.counts['great'], 8);
      expect(tester.takeException(), isNull);
    },
  );
}
