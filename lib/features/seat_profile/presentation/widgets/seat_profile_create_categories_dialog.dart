part of '../pages/seat_profile_create_screen.dart';

class _ManageSeatCategoriesDialog extends StatefulWidget {
  const _ManageSeatCategoriesDialog({required this.controller});

  final SeatProfileCreateController controller;

  @override
  State<_ManageSeatCategoriesDialog> createState() =>
      _ManageSeatCategoriesDialogState();
}

class _ManageSeatCategoriesDialogState
    extends State<_ManageSeatCategoriesDialog> {
  late final SeatProfileCategoryFormController _formController;

  @override
  void initState() {
    super.initState();
    _formController = SeatProfileCategoryFormController(
      loadCategories: widget.controller.loadSeatCategoryDrafts,
      onSaveCategories: widget.controller.saveSeatCategoryDrafts,
    )..addListener(_handleFormChanged);
    unawaited(_formController.initialize());
  }

  Future<void> _submit() async {
    var result = await _formController.submit();
    if (!mounted) return;
    if (result == SeatProfileCategorySaveResult.confirmationRequired) {
      final shouldContinue = await _showTotalConfirmationDialog();
      if (!mounted || !shouldContinue) return;
      result = await _formController.submit(confirmIncompleteTotal: true);
    }
    if (mounted && result == SeatProfileCategorySaveResult.saved) {
      Navigator.of(context).pop(true);
    }
  }

  void _handleFormChanged() {
    final message = _formController.takeErrorMessage();
    if (mounted && message != null) _showSnackBar(message);
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
        description:
            AppStrings.seatProfileCategoriesSaveConfirmationDescription,
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
    _formController
      ..removeListener(_handleFormChanged)
      ..dispose();
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
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 24,
          ),
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
                        const Align(
                          alignment: Alignment.centerRight,
                          child: FastCircularProgressIndicator(
                            width: 20,
                            height: 20,
                            color: AppColors.secondaryColor,
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
                          remainingImportanceLabel:
                              _formController.remainingImportanceLabel,
                          isBalanced: _formController.hasReachedImportance,
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
                          totalImportanceLabel:
                              _formController.totalImportanceLabel,
                          onAddTap: _formController.isSaving
                              ? null
                              : _formController.addRow,
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
                          alignment: isCompact
                              ? Alignment.center
                              : Alignment.centerRight,
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
