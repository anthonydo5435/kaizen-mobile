import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sparrowkaizen/core/constants/app_colors.dart';
import 'package:sparrowkaizen/core/constants/app_strings.dart';
import 'package:sparrowkaizen/core/managers/app_manager.dart';
import 'package:sparrowkaizen/core/preference/app_preference.dart';
import 'package:sparrowkaizen/core/widgets/app_swipe_reveal_action.dart';
import 'package:sparrowkaizen/features/login/domain/entities/user.dart';
import 'package:sparrowkaizen/features/paygrades/domain/entities/paygrade_detail.dart';
import 'package:sparrowkaizen/features/paygrades/domain/usecases/get_paygrades_usecase.dart';
import 'package:sparrowkaizen/features/paygrades/presentation/pages/paygrade_detail_screen.dart';

void main() {
  late _UseCase useCase;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppPreference.init();
    AppManager.instance.resetSessionState();
    AppManager.instance.updateCurrentUser(
      User(uuid: 'owner', isOwner: true, organizationUuid: 'org'),
    );
    useCase = _UseCase();
  });
  tearDown(AppManager.instance.resetSessionState);

  Future<void> openScreen(WidgetTester tester, {bool ancillary = false}) async {
    await tester.binding.setSurfaceSize(const Size(320, 840));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1.3)),
          child: child!,
        ),
        home: PaygradeDetailScreen(paygradeId: 'job', getPaygradesUseCase: useCase),
      ),
    );
    await tester.pumpAndSettle();
    if (ancillary) {
      await tester.tap(find.text(AppStrings.paygradesAncillaryTab));
      await tester.pumpAndSettle();
    }
  }

  for (final ancillary in [false, true]) {
    final tab = ancillary ? 'ancillary' : 'primary';

    testWidgets('$tab right swipe expands only its card and can collapse it', (tester) async {
      await openScreen(tester, ancillary: ancillary);
      final title = ancillary ? 'AD1: Ancillary Designer' : 'PD1: Primary Designer';
      expect(find.byIcon(Icons.keyboard_arrow_down_rounded), findsNothing);
      expect(find.text('$tab specifics'), findsNothing);
      await tester.tap(find.text(title));
      await tester.pumpAndSettle();
      expect(find.text('$tab specifics'), findsNothing);

      await _swipeCard(tester, const Offset(180, 0));
      final showMore = find.text(AppStrings.paygradesShowMoreAction);
      expect(showMore.hitTestable(), findsOneWidget);
      _expectSecondaryColorAction(tester, showMore);
      expect(find.text('$tab specifics'), findsNothing);
      await tester.tap(showMore);
      await tester.pumpAndSettle();
      expect(find.text('$tab specifics'), findsOneWidget);
      expect(find.text('$tab promotion'), findsOneWidget);
      expect(find.text('second specifics'), findsNothing);
      expect(find.text(AppStrings.paygradesShowMoreAction), findsNothing);
      expect(find.text(AppStrings.paygradesEditAction), findsNothing);

      await _swipeCard(tester, const Offset(180, 0));
      await tester.tap(find.text(AppStrings.paygradesShowLessAction));
      await tester.pumpAndSettle();
      expect(find.text('$tab specifics'), findsNothing);
      expect(find.text(AppStrings.paygradesShowLessAction), findsNothing);
      expect(useCase.updates, isEmpty);
      expect(useCase.deletions, isEmpty);
    });

    testWidgets('$tab left swipe edits the selected entry without expanding it', (tester) async {
      await openScreen(tester, ancillary: ancillary);
      await _swipeCard(tester, const Offset(-200, 0));
      final edit = find.text(AppStrings.paygradesEditAction);
      expect(edit.hitTestable(), findsOneWidget);
      _expectSecondaryColorAction(tester, edit);
      expect(find.byTooltip(AppStrings.paygradesDeleteAction).hitTestable(), findsOneWidget);
      expect(useCase.updates, isEmpty);
      expect(useCase.deletions, isEmpty);
      await tester.tap(edit);
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.paygradesEditSheetTitle), findsOneWidget);
      final fields = find.byType(TextField);
      expect(tester.widget<TextField>(fields.at(1)).controller!.text, '10.00');
      expect(tester.widget<TextField>(fields.at(2)).controller!.text, '$tab specifics');
      await tester.enterText(fields.first, 'Updated Designer');
      final save = find.text(AppStrings.seatProfileSaveAction);
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(useCase.updates, ['$tab-entry:Updated Designer']);
      expect(find.text('UD1: Updated Designer'), findsOneWidget);
      expect(find.text(AppStrings.paygradesEditAction), findsNothing);
      expect(find.text('$tab specifics'), findsNothing);
    });
  }

  testWidgets('left swipe only reveals Delete and deletion requires confirmation', (tester) async {
    await openScreen(tester);
    await _swipeCard(tester, const Offset(-200, 0));
    expect(useCase.deletions, isEmpty);
    await tester.tap(find.byTooltip(AppStrings.paygradesDeleteAction));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.paygradesDeleteTitle), findsOneWidget);
    expect(useCase.deletions, isEmpty);
    await tester.tap(find.text(AppStrings.trainingCancel));
    await tester.pumpAndSettle();
    expect(find.text('PD1: Primary Designer'), findsOneWidget);
    expect(useCase.deletions, isEmpty);

    await _swipeCard(tester, const Offset(-200, 0));
    await tester.tap(find.byTooltip(AppStrings.paygradesDeleteAction));
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppStrings.paygradesDeleteAction));
    await tester.pumpAndSettle();
    expect(useCase.deletions, ['primary-entry']);
    expect(find.text('PD1: Primary Designer'), findsNothing);
    expect(find.text('SD1: Second Designer'), findsOneWidget);
  });

  for (final childOrganization in [false, true]) {
    testWidgets('read-only cards expand without edit/delete (child: $childOrganization)', (
      tester,
    ) async {
      if (childOrganization) {
        final client = MockClient(
          (_) async => http.Response(
            jsonEncode([
              {'uuid': 'org', 'name': 'Child', 'type': 'child'},
            ]),
            200,
          ),
        );
        addTearDown(client.close);
        await http.runWithClient(
          () => AppManager.instance.fetchOrganizations(forceRefresh: true, requireSuccess: true),
          () => client,
        );
      } else {
        AppManager.instance.updateCurrentUser(
          User(uuid: 'member', roles: ['team_member'], organizationUuid: 'org'),
        );
      }
      await openScreen(tester);
      await _swipeCard(tester, const Offset(-200, 0));
      expect(find.text(AppStrings.paygradesEditAction), findsNothing);
      expect(find.byTooltip(AppStrings.paygradesDeleteAction), findsNothing);
      await _swipeCard(tester, const Offset(180, 0));
      await tester.tap(find.text(AppStrings.paygradesShowMoreAction));
      await tester.pumpAndSettle();
      expect(find.text('primary specifics'), findsOneWidget);
      expect(useCase.updates, isEmpty);
      expect(useCase.deletions, isEmpty);
    });
  }
}

