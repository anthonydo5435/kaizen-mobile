import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sparrowkaizen/core/constants/app_strings.dart';
import 'package:sparrowkaizen/features/seat_profile/domain/entities/seat_profile_category_draft.dart';
import 'package:sparrowkaizen/features/seat_profile/presentation/providers/seat_profile_category_form_controller.dart';

import '../../support/seat_profile_create_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final scenario in [
    (
      name: '',
      weight: '100',
      error: AppStrings.seatProfileCategoryNameRequired,
    ),
    (
      name: 'This title has too many characters',
      weight: '100',
      error: AppStrings.seatProfileCategoryNameCharacterLimit,
    ),
    (
      name: 'One Two Three Four',
      weight: '100',
      error: AppStrings.seatProfileCategoryNameWordLimit,
    ),
    (
      name: 'Delivery',
      weight: '',
      error: AppStrings.seatProfileCategoryImportanceRequired,
    ),
    (
      name: 'Delivery',
      weight: '0',
      error: AppStrings.seatProfileCategoryImportanceInvalid,
    ),
    (
      name: 'Delivery',
      weight: '1.2.3',
      error: AppStrings.seatProfileCategoryImportanceInvalid,
    ),
    (
      name: 'Delivery',
      weight: '101',
      error: AppStrings.seatProfileCategoryImportanceTotalExceeded,
    ),
  ]) {
    test('invalid category input blocks saving: ${scenario.error}', () async {
      var saves = 0;
      final controller = SeatProfileCategoryFormController(
        onSaveCategories: (_) async => saves++,
      );
      addTearDown(controller.dispose);
      controller.addRow();
      controller.rows.single.nameController.text = scenario.name;
      controller.rows.single.weightController.text = scenario.weight;
      expect(await controller.submit(), SeatProfileCategorySaveResult.notSaved);
      expect(controller.message, scenario.error);
      expect(saves, 0);
    });
  }

  test(
    'under-allocation requires confirmation and preserves UUIDs and trimmed titles',
    () async {
      List<SeatProfileCategoryDraft>? saved;
      final controller = SeatProfileCategoryFormController(
        onSaveCategories: (drafts) async => saved = drafts,
      );
      addTearDown(controller.dispose);
      controller.initializeWith([createCategory]);
      controller.rows.single.nameController.text = '  Daily Delivery  ';
      controller.rows.single.weightController.text = '80.5';
      expect(controller.remainingImportanceLabel, '19.5%');
      expect(
        controller.totalImportanceLabel,
        '${AppStrings.seatProfileCategoriesTotalLabel}: 80.5%',
      );
      expect(controller.importanceStatusValueLabel, '80.5%');
      expect(
        await controller.submit(),
        SeatProfileCategorySaveResult.confirmationRequired,
      );
      expect(saved, isNull);
      expect(
        await controller.submit(confirmIncompleteTotal: true),
        SeatProfileCategorySaveResult.saved,
      );
      expect(saved!.single.uuid, 'category-id');
      expect(saved!.single.title, 'Daily Delivery');
      expect(saved!.single.weightPercent, 80.5);
    },
  );

  test(
    'adding and removing rows preserves remaining drafts and total tolerance',
    () async {
      final controller = SeatProfileCategoryFormController(
        onSaveCategories: (_) async {},
      );
      addTearDown(controller.dispose);
      controller.initializeWith([createCategory]);
      controller.addRow();
      final added = controller.rows.last;
      added.nameController.text = 'New Category';
      added.weightController.text = '100.0005';
      controller.removeRowAt(0);
      expect(controller.rows.single, same(added));
      expect(controller.hasReachedImportance, isTrue);
      expect(controller.requiresTotalConfirmation, isFalse);
      expect(await controller.submit(), SeatProfileCategorySaveResult.saved);
    },
  );

  test(
    'saving blocks duplicate submissions, exposes failures once and allows retry',
    () async {
      final pending = Completer<void>();
      var saves = 0;
      final controller = SeatProfileCategoryFormController(
        onSaveCategories: (_) async {
          saves++;
          if (saves == 1) await pending.future;
        },
      );
      addTearDown(controller.dispose);
      controller.initializeWith([createCategory]);
      final saving = controller.submit();
      expect(controller.isSaving, isTrue);
      expect(await controller.submit(), SeatProfileCategorySaveResult.notSaved);
      controller.addRow();
      controller.removeRowAt(0);
      expect(controller.rows, hasLength(1));
      pending.completeError(StateError('Offline'));
      expect(await saving, SeatProfileCategorySaveResult.notSaved);
      expect(controller.isSaving, isFalse);
      expect(controller.takeErrorMessage(), contains('Offline'));
      expect(controller.takeErrorMessage(), isNull);
      expect(await controller.submit(), SeatProfileCategorySaveResult.saved);
      expect(saves, 2);
    },
  );

  test(
    'loading can fail and retry, and late responses are discarded after disposal',
    () async {
      final pending = Completer<List<SeatProfileCategoryDraft>>();
      var loads = 0;
      final controller = SeatProfileCategoryFormController(
        loadCategories: () async {
          if (++loads == 1) throw StateError('Offline');
          return pending.future;
        },
        onSaveCategories: (_) async {},
      );
      expect(controller.isLoading, isTrue);
      await controller.initialize();
      expect(controller.isLoading, isFalse);
      expect(controller.takeErrorMessage(), contains('Offline'));
      final loading = controller.initialize();
      controller.dispose();
      pending.complete([createCategory]);
      await loading;
      expect(controller.rows, isEmpty);
    },
  );
}
