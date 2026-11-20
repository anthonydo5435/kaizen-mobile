part of 'package:sparrowkaizen/features/training/presentation/pages/edit_training_screen.dart';

class _GenerateSopDialog extends StatefulWidget {
  const _GenerateSopDialog();

  @override
  State<_GenerateSopDialog> createState() => _GenerateSopDialogState();
}

class _GenerateSopDialogState extends State<_GenerateSopDialog> {
  final TextEditingController _confirmationController = TextEditingController();

  bool get _canRegenerate {
    return _confirmationController.text.trim().toUpperCase() ==
        AppStrings.trainingGenerateSopConfirmation;
  }

  @override
  void dispose() {
    _confirmationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<TrainingModuleController>();
    final hasExistingSop = controller.hasSelectedModuleDocumentText;
    final errorMessage = controller.documentErrorMessage?.trim();
    final hasErrorMessage = errorMessage != null && errorMessage.isNotEmpty;

    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: _confirmationController,
      builder: (context, _, __) {
        final canGenerate =
            controller.canGenerateSopForSelectedModule &&
            (!hasExistingSop || _canRegenerate);
        return Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: AppColors.mainBg,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 38,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.92),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        const Expanded(
                          child: AppTextView.body1(
                            AppStrings.trainingGenerateWithAi,
                            color: AppColors.secondaryColor,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        _DialogCloseButton(
                          onTap: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        _DividerDot(),
                        Expanded(
                          child: Container(
                            height: 1,
                            color: AppColors.fieldBorder.withValues(
                              alpha: 0.24,
                            ),
                          ),
                        ),
                        _DividerDot(),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Container(
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.secondaryColor.withValues(alpha: 0.08),
                      ),
                      child: Center(
                        child: Icon(
                          Icons.auto_awesome_rounded,
                          size: 28,
                          color: AppColors.secondaryColor.withValues(
                            alpha: 0.96,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    AppTextView.body1(
                      hasExistingSop
                          ? AppStrings.trainingRegenerate
                          : AppStrings.trainingGenerateSop,
                      color: AppColors.hexd9deff,
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 10),
                    AppTextView.body(
                      hasExistingSop
                          ? AppStrings.trainingGenerateSopAlertDescription
                          : AppStrings.trainingGenerateSopSubtitle,
                      color: AppColors.lightPurple1,
                      fontSize: 13,
                      height: 1.45,
                      textAlign: TextAlign.center,
                    ),
                    if (hasExistingSop) ...[
                      const SizedBox(height: 18),
                      _SopAlertCard(
                        confirmationController: _confirmationController,
                      ),
                    ],
                    if (hasErrorMessage) ...[
                      const SizedBox(height: 16),
                      _DialogErrorMessageCard(message: errorMessage),
                    ],
                    const SizedBox(height: 22),
                    Row(
                      children: [
                        _DividerDot(),
                        Expanded(
                          child: Container(
                            height: 1,
                            color: AppColors.fieldBorder.withValues(
                              alpha: 0.24,
                            ),
                          ),
                        ),
                        _DividerDot(),
                      ],
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: TextButton.icon(
                        onPressed: canGenerate
                            ? () async {
                                if (showBillingRestrictionIfNeeded(context)) {
                                  return;
                                }
                                final didGenerate = await context
                                    .read<TrainingModuleController>()
                                    .generateSopForSelectedModule();
                                if (!context.mounted || !didGenerate) {
                                  return;
                                }

                                Navigator.of(context).pop(true);
                              }
                            : null,
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.textPrimary,
                          disabledForegroundColor: AppColors.textSecondary,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          backgroundColor: canGenerate
                              ? AppColors.secondaryColor
                              : AppColors.surfaceDark3,
                          disabledBackgroundColor: AppColors.surfaceDark3,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color: canGenerate
                                  ? AppColors.secondaryColor
                                  : AppColors.fieldBorder.withValues(
                                      alpha: 0.12,
                                    ),
                            ),
                          ),
                        ),
                        icon: controller.isGeneratingSop
                            ? FastCircularProgressIndicator(
                                width: 14,
                                height: 14,
                              )
                            : const Icon(
                                Icons.auto_awesome_rounded,
                                size: 16,
                                color: AppColors.textPrimary,
                              ),
                        label: AppTextView.body(
                          hasExistingSop
                              ? AppStrings.trainingRegenerate
                              : AppStrings.trainingGenerateWithAi,
                          fontSize: 14,
                          color: canGenerate
                              ? AppColors.textPrimary
                              : AppColors.textSecondary.withValues(alpha: 0.7),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