Future<void> _swipeCard(WidgetTester tester, Offset offset) async {
  await tester.drag(find.byType(AppSwipeRevealAction).first, offset);
  await tester.pumpAndSettle();
}

void _expectSecondaryColorAction(WidgetTester tester, Finder label) {
  final material = find.ancestor(of: label, matching: find.byType(Material)).first;
  expect(tester.widget<Material>(material).color, AppColors.secondaryColor);
}

class _UseCase extends Fake implements GetPaygradesUseCase {
  final updates = <String>[];
  final deletions = <String>[];

  @override
  Future<PaygradeDetail> getPaygradeDetail({
    required String paygradeId,
    required String type,
  }) async {
    return PaygradeDetail(
      id: 'job',
      title: 'Designer',
      department: 'Operations',
      paygradeUnit: 'hr',
      payGrades: [
        PaygradeEntry(
          id: '$type-entry',
          type: type,
          title: type == 'primary' ? 'Primary Designer' : 'Ancillary Designer',
          payRate: '10.00',
          level: 1,
          description: '$type specifics',
          promotionRequirement: '$type promotion',
        ),
        if (type == 'primary')
          const PaygradeEntry(
            id: 'second-entry',
            type: 'primary',
            title: 'Second Designer',
            payRate: '20.00',
            level: 2,
            description: 'second specifics',
            promotionRequirement: 'second promotion',
          ),
      ],
    );
  }

  @override
  Future<String?> getPaygradesPublicLink(String jobId) async => null;

  @override
  Future<void> updatePaygrade({
    required String paygradeId,
    required String title,
    required String description,
    required String promotionRequirement,
    String? payRate,
  }) async {
    updates.add('$paygradeId:$title');
  }

  @override
  Future<void> deletePaygrade(String paygradeId) async {
    deletions.add(paygradeId);
  }
}
