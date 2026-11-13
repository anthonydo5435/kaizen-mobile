import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_radio_selection_tile.dart';
import '../../../../core/widgets/app_selection_sheet.dart';
import '../../../../core/widgets/app_text_view.dart';
import '../../../../core/widgets/fast_circular_progress.dart';
import '../controllers/training_library_controller.dart';
import 'training_library_selection_sheet.dart';
import 'training_library_status_state.dart';
import 'training_selection_step_field.dart';

Future<void> showTrainingLibrarySeatSelectionSheet(
  BuildContext context, {
  required TrainingLibraryController controller,
}) async {
  FocusScope.of(context).unfocus();
  controller.clearSelectionError();
  unawaited(controller.openSeatSelection());
  try {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _SeatSelectionContent(
        controller: controller,
        onApply: () async {
          FocusScope.of(sheetContext).unfocus();
          final succeeded = await controller.applyPendingSeatSelection();
          if (succeeded && sheetContext.mounted) {
            Navigator.of(sheetContext).pop();
          }
        },
      ),
    );
  } finally {
    controller.closeSeatSelection();
  }
}

class _SeatSelectionContent extends StatelessWidget {
  const _SeatSelectionContent({required this.controller, required this.onApply});

  final TrainingLibraryController controller;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => TrainingLibrarySelectionSheet(
        isBusy: controller.isApplyingSelection,
        child: Column(
          children: [
            AppFilterSheetHeader(
              title: AppStrings.trainingLibraryFilterTitle,
              centerTitle: true,
              onClose: controller.isApplyingSelection ? null : () => Navigator.of(context).pop(),
            ),
            Expanded(child: _SeatFilterFields(controller: controller)),
            TrainingLibrarySelectionError(message: controller.selectionErrorMessage),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: AppButton(
                text: AppStrings.done,
                textSize: 14,
                isLoading: controller.isApplyingSelection,
                onPressed: controller.canApplySelection && !controller.isLoadingSeatOptions
                    ? onApply
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SeatFilterFields extends StatelessWidget {
  const _SeatFilterFields({required this.controller});

  final TrainingLibraryController controller;

  @override
  Widget build(BuildContext context) {
    if (controller.isLoadingSeatOptions) {
      return Center(child: FastCircularProgressIndicator(width: 24, height: 24));
    }
    if (controller.seatOptionsError != null) {
      return Center(
        child: TrainingLibraryStatusState(
          message: controller.seatOptionsError!,
          actionLabel: AppStrings.trainingLibraryRetry,
          onActionTap: controller.loadSeatOptions,
        ),
      );
    }

    final enabled = !controller.isApplyingSelection;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
      child: Column(
        children: [
          TrainingSelectionStepField(
            hintText: AppStrings.trainingSetupSelectSeat,
            selectedText: controller.pendingSeatSelection?.title,
            enabled: enabled,
            onTap: () => _selectSeat(context),
          ),
          const SizedBox(height: 22),
          TrainingSelectionStepField(
            hintText: AppStrings.trainingSetupSelectCategory,
            selectedText: controller.pendingCategorySelection?.title,
            enabled:
                enabled &&
                controller.pendingSeatSelectionId != null &&
                controller.categoryOptions.isNotEmpty,
            onTap: () => _selectCategory(context),
          ),
          const SizedBox(height: 22),
          TrainingSelectionStepField(
            hintText: AppStrings.trainingSetupSelectDescription,
            selectedText: controller.pendingDescriptionSelection?.name,
            enabled:
                enabled &&
                controller.pendingCategorySelection != null &&
                controller.descriptionOptions.isNotEmpty,
            onTap: () => _selectDescription(context),
          ),
          if (controller.pendingSeatSelectionId != null && controller.categoryOptions.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 16),
              child: AppTextView.body2(
                AppStrings.seatProfileNoCategoriesFound,
                color: AppColors.textSecondary,
              ),
            ),
          if (controller.pendingCategorySelection != null && controller.descriptionOptions.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 16),
              child: AppTextView.body2(
                AppStrings.seatProfileNoDescriptionsFound,
                color: AppColors.textSecondary,
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _selectSeat(BuildContext context) async {
    final seats = controller.seatOptions;
    final id = await _showOptions(
      context,
      title: AppStrings.trainingSetupSelectSeat,
      searchHint: AppStrings.trainingSetupSearchSeat,
      allLabel: AppStrings.trainingLibraryAllSeats,
      selectedId: controller.pendingSeatSelectionId,
      options: seats.map((seat) => (id: seat.id, label: seat.title)).toList(),
    );
    if (id == null || !context.mounted) return;
    controller.updatePendingSeatSelection(seats.where((seat) => seat.id == id).firstOrNull);
  }

  Future<void> _selectCategory(BuildContext context) async {
    final categories = controller.categoryOptions;
    final id = await _showOptions(
      context,
      title: AppStrings.trainingSetupSelectCategoryTitle,
      searchHint: AppStrings.trainingSetupSearchCategory,
      allLabel: AppStrings.trainingLibraryAllCategories,
      selectedId: controller.pendingCategorySelection?.id,
      options: categories.map((category) => (id: category.id, label: category.title)).toList(),
    );
    if (id == null || !context.mounted) return;
    controller.updatePendingCategorySelection(
      categories.where((category) => category.id == id).firstOrNull,
    );
  }

  Future<void> _selectDescription(BuildContext context) async {
    final descriptions = controller.descriptionOptions;
    final id = await _showOptions(
      context,
      title: AppStrings.trainingSetupSelectDescriptionTitle,
      searchHint: AppStrings.trainingSetupSearchDescription,
      allLabel: AppStrings.trainingLibraryAllDescriptions,
      selectedId: controller.pendingDescriptionSelection?.id,
      options: descriptions
          .map((description) => (id: description.id, label: description.name))
          .toList(),
    );
    if (id == null || !context.mounted) return;
    controller.updatePendingDescriptionSelection(
      descriptions.where((description) => description.id == id).firstOrNull,
    );
  }

  Future<String?> _showOptions(
    BuildContext context, {
    required String title,
    required String searchHint,
    required String allLabel,
    required String? selectedId,
    required List<_FilterOption> options,
  }) => showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _FilterOptionsSheet(
      title: title,
      searchHint: searchHint,
      allLabel: allLabel,
      selectedId: selectedId,
      options: options,
    ),
  );
}

typedef _FilterOption = ({String id, String label});

class _FilterOptionsSheet extends StatefulWidget {
  const _FilterOptionsSheet({
    required this.title,
    required this.searchHint,
    required this.allLabel,
    required this.selectedId,
    required this.options,
  });

  final String title;
  final String searchHint;
  final String allLabel;
  final String? selectedId;
  final List<_FilterOption> options;

  @override
  State<_FilterOptionsSheet> createState() => _FilterOptionsSheetState();
}

class _FilterOptionsSheetState extends State<_FilterOptionsSheet> {
  final ValueNotifier<String> _search = ValueNotifier('');

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TrainingLibrarySelectionSheet(
    child: Column(
      children: [
        TrainingLibrarySelectionHeader(
          title: widget.title,
          searchHint: widget.searchHint,
          onSearchChanged: (value) => _search.value = value.trim().toLowerCase(),
        ),
        Expanded(
          child: ValueListenableBuilder<String>(
            valueListenable: _search,
            builder: (context, search, _) {
              final options = widget.options
                  .where((option) => option.label.toLowerCase().contains(search))
                  .toList();
              return ListView.builder(
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.only(bottom: 16),
                itemCount: options.length + 1 + (options.isEmpty ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return AppRadioSelectionTile(
                      title: widget.allLabel,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 28),
                      isSelected: widget.selectedId == null,
                      onTap: () => Navigator.of(context).pop(''),
                    );
                  }
                  if (options.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.all(24),
                      child: AppTextView.body2(
                        AppStrings.trainingSetupNoMatches,
                        color: AppColors.textSecondary,
                        textAlign: TextAlign.center,
                      ),
                    );
                  }
                  final option = options[index - 1];
                  return AppRadioSelectionTile(
                    title: option.label,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 28),
                    isSelected: widget.selectedId == option.id,
                    onTap: () => Navigator.of(context).pop(option.id),
                  );
                },
              );
            },
          ),
        ),
      ],
    ),
  );
}
