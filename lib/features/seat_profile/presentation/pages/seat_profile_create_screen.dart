import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/managers/app_manager.dart';
import '../../../../core/widgets/app_ai_generate_button.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_confirmation_dialog.dart';
import '../../../../core/widgets/app_dialog_style.dart';
import '../../../../core/widgets/app_overlay_close_button.dart';
import '../../../../core/widgets/app_text_view.dart';
import '../../../../core/widgets/fast_circular_progress.dart';
import '../../../../routes/app_router.dart';
import '../../data/datasources/seat_profile_remote_data_source.dart';
import '../../data/repositories/seat_profile_repository_impl.dart';
import '../../domain/entities/seat_profile_category_draft.dart';
import '../../domain/usecases/get_seat_profiles_usecase.dart';
import '../models/seat_profile_form_initial_data.dart';
import '../providers/seat_profile_create_controller.dart';

class SeatProfileCreateScreen extends StatelessWidget {
  const SeatProfileCreateScreen({super.key, this.initialData});

  final SeatProfileFormInitialData? initialData;

  @override
  Widget build(BuildContext context) {
    if (!_canAccessSeatProfileForm()) {
      return const _SeatProfileCreateAccessDeniedView();
    }

    return MultiProvider(
      providers: [
        Provider<SeatProfileRemoteDataSource>(create: (_) => createSeatProfileRemoteDataSource()),
        ProxyProvider<SeatProfileRemoteDataSource, SeatProfileRepositoryImpl>(
          update: (_, remoteDataSource, __) => SeatProfileRepositoryImpl(remoteDataSource),
        ),
        ProxyProvider<SeatProfileRepositoryImpl, GetSeatProfilesUseCase>(
          update: (_, repository, __) => GetSeatProfilesUseCase(repository),
        ),
        ChangeNotifierProvider<SeatProfileCreateController>(
          create: (context) => SeatProfileCreateController(
            context.read<GetSeatProfilesUseCase>(),
            initialData: initialData,
            canManageDepartment: (department) => AppManager.instance
                .canCurrentUserManageSeatProfileDepartment(departmentId: department.id),
          )..initialize(),
        ),
      ],
      child: const _SeatProfileCreateScreenView(),
    );
  }

  bool _canAccessSeatProfileForm() {
    final initialData = this.initialData;
    if (initialData == null || !initialData.isValid) {
      return AppManager.instance.currentUserCanOpenSeatProfileCreateFlow;
    }

    final departmentId = initialData.department?.id.trim() ?? '';
    return AppManager.instance.canCurrentUserManageSeatProfileDepartment(
      departmentId: departmentId,
    );
  }
}

class _SeatProfileCreateAccessDeniedView extends StatelessWidget {
  const _SeatProfileCreateAccessDeniedView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.mainBg,
      appBar: AppBar(
        backgroundColor: AppColors.mainBg,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        leadingWidth: 40,
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(false),
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: AppTextView.body(
              AppStrings.seatProfileCreateAccessDenied,
              color: AppColors.textSecondary,
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}

class _SeatProfileCreateScreenView extends StatelessWidget {
  const _SeatProfileCreateScreenView();

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<SeatProfileCreateController>();

    return PopScope<Object?>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) {
          return;
        }

        _handleBackTap(context, controller);
      },
      child: Scaffold(
        backgroundColor: AppColors.mainBg,
        appBar: AppBar(
          backgroundColor: AppColors.mainBg,
          foregroundColor: AppColors.textPrimary,
          elevation: 0,
          leadingWidth: 40,
          leading: IconButton(
            onPressed: () => _handleBackTap(context, controller),
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
          ),
          title: AppTextView.title1(
            controller.title,
            color: AppColors.secondaryColor,
            fontSize: 24,
            fontWeight: FontWeight.w500,
          ),
        ),
        body: SafeArea(
          top: false,
          bottom: false,
          child: controller.isLoadingDepartments && controller.departments.isEmpty
              ? Center(child: FastCircularProgressIndicator())
              : _SeatProfileCreateContent(
                  controller: controller,
                  onCompleteFlowToDetails: () => _openSeatProfileDetails(context, controller),
                ),
        ),
      ),
    );
  }

  void _handleBackTap(BuildContext context, SeatProfileCreateController controller) {
    Navigator.of(context).pop(controller.didCompleteFlow);
  }

  void _openSeatProfileDetails(BuildContext context, SeatProfileCreateController controller) {
    final seatId = controller.detailTargetSeatId;
    if (seatId.isEmpty) {
      Navigator.of(context).pop(true);
      return;
    }

    AppRouter.pushReplacementNamed<void, bool>(
      context,
      AppRouter.seatProfileDetail,
      arguments: SeatProfileDetailRouteArgs(seatId: seatId),
      result: true,
    );
  }
}

