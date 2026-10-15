import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sparrowkaizen/core/constants/app_strings.dart';
import 'package:sparrowkaizen/core/widgets/app_button.dart';
import 'package:sparrowkaizen/core/widgets/app_overlay_close_button.dart';
import 'package:sparrowkaizen/core/widgets/fast_circular_progress.dart';
import 'package:sparrowkaizen/features/check_in/domain/repositories/audit_repository.dart';
import 'package:sparrowkaizen/features/seat_profile/domain/entities/department.dart';
import 'package:sparrowkaizen/features/seat_profile/domain/entities/seat_profile_detail.dart';
import 'package:sparrowkaizen/features/seat_profile/domain/repositories/seat_profile_repository.dart';
import 'package:sparrowkaizen/features/seat_profile/domain/usecases/get_seat_profiles_usecase.dart';
import 'package:sparrowkaizen/features/training/domain/entities/training_library_module.dart';
import 'package:sparrowkaizen/features/training/domain/entities/training_library_page.dart';
import 'package:sparrowkaizen/features/training/domain/repositories/training_library_repository.dart';
import 'package:sparrowkaizen/features/training/domain/usecases/get_training_library_modules_usecase.dart';
import 'package:sparrowkaizen/features/training/presentation/controllers/training_library_controller.dart';
import 'package:sparrowkaizen/features/training/presentation/controllers/training_library_lesson_visibility_controller.dart';
import 'package:sparrowkaizen/features/training/presentation/widgets/training_library_department_selection_sheet.dart';
import 'package:sparrowkaizen/features/training/presentation/widgets/training_library_lesson_visibility_sheet.dart';
import 'package:sparrowkaizen/features/training/presentation/widgets/training_library_seat_selection_sheet.dart';
import 'package:sparrowkaizen/features/training/presentation/widgets/training_library_selection_sheet.dart';
import 'package:sparrowkaizen/features/training/presentation/widgets/training_selection_step_field.dart';

