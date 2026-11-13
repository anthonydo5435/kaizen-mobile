import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sparrowkaizen/core/constants/app_strings.dart';
import 'package:sparrowkaizen/core/managers/app_manager.dart';
import 'package:sparrowkaizen/features/seat_profile/domain/entities/department.dart';
import 'package:sparrowkaizen/features/seat_profile/domain/entities/seat_profile_creation_result.dart';
import 'package:sparrowkaizen/features/seat_profile/presentation/providers/seat_profile_create_controller.dart';

import '../../support/seat_profile_create_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SeatProfileCreateUseCase useCase;

  setUp(() => useCase = SeatProfileCreateUseCase());

  Future<SeatProfileCreateController> create() async {
    final controller = SeatProfileCreateController(useCase);
    addTearDown(controller.dispose);
    await controller.initialize();
    controller.nameController.text = '  Operator  ';
    controller.selectDepartment(createDepartment.id);
    controller.selectPaygradeUnit(SeatProfilePaygradeUnit.hourly);
    return controller;
  }

  test(
    'create validates required fields, saves once, and locks the completed form',
    () async {
      final controller = SeatProfileCreateController(useCase);
      addTearDown(controller.dispose);
      await controller.initialize();
      expect(await controller.submit(), isFalse);
      expect(controller.errorMessage, AppStrings.seatProfileNameRequired);
      controller.nameController.text = '  Operator  ';
      expect(await controller.submit(), isFalse);
      expect(controller.errorMessage, AppStrings.seatProfileDepartmentRequired);
      controller.selectDepartment(createDepartment.id);
      expect(await controller.submit(), isFalse);
      expect(controller.errorMessage, AppStrings.seatProfilePaygradeRequired);
      controller.selectPaygradeUnit(SeatProfilePaygradeUnit.hourly);
      final pending = Completer<SeatProfileCreationResult>();
      useCase.pendingCreate = pending.future;
      final submission = controller.submit();
      expect(controller.isSubmitting, isTrue);
      expect(await controller.submit(), isFalse);
      pending.complete(createResult);
      expect(await submission, isTrue);
      expect(useCase.creations.single, (
        title: 'Operator',
        department: createDepartment,
        unit: 'hr',
      ));
      expect(controller.isFormLocked, isTrue);
      expect(controller.canSelectDepartment, isFalse);
      expect(controller.canUseDescriptionActions, isTrue);
      expect(controller.didCompleteFlow, isTrue);
      expect(controller.createdProfileSummary.map((row) => row.value), [
        'Operator',
        'Operations',
        AppStrings.seatProfilePaygradeHourly,
      ]);
      expect(await controller.submit(), isFalse);
      expect(useCase.creations, hasLength(1));
    },
  );

  test(
    'edit preserves initial department and unit and updates the actual ID',
    () async {
      useCase.departments = [otherCreateDepartment];
      final controller = SeatProfileCreateController(
        useCase,
        initialData: editFormData,
      );
      addTearDown(controller.dispose);
      await controller.initialize();
      expect(controller.departments, contains(createDepartment));
      expect(controller.canSelectDepartment, isFalse);
      expect(controller.canSelectPaygradeUnit, isFalse);
      expect(controller.isFormLocked, isFalse);
      controller.nameController.text = '  Senior Operator  ';
      expect(await controller.submit(), isTrue);
      expect(useCase.updates.single, (
        id: 'actual-seat',
        title: 'Senior Operator',
        department: createDepartment,
        unit: 'hr',
      ));
      expect(useCase.creations, isEmpty);
      expect(controller.shouldReturnAfterSubmit, isTrue);
      expect(controller.didCompleteFlow, isTrue);
    },
  );

  test(
    'access checks use shared create-entry and department permissions',
    () async {
      final manager = _Permissions();
      expect(
        SeatProfileCreateController.canAccessForm(appManager: manager),
        isTrue,
      );
      manager.canOpenCreate = false;
      expect(
        SeatProfileCreateController.canAccessForm(appManager: manager),
        isFalse,
      );
      expect(
        SeatProfileCreateController.canAccessForm(
          initialData: editFormData,
          appManager: manager,
        ),
        isTrue,
      );
      final controller = SeatProfileCreateController.forCurrentUser(
        useCase,
        appManager: manager,
      );
      addTearDown(controller.dispose);
      await controller.initialize();
      expect(controller.departments, [createDepartment]);
      controller.nameController.text = 'Operator';
      controller.selectDepartment(createDepartment.id);
      controller.selectPaygradeUnit(SeatProfilePaygradeUnit.hourly);
      manager.allowedDepartment = '';
      expect(await controller.submit(), isFalse);
      expect(
        controller.errorMessage,
        AppStrings.seatProfileDepartmentAccessDenied,
      );
      expect(useCase.creations, isEmpty);
      expect(
        SeatProfileCreateController.canAccessForm(
          initialData: editFormData,
          appManager: manager,
        ),
        isFalse,
      );
    },
  );

  test(
    'generation uses selected options and the actual ID and retains retry feedback',
    () async {
      final controller = await create();
      await controller.submit();
      controller.selectSpecificity(SeatContentSpecificity.high);
      controller.selectTone(SeatContentTone.technical);
      useCase.generationFailure = StateError('Generation unavailable');
      expect(await controller.generateSeatContentWithAi(), isFalse);
      expect(
        controller.seatContentGenerationErrorMessage,
        contains('Generation unavailable'),
      );
      expect(controller.canUseDescriptionActions, isTrue);
      useCase.generationFailure = null;
      final pending = Completer<void>();
      useCase.pendingGeneration = pending.future;
      final generation = controller.generateSeatContentWithAi();
      expect(controller.isGeneratingSeatContent, isTrue);
      expect(await controller.generateSeatContentWithAi(), isFalse);
      pending.complete();
      expect(await generation, isTrue);
      expect(useCase.generations.last, (
        id: 'actual-seat',
        specificity: 'high',
        tone: 'technical',
      ));
      expect(useCase.contentLoads, ['actual-seat']);
      expect(controller.seatContentGenerationErrorMessage, isNull);
    },
  );

  test(
    'categories retain UUIDs and use the seat ID fallback when no actual ID exists',
    () async {
      useCase.result = const SeatProfileCreationResult(
        id: 'created-seat',
        actualId: '',
        descriptionsCount: 0,
        categoriesCount: 1,
        categories: [createCategory],
      );
      final controller = await create();
      await controller.submit();
      expect(controller.detailTargetSeatId, 'created-seat');
      expect(await controller.loadSeatCategoryDrafts(), [createCategory]);
      await controller.saveSeatCategoryDrafts([createCategory]);
      expect(useCase.categorySaves.single.id, 'created-seat');
      expect(
        useCase.categorySaves.single.categories.single.uuid,
        'category-id',
      );
      expect(useCase.contentLoads, ['created-seat', 'created-seat']);
    },
  );

  test(
    'a department load completing after disposal does not notify a dead form',
    () async {
      final pending = Completer<List<Department>>();
      useCase.pendingDepartments = pending.future;
      final controller = SeatProfileCreateController(useCase);
      final loading = controller.initialize();
      controller.dispose();
      pending.complete([createDepartment]);
      await loading;
    },
  );
}

class _Permissions extends Fake implements AppManager {
  bool canOpenCreate = true;
  String allowedDepartment = 'operations';

  @override
  bool get currentUserCanOpenSeatProfileCreateFlow => canOpenCreate;

  @override
  bool canCurrentUserManageSeatProfileDepartment({
    required String departmentId,
  }) => departmentId == allowedDepartment;
}