class _SeatProfileCreateContent extends StatelessWidget {
  const _SeatProfileCreateContent({
    required this.controller,
    required this.onCompleteFlowToDetails,
  });

  final SeatProfileCreateController controller;
  final VoidCallback onCompleteFlowToDetails;

  @override
  Widget build(BuildContext context) {
    final hasDepartments = controller.departments.isNotEmpty;

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
          enabled: !controller.hasCreatedProfile,
        ),
        const SizedBox(height: 16),
        _SeatProfileDropdownField<String>(
          label: AppStrings.paygradesDepartment,
          hintText: hasDepartments
              ? AppStrings.seatProfileSelectDepartmentHint
              : AppStrings.seatProfileNoDepartmentsAvailable,
          value: controller.selectedDepartment?.id,
          selectedLabel: controller.selectedDepartment?.name,
          enabled: !controller.areSelectionFieldsLocked && hasDepartments,
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
          enabled: !controller.areSelectionFieldsLocked,
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
                    if (!context.mounted || !didSubmit || !controller.isEditMode) {
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
          style: TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w500),
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
            style: TextStyle(color: AppColors.textSecondary.withValues(alpha: 0.85), fontSize: 14),
          ),
          items: items,
          onChanged: enabled ? onChanged : null,
        ),
      ),
    );
  }
}