void main() {
  for (final selectSeat in [true, false]) {
    testWidgets(
      selectSeat
          ? 'seat applies only from Done and keeps the draft after failure'
          : 'department keeps progress in the option and retries failures',
      (tester) async {
        final repository = _LibraryRepository();
        final controller = TrainingLibraryController(
          GetTrainingLibraryModulesUseCase(repository),
          getSeatProfilesUseCase: GetSeatProfilesUseCase(_SeatRepository()),
        );
        addTearDown(controller.dispose);
        await controller.initialize();
        await tester.pumpWidget(
          _host(
            (context) => selectSeat
                ? showTrainingLibrarySeatSelectionSheet(
                    context,
                    controller: controller,
                  )
                : showTrainingLibraryDepartmentSelectionSheet(
                    context,
                    controller: controller,
                  ),
          ),
        );
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();

        if (selectSeat) {
          await tester.tap(find.text(AppStrings.trainingSetupSelectSeat));
          await tester.pumpAndSettle();
        }
        final title = selectSeat ? 'Sales Seat' : 'Sales';
        final pending = Completer<TrainingLibraryPage>();
        repository.response = pending.future;
        final requestsBeforeSelection = repository.requests;
        await tester.tap(find.text(title));
        if (selectSeat) {
          await tester.pumpAndSettle();
        } else {
          await tester.pump();
        }

        if (selectSeat) {
          expect(controller.pendingSeatSelectionId, 'sales');
          expect(controller.selectedSeatId, isNull);
          expect(controller.searchQuery, isEmpty);
          expect(controller.isApplyingSelection, isFalse);
          expect(repository.requests, requestsBeforeSelection);
          await tester.tap(find.text(AppStrings.done));
          await tester.pump();
        }

        expect(find.byType(TrainingLibrarySelectionSheet), findsOneWidget);
        final tile = find.ancestor(
          of: find.text(title),
          matching: find.byType(ListTile),
        );
        expect(
          find.descendant(
            of: selectSeat ? find.byType(AppButton) : tile,
            matching: find.byType(FastCircularProgressIndicator),
          ),
          findsOneWidget,
        );
        expect(controller.isInlineLoading, isFalse);
        expect(controller.visibleItems.map((item) => item.id), [
          'operations',
          'sales',
        ]);
        expect(
          tester
              .widget<AppOverlayCloseButton>(find.byType(AppOverlayCloseButton))
              .onTap,
          isNull,
        );
        expect(
          await controller.applyDepartmentSelection('operations'),
          isFalse,
        );

        pending.completeError(Exception('API failure'));
        await tester.pumpAndSettle();

        expect(find.byType(TrainingLibrarySelectionSheet), findsOneWidget);
        expect(
          find.text(AppStrings.trainingLibraryUnableToApplyFilter),
          findsOneWidget,
        );
        expect(controller.selectedDepartmentId, 'all');
        expect(controller.selectedSeatId, isNull);
        expect(controller.errorMessage, isNull);
        expect(controller.visibleItems, hasLength(2));
        if (selectSeat) {
          expect(controller.pendingSeatSelectionId, 'sales');
        }

        final retry = Completer<TrainingLibraryPage>();
        repository.response = retry.future;
        await tester.tap(find.text(selectSeat ? AppStrings.done : title));
        await tester.pump();
        retry.complete(
          TrainingLibraryPage(
            items: [_module('sales', 'Sales')],
            hasNextPage: false,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(TrainingLibrarySelectionSheet), findsNothing);
        expect(controller.visibleItems.map((item) => item.id), ['sales']);
        expect(controller.isApplyingSelection, isFalse);
        expect(controller.isInlineLoading, isFalse);
        expect(
          selectSeat
              ? controller.selectedSeatId
              : controller.selectedDepartmentId,
          'sales',
        );
      },
    );
  }

  testWidgets(
    'closing discards a seat draft and All Seats also waits for Done',
    (tester) async {
      final repository = _LibraryRepository();
      final controller = TrainingLibraryController(
        GetTrainingLibraryModulesUseCase(repository),
        getSeatProfilesUseCase: GetSeatProfilesUseCase(_SeatRepository()),
      );
      addTearDown(controller.dispose);
      await controller.initialize();
      await controller.selectDepartment('sales');
      await controller.selectSeat(_module('sales', 'Sales').seat);
      final requestsBeforeOpening = repository.requests;
      await tester.pumpWidget(
        _host(
          (context) => showTrainingLibrarySeatSelectionSheet(
            context,
            controller: controller,
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(controller.pendingSeatSelectionId, 'sales');
      await tester.tap(find.text('Sales Seat'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(AppStrings.trainingLibraryAllSeats));
      await tester.pumpAndSettle();
      expect(controller.pendingSeatSelectionId, isNull);
      expect(controller.selectedSeatId, 'sales');
      expect(repository.requests, requestsBeforeOpening);
      await tester.tap(find.byType(AppOverlayCloseButton));
      await tester.pumpAndSettle();
      expect(controller.selectedSeatId, 'sales');
      expect(controller.searchQuery, isEmpty);
      expect(controller.appliedFilterTags.single.label, 'Sales Seat');

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(controller.pendingSeatSelectionId, 'sales');
      await tester.tap(find.text('Sales Seat'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(AppStrings.trainingLibraryAllSeats));
      await tester.pumpAndSettle();
      expect(repository.requests, requestsBeforeOpening);
      await tester.tap(find.text(AppStrings.done));
      await tester.pumpAndSettle();
      expect(controller.selectedSeatId, isNull);
      expect(controller.searchQuery, isEmpty);
      expect(controller.selectedDepartmentId, 'sales');
      expect(repository.requests, requestsBeforeOpening + 1);
      expect(find.byType(TrainingLibrarySelectionSheet), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Done remains visible above the keyboard on a small screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    final controller = TrainingLibraryController(
      GetTrainingLibraryModulesUseCase(_LibraryRepository()),
      getSeatProfilesUseCase: GetSeatProfilesUseCase(_SeatRepository()),
    );
    addTearDown(controller.dispose);
    await controller.initialize();
    await tester.pumpWidget(
      _host(
        (context) => showTrainingLibrarySeatSelectionSheet(
          context,
          controller: controller,
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppStrings.trainingSetupSelectSeat));
    await tester.pumpAndSettle();
    await tester.showKeyboard(find.byType(TextField));
    tester.view.viewInsets = const FakeViewPadding(bottom: 240);
    await tester.pumpAndSettle();

    expect(find.text('Sales Seat').hitTestable(), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'missing');
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.trainingSetupNoMatches), findsOneWidget);
    expect(find.text('Sales Seat'), findsNothing);
    await tester.tap(find.byType(AppOverlayCloseButton).last);
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.done).hitTestable(), findsOneWidget);
    expect(
      tester.getBottomLeft(find.byType(AppButton)).dy,
      lessThanOrEqualTo(400),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('dropdowns unlock in order and apply together only on Done', (
    tester,
  ) async {
    final repository = _LibraryRepository();
    final controller = TrainingLibraryController(
      GetTrainingLibraryModulesUseCase(repository),
      getSeatProfilesUseCase: GetSeatProfilesUseCase(_SeatRepository()),
    );
    addTearDown(controller.dispose);
    await controller.initialize();
    await tester.pumpWidget(
      _host(
        (context) => showTrainingLibrarySeatSelectionSheet(
          context,
          controller: controller,
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    List<bool> enabledSteps() => tester
        .widgetList<TrainingSelectionStepField>(
          find.byType(TrainingSelectionStepField),
        )
        .map((field) => field.enabled)
        .toList();
    expect(enabledSteps(), [true, false, false]);
    await tester.tap(find.text(AppStrings.trainingSetupSelectSeat));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sales Seat'));
    await tester.pumpAndSettle();
    expect(enabledSteps(), [true, true, false]);
    await tester.tap(find.text(AppStrings.trainingSetupSelectCategory));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Safety'));
    await tester.pumpAndSettle();
    expect(enabledSteps(), [true, true, true]);
    await tester.tap(find.text(AppStrings.trainingSetupSelectDescription));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Safety procedures'));
    await tester.pumpAndSettle();
    expect(controller.selectedDescriptionId, isNull);
    expect(repository.requests, 1);

    await tester.tap(find.text('Safety'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Other category'));
    await tester.pumpAndSettle();
    expect(enabledSteps(), [true, true, false]);
    expect(find.text('Safety procedures'), findsNothing);
    expect(
      find.text(AppStrings.seatProfileNoDescriptionsFound),
      findsOneWidget,
    );
    await tester.tap(find.text('Other category'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Safety'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppStrings.trainingSetupSelectDescription));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Safety procedures'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppStrings.done));
    await tester.pumpAndSettle();
    expect(controller.selectedSeatId, 'sales');
    expect(controller.selectedCategoryId, 'category');
    expect(controller.selectedDescriptionId, 'sales');
    expect(controller.visibleItems.single.id, 'sales');
    expect(find.byType(TrainingLibrarySelectionSheet), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'visibility replaces the clicked radio with progress and closes only after success',
    (tester) async {
      final repository = _AuditRepository();
      final controller = TrainingLibraryLessonVisibilityController(repository);
      addTearDown(controller.dispose);
      const lesson = TrainingLibraryLesson(
        id: 'lesson',
        title: 'Lesson',
        description: '',
        thumbnailLink: null,
        isPubliclyAvailable: false,
      );
      await tester.pumpWidget(
        _host(
          (context) => showTrainingLibraryLessonVisibilitySheet(
            context,
            lesson: lesson,
            controller: controller,
            onApply: (value) => controller.updateLessonVisibility(
              lesson: lesson,
              isPubliclyAvailable: value,
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      final pending = Completer<void>();
      repository.response = pending.future;
      await tester.tap(find.text(AppStrings.trainingLibraryAllVisibility));
      await tester.pump();
      final tile = find.ancestor(
        of: find.text(AppStrings.trainingLibraryAllVisibility),
        matching: find.byType(ListTile),
      );
      expect(
        find.descendant(
          of: tile,
          matching: find.byType(FastCircularProgressIndicator),
        ),
        findsOneWidget,
      );
      expect(controller.isLessonPubliclyAvailable(lesson), isFalse);
      expect(find.byType(TrainingLibrarySelectionSheet), findsOneWidget);

      pending.completeError(Exception('API failure'));
      await tester.pumpAndSettle();
      expect(
        find.text(AppStrings.trainingLibraryUnableToUpdateVisibility),
        findsOneWidget,
      );
      expect(controller.isLessonPubliclyAvailable(lesson), isFalse);

      final retry = Completer<void>();
      repository.response = retry.future;
      await tester.tap(find.text(AppStrings.trainingLibraryAllVisibility));
      await tester.pump();
      retry.complete();
      await tester.pumpAndSettle();
      expect(find.byType(TrainingLibrarySelectionSheet), findsNothing);
      expect(controller.isLessonPubliclyAvailable(lesson), isTrue);
      expect(controller.isUpdatingAnyLesson, isFalse);
    },
  );
}

Widget _host(Future<void> Function(BuildContext) onOpen) => MaterialApp(
  home: Scaffold(
    body: Builder(
      builder: (context) => TextButton(
        onPressed: () => onOpen(context),
        child: const Text('Open'),
      ),
    ),
  ),
);

class _LibraryRepository extends Fake implements TrainingLibraryRepository {
  Future<TrainingLibraryPage>? response;
  int requests = 0;

  @override
  Future<TrainingLibraryPage> getTrainingLibraryModules({
    required String view,
    required int page,
    int pageSize = 10,
    String searchType = 'category',
    String searchText = '',
    String? departmentId,
    String? jobId,
    String? jobCategoryId,
    String? jobCategoryDescriptionId,
    bool forceRefresh = false,
  }) async {
    requests++;
    return response ??
        TrainingLibraryPage(
          items: [
            _module('operations', 'Operations'),
            _module('sales', 'Sales'),
          ],
          hasNextPage: false,
        );
  }
}

class _SeatRepository extends Fake implements SeatProfileRepository {
  @override
  Future<List<SeatProfileDetail>> seatProfileCategoryTrainings() async =>
      const [
        SeatProfileDetail(
          id: 'sales',
          actualId: 'actual-sales',
          title: 'Sales Seat',
          department: Department(id: 'sales', name: 'Sales'),
          paygradeUnit: '',
          categories: [
            SeatProfileCategory(
              id: 'category',
              title: 'Safety',
              weightPercent: 0,
              descriptions: [
                SeatProfileDescription(
                  id: 'sales',
                  actualId: 'sales',
                  name: 'Safety procedures',
                  auditSpecifics: '',
                  auditFactorType: '',
                  milestoneDays: '',
                ),
              ],
            ),
            SeatProfileCategory(
              id: 'other',
              title: 'Other category',
              weightPercent: 0,
              descriptions: [],
            ),
          ],
        ),
      ];
}

class _AuditRepository extends Fake implements AuditRepository {
  Future<void>? response;

  @override
  Future<void> updateSeatDescriptionTrainingModuleVisibility({
    required String moduleId,
    required bool isPubliclyAvailable,
  }) async {
    await response;
  }
}

TrainingLibraryModule _module(String id, String department) =>
    TrainingLibraryModule(
      id: id,
      title: id,
      description: '',
      department: TrainingLibraryDepartment(id: id, name: department),
      totalDuration: 0,
      seat: TrainingLibrarySeat(id: id, title: '$department Seat'),
      lessons: const [],
      thumbnailLink: null,
      category: const TrainingLibraryCategory(
        id: 'category',
        title: 'Category',
      ),
    );
