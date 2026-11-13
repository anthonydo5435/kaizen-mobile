part of '../pages/seat_profile_create_screen.dart';

class _SeatProfileCreateContent extends StatelessWidget {
  const _SeatProfileCreateContent({
    required this.controller,
    required this.onCompleteFlowToDetails,
  });

  final SeatProfileCreateController controller;
  final VoidCallback onCompleteFlowToDetails;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 24),
      children: [
        if (controller.errorMessage != null) ...[
          _CreateMessageCard(message: controller.errorMessage!),
          const SizedBox(height: 14),
        ],
        _SeatProfileTextField(
          label: AppStrings.seatProfileNameLabel,
          hintText: AppStrings.seatProfileNameHint,
          controller: controller.nameController,
          enabled: !controller.isFormLocked,
        ),
        const SizedBox(height: 16),
        _SeatProfileDropdownField<String>(
          label: AppStrings.paygradesDepartment,
          hintText: controller.departmentHint,
          value: controller.selectedDepartment?.id,
          selectedLabel: controller.selectedDepartment?.name,
          enabled: controller.canSelectDepartment,
          items: controller.departments
              .map(
                (department) => DropdownMenuItem<String>(
                  value: department.id,
                  child: Text(
                    department.name,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              )
              .toList(growable: false),
          onChanged: controller.selectDepartment,
          compact: true,
        ),
        const SizedBox(height: 16),
        _SeatProfileDropdownField<SeatProfilePaygradeUnit>(
          label: AppStrings.seatProfilePaygradeLabel,
          hintText: AppStrings.seatProfileSelectPaygradeHint,
          value: controller.selectedPaygradeUnit,
          selectedLabel: controller.selectedPaygradeUnit?.label,
          enabled: controller.canSelectPaygradeUnit,
          items: SeatProfilePaygradeUnit.values
              .map(
                (unit) => DropdownMenuItem<SeatProfilePaygradeUnit>(
                  value: unit,
                  child: Text(
                    unit.label,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              )
              .toList(growable: false),
          onChanged: controller.selectPaygradeUnit,
          compact: true,
        ),
        const SizedBox(height: 18),
        if (!controller.hasCreatedProfile) ...[
          AppButton(
            text: controller.submitActionLabel,
            onPressed: controller.canSubmit
                ? () async {
                    final didSubmit = await controller.submit();
                    if (!context.mounted ||
                        !didSubmit ||
                        !controller.shouldReturnAfterSubmit) {
                      return;
                    }

                    Navigator.of(context).pop(true);
                  }
                : null,
            isLoading: controller.isSubmitting,
            borderRadius: 12,
            minimumHeight: 48,
          ),
        ],
        if (controller.hasCreatedProfile) ...[
          const SizedBox(height: 18),
          _CreatedSeatProfileSummary(controller: controller),
        ],
        if (controller.showDescriptionActions) ...[
          const SizedBox(height: 18),
          _PostCreateDescriptionActions(
            controller: controller,
            onCompleteFlowToDetails: onCompleteFlowToDetails,
          ),
        ],
      ],
    );
  }
}

class _SeatProfileTextField extends StatelessWidget {
  const _SeatProfileTextField({
    required this.label,
    required this.hintText,
    required this.controller,
    required this.enabled,
  });

  final String label;
  final String hintText;
  final TextEditingController controller;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return _SeatProfileFieldShell(
      label: label,
      child: TextField(
        controller: controller,
        enabled: enabled,
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        cursorColor: AppColors.textPrimary,
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: TextStyle(
            color: AppColors.textSecondary.withValues(alpha: 0.85),
            fontSize: 14,
          ),
          border: InputBorder.none,
          isCollapsed: true,
        ),
      ),
    );
  }
}

class _SeatProfileDropdownField<T> extends StatelessWidget {
  const _SeatProfileDropdownField({
    required this.label,
    required this.hintText,
    required this.value,
    required this.selectedLabel,
    required this.items,
    required this.onChanged,
    required this.enabled,
    this.compact = false,
  });

  final String label;
  final String hintText;
  final T? value;
  final String? selectedLabel;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?>? onChanged;
  final bool enabled;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return _SeatProfileFieldShell(
      label: label,
      compact: compact,
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          isDense: compact,
          dropdownColor: AppColors.surfaceDark3,
          itemHeight: compact ? kMinInteractiveDimension : null,
          borderRadius: BorderRadius.circular(12),
          selectedItemBuilder: selectedLabel == null
              ? null
              : (context) => List<Widget>.generate(
                  items.length,
                  (_) => Text(
                    selectedLabel!,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
          icon: Icon(
            Icons.keyboard_arrow_down_rounded,
            color: enabled ? AppColors.textPrimary : AppColors.textSecondary,
            size: compact ? 20 : 24,
          ),
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          disabledHint: selectedLabel == null
              ? null
              : Text(
                  selectedLabel!,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
          hint: Text(
            hintText,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AppColors.textSecondary.withValues(alpha: 0.85),
              fontSize: 14,
            ),
          ),
          items: items,
          onChanged: enabled ? onChanged : null,
        ),
      ),
    );
  }
}