class _SeatProfileFieldShell extends StatelessWidget {
  const _SeatProfileFieldShell({required this.label, required this.child, this.compact = false});

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
          AppTextView.body2(label, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
          SizedBox(height: compact ? 6 : 10),
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: 14, vertical: compact ? 6 : 14),
            decoration: BoxDecoration(
              color: AppColors.mainBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.fieldBorder.withValues(alpha: 0.7)),
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
        border: Border.all(color: AppColors.secondaryColor.withValues(alpha: 0.18)),
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
    final createdProfile = controller.createdProfile;
    if (createdProfile == null) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.secondaryColor.withValues(alpha: 0.16)),
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
          _CreatedSummaryRow(
            label: AppStrings.seatProfileNameLabel,
            value: controller.nameController.text.trim(),
          ),
          const SizedBox(height: 10),
          _CreatedSummaryRow(
            label: AppStrings.paygradesDepartment,
            value: controller.selectedDepartment?.name ?? '',
          ),
          const SizedBox(height: 10),
          _CreatedSummaryRow(
            label: AppStrings.seatProfilePaygradeLabel,
            value: controller.selectedPaygradeUnit?.label ?? '',
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
          onTap: isEnabled ? () => _showManageSeatCategoriesDialog(context) : null,
        ),
        const SizedBox(height: 12),
        AppAiGenerateButton(
          expand: true,
          minHeight: 40,
          textSize: 15,
          fontWeight: FontWeight.w700,
          label: AppStrings.seatProfileGenerateWithAiAction,
          onTap: isEnabled ? () => _showGenerateSeatContentDialog(context) : null,
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
  const _SeatProfileDottedActionButton({required this.label, required this.onTap});

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
        painter: _SeatProfileDottedRoundedBorderPainter(color: borderColor, radius: 14),
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
                  color: isEnabled ? AppColors.secondaryColor : AppColors.textSecondary,
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

class _ManageSeatCategoriesDialog extends StatefulWidget {
  const _ManageSeatCategoriesDialog({required this.controller});

  final SeatProfileCreateController controller;

  @override
  State<_ManageSeatCategoriesDialog> createState() => _ManageSeatCategoriesDialogState();
}

class _ManageSeatCategoriesDialogState extends State<_ManageSeatCategoriesDialog> {
  late final _ManageSeatCategoriesDialogController _formController;

  @override
  void initState() {
    super.initState();
    _formController = _ManageSeatCategoriesDialogController();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      final categories = await widget.controller.loadSeatCategoryDrafts();
      if (!mounted) {
        return;
      }

      _formController.initializeWith(categories);
    } catch (error) {
      if (!mounted) {
        return;
      }

      _formController.setLoading(false);
      _showSnackBar(error.toString());
    }
  }

  Future<void> _submit() async {
    final validationMessage = _formController.validateEntries();
    if (validationMessage != null) {
      _formController.setMessage(validationMessage);
      return;
    }

    if (_formController.requiresTotalConfirmation) {
      final shouldContinue = await _showTotalConfirmationDialog();
      if (!mounted || !shouldContinue) {
        return;
      }
    }

    _formController.setSaving(true);

    try {
      await widget.controller.saveSeatCategoryDrafts(_formController.buildDrafts());
      if (!mounted) {
        return;
      }

      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) {
        return;
      }

      _showSnackBar(error.toString());
    } finally {
      if (mounted) {
        _formController.setSaving(false);
      }
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<bool> _showTotalConfirmationDialog() async {
    final didConfirm = await showDialog<bool>(
      context: context,
      builder: (_) => AppConfirmationDialog(
        title: AppStrings.seatProfileCategoriesSaveConfirmationTitle,
        description: AppStrings.seatProfileCategoriesSaveConfirmationDescription,
        onCancelCallback: () async => Navigator.of(context).pop(false),
        onConfirmCallback: () async => Navigator.of(context).pop(true),
        confirmText: AppStrings.seatProfileSaveAction,
        cancelText: AppStrings.done,
      ),
    );

    return didConfirm == true;
  }

  @override
  void dispose() {
    _formController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _formController,
      builder: (context, _) => PopScope<Object?>(
        canPop: !_formController.isSaving,
        child: Dialog(
          backgroundColor: AppColors.surfaceDark,
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          shape: AppDialogStyle.shape(radius: 28),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 720,
              maxHeight: MediaQuery.sizeOf(context).height * 0.88,
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isCompact = constraints.maxWidth < 560;
                final amountFieldWidth = isCompact ? 92.0 : 118.0;
                final deleteSlotWidth = isCompact ? 28.0 : 40.0;

                return SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    isCompact ? 18 : 24,
                    isCompact ? 18 : 20,
                    isCompact ? 18 : 24,
                    isCompact ? 20 : 24,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: AppTextView.body1(
                              AppStrings.seatProfileManageCategoriesDialogTitle,
                              color: AppColors.textPrimary,
                              fontSize: isCompact ? 16 : 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          _SeatContentDialogCloseButton(
                            onTap: _formController.isSaving
                                ? null
                                : () => Navigator.of(context).pop(),
                          ),
                        ],
                      ),
                      SizedBox(height: isCompact ? 14 : 18),
                      const _SeatContentDialogDivider(),
                      if (_formController.isSaving) ...[
                        SizedBox(height: isCompact ? 12 : 14),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: LinearProgressIndicator(
                            minHeight: 6,
                            color: AppColors.secondaryColor,
                            backgroundColor: AppColors.fieldBorder.withValues(alpha: 0.18),
                          ),
                        ),
                      ],
                      SizedBox(height: isCompact ? 18 : 24),
                      if (_formController.isLoading)
                        SizedBox(
                          height: isCompact ? 180 : 240,
                          child: Center(child: FastCircularProgressIndicator()),
                        )
                      else ...[
                        _ManageSeatCategoriesIntroSection(
                          isCompact: isCompact,
                          remainingImportance: _formController.remainingImportance,
                        ),
                        SizedBox(height: isCompact ? 20 : 28),
                        _SeatCategoryHeaderRow(
                          isCompact: isCompact,
                          amountFieldWidth: amountFieldWidth,
                          deleteSlotWidth: deleteSlotWidth,
                        ),
                        SizedBox(height: isCompact ? 10 : 14),
                        if (_formController.rows.isNotEmpty) ...[
                          ...List.generate(
                            _formController.rows.length,
                            (index) => Padding(
                              padding: EdgeInsets.only(
                                bottom: index == _formController.rows.length - 1
                                    ? (isCompact ? 10 : 12)
                                    : (isCompact ? 8 : 10),
                              ),
                              child: _SeatCategoryInputRow(
                                rowController: _formController.rows[index],
                                onDeleteTap: _formController.isSaving
                                    ? null
                                    : () => _formController.removeRowAt(index),
                                isCompact: isCompact,
                                amountFieldWidth: amountFieldWidth,
                              ),
                            ),
                          ),
                        ],
                        _SeatCategoryActionFooter(
                          isCompact: isCompact,
                          totalImportance: _formController.totalImportance,
                          onAddTap: _formController.isSaving ? null : _formController.addRow,
                        ),
                        SizedBox(height: isCompact ? 14 : 18),
                        AppTextView.body2(
                          AppStrings.seatProfileCategoryValidationNote,
                          color: AppColors.grey1,
                          fontSize: isCompact ? 12 : 14,
                          height: 1.45,
                        ),
                        if (_formController.message != null) ...[
                          const SizedBox(height: 16),
                          _CreateMessageCard(message: _formController.message!),
                        ],
                        SizedBox(height: isCompact ? 18 : 22),
                        Align(
                          alignment: isCompact ? Alignment.center : Alignment.centerRight,
                          child: SizedBox(
                            width: isCompact ? double.infinity : 180,
                            child: AppAiGenerateButton(
                              expand: true,
                              minHeight: 48,
                              textSize: 15,
                              fontWeight: FontWeight.w700,
                              label: AppStrings.seatProfileSaveAction,
                              isLoading: _formController.isSaving,
                              onTap: _formController.isSaving ? null : _submit,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _ManageSeatCategoriesDialogController extends ChangeNotifier {
  final List<_SeatCategoryRowController> rows = <_SeatCategoryRowController>[];
  bool _isLoading = true;
  bool _isSaving = false;
  String? _message;

  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  String? get message => _message;

  double get totalImportance =>
      rows.fold<double>(0, (total, row) => total + _parseWeightPercent(row.weightController.text));

  double get remainingImportance => 100 - totalImportance;
  bool get requiresTotalConfirmation => remainingImportance > 0.001;

  void initializeWith(List<SeatProfileCategoryDraft> categories) {
    for (final row in rows) {
      row.dispose();
    }
    rows.clear();

    for (final category in categories) {
      rows.add(
        _SeatCategoryRowController(
          uuid: category.uuid,
          title: category.title,
          weightPercent: _formatSeatProfilePercent(category.weightPercent),
          onChanged: _handleRowChanged,
        ),
      );
    }

    _isLoading = false;
    _message = null;
    notifyListeners();
  }

  void addRow() {
    rows.add(_SeatCategoryRowController(onChanged: _handleRowChanged));
    _message = null;
    notifyListeners();
  }

  void removeRowAt(int index) {
    if (index < 0 || index >= rows.length) {
      return;
    }

    final row = rows.removeAt(index);
    row.dispose();
    _message = null;
    notifyListeners();
  }

  void setLoading(bool value) {
    if (_isLoading == value) {
      return;
    }

    _isLoading = value;
    notifyListeners();
  }

  void setSaving(bool value) {
    if (_isSaving == value) {
      return;
    }

    _isSaving = value;
    notifyListeners();
  }

  void setMessage(String? message) {
    if (_message == message) {
      return;
    }

    _message = message;
    notifyListeners();
  }

  String? validateEntries() {
    for (final row in rows) {
      final title = row.nameController.text.trim();
      if (title.isEmpty) {
        return AppStrings.seatProfileCategoryNameRequired;
      }
      if (title.length > 25) {
        return AppStrings.seatProfileCategoryNameCharacterLimit;
      }
      if (_countWords(title) > 3) {
        return AppStrings.seatProfileCategoryNameWordLimit;
      }

      final weightText = row.weightController.text.trim();
      if (weightText.isEmpty) {
        return AppStrings.seatProfileCategoryImportanceRequired;
      }

      final weight = double.tryParse(weightText);
      if (weight == null || weight <= 0) {
        return AppStrings.seatProfileCategoryImportanceInvalid;
      }
    }

    if (totalImportance > 100.001) {
      return AppStrings.seatProfileCategoryImportanceTotalExceeded;
    }

    return null;
  }

  List<SeatProfileCategoryDraft> buildDrafts() {
    return rows
        .map(
          (row) => SeatProfileCategoryDraft(
            uuid: row.uuid,
            title: row.nameController.text.trim(),
            weightPercent: _parseWeightPercent(row.weightController.text),
          ),
        )
        .toList(growable: false);
  }

  void _handleRowChanged() {
    if (_message == null) {
      notifyListeners();
      return;
    }

    _message = null;
    notifyListeners();
  }

  @override
  void dispose() {
    for (final row in rows) {
      row.dispose();
    }
    super.dispose();
  }
}

class _SeatCategoryRowController {
  _SeatCategoryRowController({
    this.uuid,
    String title = '',
    String weightPercent = '',
    required VoidCallback onChanged,
  }) : _onChanged = onChanged {
    nameController = TextEditingController(text: title)..addListener(_handleChanged);
    weightController = TextEditingController(text: weightPercent)..addListener(_handleChanged);
  }

  final String? uuid;
  late final TextEditingController nameController;
  late final TextEditingController weightController;
  final VoidCallback _onChanged;

  void _handleChanged() {
    _onChanged();
  }

  void dispose() {
    nameController
      ..removeListener(_handleChanged)
      ..dispose();
    weightController
      ..removeListener(_handleChanged)
      ..dispose();
  }
}

class _CategoryRemainingCard extends StatelessWidget {
  const _CategoryRemainingCard({required this.remainingImportance, required this.isCompact});

  final double remainingImportance;
  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    final isBalanced = remainingImportance.abs() < 0.001;

    return Container(
      width: isCompact ? double.infinity : 220,
      padding: EdgeInsets.symmetric(horizontal: isCompact ? 14 : 18, vertical: isCompact ? 14 : 18),
      decoration: BoxDecoration(
        color: isBalanced ? AppColors.secondaryColor : AppColors.red1,
        borderRadius: BorderRadius.circular(isCompact ? 18 : 24),
      ),
      child: Row(
        children: [
          Expanded(
            child: AppTextView.title1(
              '${_formatSeatProfilePercent(remainingImportance)}%',
              color: AppColors.textPrimary,
              fontSize: isCompact ? 28 : 34,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(width: isCompact ? 10 : 12),
          Expanded(
            child: AppTextView.body1(
              AppStrings.seatProfileCategoryImportanceRemaining,
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w500,
              fontSize: isCompact ? 14 : 18,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _SeatCategoryInputRow extends StatelessWidget {
  const _SeatCategoryInputRow({
    required this.rowController,
    required this.onDeleteTap,
    required this.isCompact,
    required this.amountFieldWidth,
  });

  final _SeatCategoryRowController rowController;
  final VoidCallback? onDeleteTap;
  final bool isCompact;
  final double amountFieldWidth;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _DialogInputField(
            controller: rowController.nameController,
            hintText: AppStrings.seatProfileCategoryNameColumn,
            isCompact: isCompact,
            inputFormatters: <TextInputFormatter>[LengthLimitingTextInputFormatter(25)],
          ),
        ),
        SizedBox(width: isCompact ? 8 : 12),
        SizedBox(
          width: amountFieldWidth,
          child: _DialogInputField(
            controller: rowController.weightController,
            hintText: '0',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textAlign: TextAlign.center,
            isCompact: isCompact,
            inputFormatters: <TextInputFormatter>[
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
            ],
          ),
        ),
        SizedBox(width: isCompact ? 6 : 8),
        SizedBox(
          width: isCompact ? 28 : 32,
          height: isCompact ? 46 : 52,
          child: InkWell(
            onTap: onDeleteTap,
            borderRadius: BorderRadius.circular(12),
            child: Icon(
              Icons.delete_outline_rounded,
              color: AppColors.red1,
              size: isCompact ? 20 : 22,
            ),
          ),
        ),
      ],
    );
  }
}

class _DialogInputField extends StatelessWidget {
  const _DialogInputField({
    required this.controller,
    required this.hintText,
    this.keyboardType,
    this.textAlign = TextAlign.left,
    this.inputFormatters,
    this.isCompact = false,
  });

  final TextEditingController controller;
  final String hintText;
  final TextInputType? keyboardType;
  final TextAlign textAlign;
  final List<TextInputFormatter>? inputFormatters;
  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: isCompact ? 46 : 52,
      padding: EdgeInsets.symmetric(horizontal: isCompact ? 12 : 14),
      decoration: BoxDecoration(
        color: AppColors.mainBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.fieldBorder.withValues(alpha: 0.32)),
      ),
      child: Center(
        child: TextField(
          controller: controller,
          keyboardType: keyboardType,
          textAlign: textAlign,
          inputFormatters: inputFormatters,
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: isCompact ? 13 : 14,
            fontWeight: FontWeight.w500,
          ),
          cursorColor: AppColors.textPrimary,
          decoration: InputDecoration(
            border: InputBorder.none,
            isCollapsed: true,
            hintText: hintText,
            hintStyle: TextStyle(
              color: AppColors.textSecondary.withValues(alpha: 0.65),
              fontSize: isCompact ? 13 : 14,
            ),
          ),
        ),
      ),
    );
  }
}

class _DialogDottedActionButton extends StatelessWidget {
  const _DialogDottedActionButton({
    required this.label,
    required this.onTap,
    this.isCompact = false,
  });

  final String label;
  final VoidCallback? onTap;
  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    final isEnabled = onTap != null;

    return Opacity(
      opacity: isEnabled ? 1 : 0.58,
      child: CustomPaint(
        painter: _SeatProfileDottedRoundedBorderPainter(
          color: AppColors.fieldBorder.withValues(alpha: 0.45),
          radius: isCompact ? 16 : 18,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(isCompact ? 16 : 18),
            child: Ink(
              height: isCompact ? 56 : 64,
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(isCompact ? 16 : 18)),
              child: Center(
                child: AppTextView.body1(
                  label,
                  color: AppColors.fieldBorder.withValues(alpha: 0.6),
                  fontWeight: FontWeight.w600,
                  fontSize: isCompact ? 15 : 18,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ManageSeatCategoriesIntroSection extends StatelessWidget {
  const _ManageSeatCategoriesIntroSection({
    required this.isCompact,
    required this.remainingImportance,
  });

  final bool isCompact;
  final double remainingImportance;

  @override
  Widget build(BuildContext context) {
    final infoCard = Container(
      width: double.infinity,
      padding: EdgeInsets.all(isCompact ? 14 : 16),
      decoration: BoxDecoration(
        color: AppColors.mainBg.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(isCompact ? 16 : 20),
        border: Border.all(color: AppColors.fieldBorder.withValues(alpha: 0.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppTextView.body1(
            AppStrings.seatProfileManageCategoriesSectionTitle,
            color: AppColors.lightPurple2,
            fontSize: isCompact ? 16 : 18,
            fontWeight: FontWeight.w600,
          ),
          SizedBox(height: isCompact ? 8 : 10),
          AppTextView.body(
            AppStrings.seatProfileManageCategoriesDescription,
            color: AppColors.lightPurple1,
            fontSize: isCompact ? 13 : 15,
            height: 1.45,
          ),
        ],
      ),
    );

    if (isCompact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          infoCard,
          const SizedBox(height: 12),
          _CategoryRemainingCard(remainingImportance: remainingImportance, isCompact: true),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: infoCard),
        const SizedBox(width: 16),
        _CategoryRemainingCard(remainingImportance: remainingImportance, isCompact: false),
      ],
    );
  }
}

class _SeatCategoryHeaderRow extends StatelessWidget {
  const _SeatCategoryHeaderRow({
    required this.isCompact,
    required this.amountFieldWidth,
    required this.deleteSlotWidth,
  });

  final bool isCompact;
  final double amountFieldWidth;
  final double deleteSlotWidth;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: AppTextView.body1(
            AppStrings.seatProfileCategoryNameColumn,
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: isCompact ? 15 : 18,
          ),
        ),
        SizedBox(width: isCompact ? 8 : 12),
        SizedBox(
          width: amountFieldWidth,
          child: AppTextView.body1(
            AppStrings.seatProfileImportancePercentColumn,
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: isCompact ? 14 : 18,
            textAlign: TextAlign.center,
          ),
        ),
        SizedBox(width: deleteSlotWidth),
      ],
    );
  }
}

class _SeatCategoryActionFooter extends StatelessWidget {
  const _SeatCategoryActionFooter({
    required this.isCompact,
    required this.totalImportance,
    required this.onAddTap,
  });

  final bool isCompact;
  final double totalImportance;
  final VoidCallback? onAddTap;

  @override
  Widget build(BuildContext context) {
    final totalLabel =
        '${AppStrings.seatProfileCategoriesTotalLabel}: ${_formatSeatProfilePercent(totalImportance)}%';

    if (isCompact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _DialogDottedActionButton(
            label: AppStrings.seatProfileAddSeatCategoryAction,
            onTap: onAddTap,
            isCompact: true,
          ),
          const SizedBox(height: 10),
          AppTextView.body2(
            totalLabel,
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
            textAlign: TextAlign.right,
          ),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: _DialogDottedActionButton(
            label: AppStrings.seatProfileAddSeatCategoryAction,
            onTap: onAddTap,
          ),
        ),
        const SizedBox(width: 16),
        AppTextView.body1(totalLabel, color: AppColors.textPrimary, fontWeight: FontWeight.w700),
      ],
    );
  }
}

double _parseWeightPercent(String value) {
  return double.tryParse(value.trim()) ?? 0;
}

String _formatSeatProfilePercent(double value) {
  if (value == value.roundToDouble()) {
    return value.toInt().toString();
  }

  return value.toStringAsFixed(1).replaceFirst(RegExp(r'\.?0+$'), '');
}

int _countWords(String value) {
  return value.trim().split(RegExp(r'\s+')).where((word) => word.isNotEmpty).length;
}

class _GenerateSeatContentDialog extends StatelessWidget {
  const _GenerateSeatContentDialog();

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<SeatProfileCreateController>();

    return PopScope<Object?>(
      canPop: !controller.isGeneratingSeatContent,
      child: Dialog(
        backgroundColor: AppColors.surfaceDark,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        shape: AppDialogStyle.shape(radius: 28),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: AppTextView.body1(
                        AppStrings.seatProfileGenerateSeatContentDialogTitle,
                        color: AppColors.textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    _SeatContentDialogCloseButton(
                      onTap: controller.isGeneratingSeatContent
                          ? null
                          : () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                const _SeatContentDialogDivider(),
                const SizedBox(height: 24),
                const Center(
                  child: AppTextView.body(
                    AppStrings.seatProfileGenerateSeatContentDialogDescription,
                    color: AppColors.lightPurple1,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 24),
                _SeatContentGenerationOptionsCard(controller: controller),
                if (controller.seatContentGenerationErrorMessage != null) ...[
                  const SizedBox(height: 14),
                  _CreateMessageCard(message: controller.seatContentGenerationErrorMessage!),
                ],
                const SizedBox(height: 22),
                Center(
                  child: SizedBox(
                    width: 220,
                    child: AppAiGenerateButton(
                      expand: true,
                      minHeight: 48,
                      textSize: 15,
                      fontWeight: FontWeight.w700,
                      label: AppStrings.seatProfileGenerateAction,
                      isLoading: controller.isGeneratingSeatContent,
                      onTap: () async {
                        final didGenerate = await context
                            .read<SeatProfileCreateController>()
                            .generateSeatContentWithAi();
                        if (!context.mounted || !didGenerate) {
                          return;
                        }

                        Navigator.of(context).pop(true);
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SeatContentGenerationOptionsCard extends StatelessWidget {
  const _SeatContentGenerationOptionsCard({required this.controller});

  final SeatProfileCreateController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 22),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark3,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          const AppTextView.body1(
            AppStrings.seatProfileSpecificityLabel,
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w500,
          ),
          const SizedBox(height: 16),
          Row(
            children: SeatContentSpecificity.values
                .map(
                  (value) => Expanded(
                    child: _SeatContentOptionChip(
                      label: value.label,
                      isSelected: controller.selectedSpecificity == value,
                      onTap: controller.isGeneratingSeatContent
                          ? null
                          : () => controller.selectSpecificity(value),
                    ),
                  ),
                )
                .toList(growable: false),
          ),
          const SizedBox(height: 28),
          const AppTextView.body1(
            AppStrings.seatProfileToneLabel,
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w500,
          ),
          const SizedBox(height: 16),
          Row(
            children: SeatContentTone.values
                .map(
                  (value) => Expanded(
                    child: _SeatContentOptionChip(
                      label: value.label,
                      isSelected: controller.selectedTone == value,
                      labelFontSize: 11,
                      horizontalPadding: 0,
                      labelSpacing: 4,
                      indicatorSize: 14,
                      selectedDotSize: 6,
                      onTap: controller.isGeneratingSeatContent
                          ? null
                          : () => controller.selectTone(value),
                    ),
                  ),
                )
                .toList(growable: false),
          ),
        ],
      ),
    );
  }
}

class _SeatContentOptionChip extends StatelessWidget {
  const _SeatContentOptionChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.labelFontSize = 14,
    this.horizontalPadding = 4,
    this.labelSpacing = 8,
    this.indicatorSize = 16,
    this.selectedDotSize = 8,
  });

  final String label;
  final bool isSelected;
  final VoidCallback? onTap;
  final double labelFontSize;
  final double horizontalPadding;
  final double labelSpacing;
  final double indicatorSize;
  final double selectedDotSize;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: indicatorSize,
                height: indicatorSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? AppColors.secondaryColor : AppColors.lightPurple1,
                    width: 2,
                  ),
                ),
                child: isSelected
                    ? Center(
                        child: Container(
                          width: selectedDotSize,
                          height: selectedDotSize,
                          decoration: const BoxDecoration(
                            color: AppColors.secondaryColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                      )
                    : null,
              ),
              SizedBox(width: labelSpacing),
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: AppTextView.body(
                    label,
                    color: AppColors.textPrimary,
                    fontSize: labelFontSize,
                    fontWeight: FontWeight.w500,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SeatContentDialogCloseButton extends StatelessWidget {
  const _SeatContentDialogCloseButton({required this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: onTap != null ? 1 : 0.55,
      child: AppOverlayCloseButton(onTap: onTap),
    );
  }
}

class _SeatContentDialogDivider extends StatelessWidget {
  const _SeatContentDialogDivider();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const _SeatContentDialogDividerDot(),
        Expanded(child: Container(height: 1, color: AppColors.fieldBorder.withValues(alpha: 0.34))),
        const _SeatContentDialogDividerDot(),
      ],
    );
  }
}

class _SeatContentDialogDividerDot extends StatelessWidget {
  const _SeatContentDialogDividerDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 10,
      margin: const EdgeInsets.symmetric(horizontal: 2),
      decoration: const BoxDecoration(color: AppColors.hex51597a, shape: BoxShape.circle),
    );
  }
}

class _SeatProfileDottedRoundedBorderPainter extends CustomPainter {
  const _SeatProfileDottedRoundedBorderPainter({required this.color, required this.radius});

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius)));

    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final nextDistance = distance + 6;
        canvas.drawPath(metric.extractPath(distance, nextDistance), paint);
        distance = nextDistance + 4;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SeatProfileDottedRoundedBorderPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.radius != radius;
  }
}
