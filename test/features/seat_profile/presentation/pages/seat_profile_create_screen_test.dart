import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sparrowkaizen/core/constants/app_strings.dart';
import 'package:sparrowkaizen/core/managers/app_manager.dart';
import 'package:sparrowkaizen/core/preference/app_preference.dart';
import 'package:sparrowkaizen/core/widgets/app_ai_generate_button.dart';
import 'package:sparrowkaizen/features/login/domain/entities/user.dart';
import 'package:sparrowkaizen/features/seat_profile/presentation/models/seat_profile_form_initial_data.dart';
import 'package:sparrowkaizen/features/seat_profile/presentation/pages/seat_profile_create_screen.dart';
import 'package:sparrowkaizen/features/seat_profile/presentation/pages/seat_profile_manage_categories_sheet.dart';
import 'package:sparrowkaizen/features/seat_profile/presentation/providers/seat_profile_create_controller.dart';
import 'package:sparrowkaizen/routes/app_router.dart';

import '../../support/seat_profile_create_fixtures.dart';

void main() {
  late SeatProfileCreateUseCase useCase;
  bool? flowResult;
  String? openedSeatId;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppPreference.init();
    AppManager.instance.resetSessionState();
    AppManager.instance.updateCurrentUser(User(uuid: 'owner', isOwner: true));
    useCase = SeatProfileCreateUseCase();
    flowResult = null;
    openedSeatId = null;
  });
  tearDown(() => AppManager.instance.resetSessionState());

  Future<void> mount(
    WidgetTester tester, {
    SeatProfileFormInitialData? initialData,
  }) async {
    tester.view.physicalSize = const Size(400, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        onGenerateRoute: (settings) {
          if (settings.name != AppRouter.seatProfileDetail) return null;
          openedSeatId =
              (settings.arguments as SeatProfileDetailRouteArgs).seatId;
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => const Scaffold(body: Text('Details')),
          );
        },
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                flowResult = await Navigator.of(context).push<bool>(
                  MaterialPageRoute<bool>(
                    builder: (_) => SeatProfileCreateScreen(
                      initialData: initialData,
                      getSeatProfilesUseCase: useCase,
                    ),
                  ),
                );
              },
              child: const Text('Open form'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open form'));
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder.last);
    await tester.tap(finder.last);
    await tester.pumpAndSettle();
  }

  Future<void> createProfile(WidgetTester tester) async {
    await tester.enterText(find.byType(TextField).first, '  Operator  ');
    await tap(tester, find.byType(DropdownButton<String>));
    await tap(tester, find.text('Operations'));
    await tap(tester, find.byType(DropdownButton<SeatProfilePaygradeUnit>));
    await tap(tester, find.text(AppStrings.seatProfilePaygradeHourly));
    await tap(tester, find.text(AppStrings.seatProfileSaveAction));
    expect(useCase.creations.single.title, 'Operator');
  }

  testWidgets(
    'create retains its summary, locks selections and returns completion on back',
    (tester) async {
      await mount(tester);
      await createProfile(tester);
      expect(
        find.text(AppStrings.seatProfileCreatedSectionTitle),
        findsOneWidget,
      );
      expect(
        tester.widget<TextField>(find.byType(TextField).first).enabled,
        isFalse,
      );
      expect(
        tester
            .widget<DropdownButton<String>>(find.byType(DropdownButton<String>))
            .onChanged,
        isNull,
      );
      expect(useCase.creations, hasLength(1));
      await tap(tester, find.byIcon(Icons.arrow_back_ios_new_rounded));
      expect(flowResult, isTrue);
      expect(find.text('Open form'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'edit submits the existing department, unit and actual ID and returns true',
    (tester) async {
      await mount(tester, initialData: editFormData);
      expect(
        tester
            .widget<DropdownButton<String>>(find.byType(DropdownButton<String>))
            .onChanged,
        isNull,
      );
      expect(
        tester
            .widget<DropdownButton<SeatProfilePaygradeUnit>>(
              find.byType(DropdownButton<SeatProfilePaygradeUnit>),
            )
            .onChanged,
        isNull,
      );
      await tester.enterText(find.byType(TextField).first, ' Senior Operator ');
      await tap(tester, find.text(AppStrings.seatProfileUpdateAction));
      expect(useCase.updates.single.id, 'actual-seat');
      expect(useCase.updates.single.title, 'Senior Operator');
      expect(useCase.updates.single.department, createDepartment);
      expect(useCase.updates.single.unit, 'hr');
      expect(useCase.creations, isEmpty);
      expect(flowResult, isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'category validation and incomplete-total confirmation precede saving and details navigation',
    (tester) async {
      await mount(tester);
      await createProfile(tester);
      await tap(
        tester,
        find.text(AppStrings.seatProfileAddOrUpdateSeatCategoryAction),
      );
      final fields = find.descendant(
        of: find.byType(Dialog),
        matching: find.byType(TextField),
      );
      await tester.enterText(fields.last, '0');
      await tap(tester, find.text(AppStrings.seatProfileSaveAction));
      expect(
        find.text(AppStrings.seatProfileCategoryImportanceInvalid),
        findsOneWidget,
      );
      expect(useCase.categorySaves, isEmpty);
      await tester.enterText(fields.last, '50');
      await tap(tester, find.text(AppStrings.seatProfileSaveAction));
      expect(
        find.text(AppStrings.seatProfileCategoriesSaveConfirmationTitle),
        findsOneWidget,
      );
      expect(useCase.categorySaves, isEmpty);
      await tap(tester, find.text(AppStrings.done));
      expect(useCase.categorySaves, isEmpty);
      await tap(tester, find.text(AppStrings.seatProfileSaveAction));
      await tap(tester, find.text(AppStrings.seatProfileSaveAction));
      expect(useCase.categorySaves.single.id, 'actual-seat');
      expect(
        useCase.categorySaves.single.categories.single.uuid,
        'category-id',
      );
      expect(useCase.categorySaves.single.categories.single.weightPercent, 50);
      expect(openedSeatId, 'actual-seat');
      expect(flowResult, isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'AI generation preserves choices, button size and the actual-seat destination',
    (tester) async {
      await mount(tester, initialData: editFormData);
      await tap(tester, find.text(AppStrings.seatProfileGenerateWithAiAction));
      await tap(tester, find.text(SeatContentSpecificity.high.label));
      await tap(tester, find.text(SeatContentTone.technical.label));
      final generate = find.widgetWithText(
        AppAiGenerateButton,
        AppStrings.seatProfileGenerateAction,
      );
      await tester.ensureVisible(generate);
      final before = tester.getSize(generate);
      final pending = Completer<void>();
      useCase.pendingGeneration = pending.future;
      await tester.tap(generate);
      await tester.pump();
      expect(tester.widget<AppAiGenerateButton>(generate).isLoading, isTrue);
      expect(tester.getSize(generate), before);
      expect(useCase.generations.single, (
        id: 'actual-seat',
        specificity: 'high',
        tone: 'technical',
      ));
      pending.complete();
      await tester.pumpAndSettle();
      expect(openedSeatId, 'actual-seat');
      expect(flowResult, isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('accounts without create access never initialize the form', (
    tester,
  ) async {
    AppManager.instance.updateCurrentUser(
      User(uuid: 'member', roles: ['team_member']),
    );
    await mount(tester);
    expect(find.text(AppStrings.seatProfileCreateAccessDenied), findsOneWidget);
    expect(useCase.departmentLoads, 0);
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets(
    'the category sheet reuses validation and retains its total-status display',
    (tester) async {
      bool? saved;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  saved = await showSeatProfileManageCategoriesSheet(
                    context,
                    initialCategories: const [createCategory],
                    onSaveCategories: (categories) =>
                        useCase.bulkUpsertSeatProfileCategories(
                          actualId: 'actual-seat',
                          categories: categories,
                        ),
                  );
                },
                child: const Text('Open categories'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open categories'));
      await tester.pumpAndSettle();
      expect(find.text('100%'), findsOneWidget);
      expect(
        find.text(AppStrings.seatProfileCategoryImportanceReached),
        findsOneWidget,
      );
      await tester.enterText(find.byType(TextField).last, '80');
      await tester.pump();
      expect(find.text('80%'), findsOneWidget);
      expect(
        find.text(AppStrings.seatProfileCategoryImportanceRemaining),
        findsOneWidget,
      );
      await tap(tester, find.text(AppStrings.seatProfileSaveAction));
      expect(useCase.categorySaves, isEmpty);
      expect(
        find.text(AppStrings.seatProfileCategoriesSaveConfirmationTitle),
        findsOneWidget,
      );
      await tap(tester, find.text(AppStrings.seatProfileSaveAction));
      expect(saved, isTrue);
      expect(
        useCase.categorySaves.single.categories.single.uuid,
        'category-id',
      );
      expect(useCase.categorySaves.single.categories.single.weightPercent, 80);
      expect(tester.takeException(), isNull);
    },
  );
}