class _SeatProfileFieldShell extends StatelessWidget {
  const _SeatProfileFieldShell({
    required this.label,
    required this.child,
    this.compact = false,
  });

  final String label;
  final Widget child;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(16, compact ? 8 : 14, 16, compact ? 6 : 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppTextView.body2(
            label,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
          SizedBox(height: compact ? 6 : 10),
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(
              horizontal: 14,
              vertical: compact ? 6 : 14,
            ),
            decoration: BoxDecoration(
              color: AppColors.mainBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.fieldBorder.withValues(alpha: 0.7),
              ),
            ),
            child: child,
          ),
        ],
      ),
    );
  }
}

class _CreateMessageCard extends StatelessWidget {
  const _CreateMessageCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.secondaryColor.withValues(alpha: 0.18),
        ),
      ),
      child: AppTextView.body2(message, color: AppColors.textSecondary),
    );
  }
}

class _CreatedSeatProfileSummary extends StatelessWidget {
  const _CreatedSeatProfileSummary({required this.controller});

  final SeatProfileCreateController controller;

  @override
  Widget build(BuildContext context) {
    final summary = controller.createdProfileSummary;
    if (summary.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.secondaryColor.withValues(alpha: 0.16),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppTextView.body1(
            AppStrings.seatProfileCreatedSectionTitle,
            color: AppColors.secondaryColor,
            fontWeight: FontWeight.w700,
          ),
          const SizedBox(height: 16),
          ...List<Widget>.generate(
            summary.length,
            (index) => Padding(
              padding: EdgeInsets.only(
                bottom: index == summary.length - 1 ? 0 : 10,
              ),
              child: _CreatedSummaryRow(
                label: summary[index].label,
                value: summary[index].value,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CreatedSummaryRow extends StatelessWidget {
  const _CreatedSummaryRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 4,
          child: AppTextView.body2(
            label,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 3,
          child: AppTextView.body2(
            value,
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}

class _PostCreateDescriptionActions extends StatelessWidget {
  const _PostCreateDescriptionActions({
    required this.controller,
    required this.onCompleteFlowToDetails,
  });

  final SeatProfileCreateController controller;
  final VoidCallback onCompleteFlowToDetails;

  @override
  Widget build(BuildContext context) {
    final isEnabled = controller.canUseDescriptionActions;

    return Column(
      children: [
        _SeatProfileDottedActionButton(
          label: AppStrings.seatProfileAddOrUpdateSeatCategoryAction,
          onTap: isEnabled
              ? () => _showManageSeatCategoriesDialog(context)
              : null,
        ),
        const SizedBox(height: 12),
        AppAiGenerateButton(
          expand: true,
          minHeight: 40,
          textSize: 15,
          fontWeight: FontWeight.w700,
          label: AppStrings.seatProfileGenerateWithAiAction,
          onTap: isEnabled
              ? () => _showGenerateSeatContentDialog(context)
              : null,
        ),
      ],
    );
  }

  Future<void> _showGenerateSeatContentDialog(BuildContext context) async {
    controller.clearSeatContentGenerationError();

    final didGenerate = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ChangeNotifierProvider<SeatProfileCreateController>.value(
        value: controller,
        child: const _GenerateSeatContentDialog(),
      ),
    );

    if (didGenerate == true && context.mounted) {
      onCompleteFlowToDetails();
    }
  }

  Future<void> _showManageSeatCategoriesDialog(BuildContext context) async {
    final didSave = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ChangeNotifierProvider<SeatProfileCreateController>.value(
        value: controller,
        child: _ManageSeatCategoriesDialog(controller: controller),
      ),
    );

    if (didSave == true && context.mounted) {
      onCompleteFlowToDetails();
    }
  }
}

class _SeatProfileDottedActionButton extends StatelessWidget {
  const _SeatProfileDottedActionButton({
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isEnabled = onTap != null;
    final borderColor = isEnabled
        ? AppColors.secondaryColor
        : AppColors.fieldBorder.withValues(alpha: 0.28);
    const minimumHeight = 48.0;

    return Opacity(
      opacity: isEnabled ? 1 : 0.58,
      child: CustomPaint(
        painter: _SeatProfileDottedRoundedBorderPainter(
          color: borderColor,
          radius: 14,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(14),
            child: Ink(
              width: double.infinity,
              height: minimumHeight,
              decoration: BoxDecoration(
                color: AppColors.surfaceDark3.withValues(alpha: 0.72),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: AppTextView.body(
                  label,
                  color: isEnabled
                      ? AppColors.secondaryColor
                      : AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
