part of 'package:sparrowkaizen/features/training/presentation/pages/edit_training_screen.dart';

class _GenerateAssignmentDialog extends StatefulWidget {
  const _GenerateAssignmentDialog();

  @override
  State<_GenerateAssignmentDialog> createState() =>
      _GenerateAssignmentDialogState();
}

class _GenerateAssignmentDialogState extends State<_GenerateAssignmentDialog> {
  final TextEditingController _confirmationController = TextEditingController();

  bool get _canRegenerate =>
      _confirmationController.text.trim().toUpperCase() ==
      AppStrings.trainingGenerateSopConfirmation;

  @override
  void dispose() {
    _confirmationController.dispose();
    super.dispose();
  }

  Future<void> _generate(BuildContext context) async {
    final generated = await context
        .read<TrainingModuleController>()
        .generateAssignmentForSelectedModule();
    if (context.mounted && generated) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<TrainingModuleController>();
    final mediaQuery = MediaQuery.of(context);
    final hasExistingAssignment = controller.hasSelectedModuleAssignmentContent;
    final errorMessage = controller.assignmentErrorMessage?.trim();

    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: _confirmationController,
      builder: (context, _, __) {
        final canGenerate =
            controller.canGenerateAssignmentForSelectedModule &&
            (!hasExistingAssignment || _canRegenerate);
        final availableHeight =
            mediaQuery.size.height -
            mediaQuery.viewInsets.bottom -
            mediaQuery.padding.top -
            16;

        return Padding(
          padding: EdgeInsets.only(bottom: mediaQuery.viewInsets.bottom),
          child: AppKeyboardBottomSheetSurface(
            width: double.infinity,
            color: AppColors.mainBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: 620,
                maxHeight: availableHeight.clamp(
                  0.0,
                  mediaQuery.size.height * 0.92,
                ),
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _GenerateAssignmentHeader(
                      onClose: () => Navigator.of(context).pop(),
                    ),
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(18, 24, 18, 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Center(
                              child: Container(
                                width: 76,
                                height: 76,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppColors.secondaryColor.withValues(
                                    alpha: 0.08,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.auto_awesome_rounded,
                                  size: 28,
                                  color: AppColors.secondaryColor,
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            AppTextView.body1(
                              hasExistingAssignment
                                  ? AppStrings.trainingRegenerate
                                  : AppStrings.trainingGenerateAssignment,
                              color: AppColors.hexd9deff,
                              fontSize: 19,
                              fontWeight: FontWeight.w700,
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 10),
                            const AppTextView.body(
                              AppStrings
                                  .trainingGenerateAssignmentDialogDescription,
                              color: AppColors.lightPurple1,
                              fontSize: 13,
                              height: 1.45,
                              textAlign: TextAlign.center,
                            ),
                            if (hasExistingAssignment) ...[
                              const SizedBox(height: 18),
                              const AppTextView.body(
                                AppStrings
                                    .trainingGenerateAssignmentAlertDescription,
                                color: AppColors.textPrimary,
                                fontSize: 13,
                                height: 1.45,
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 12),
                              _SopAlertCard(
                                confirmationController: _confirmationController,
                              ),
                            ],
                            if (errorMessage != null &&
                                errorMessage.isNotEmpty) ...[
                              const SizedBox(height: 16),
                              _DialogErrorMessageCard(message: errorMessage),
                            ],
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
                      child: AppAiGenerateButton(
                        label: hasExistingAssignment
                            ? AppStrings.trainingRegenerate
                            : AppStrings.trainingGenerateAssignment,
                        isEnabled: canGenerate,
                        isLoading: controller.isGeneratingAssignment,
                        onTap: canGenerate
                            ? () => unawaited(_generate(context))
                            : null,
                        expand: true,
                        minHeight: 40,
                        showOutline: true,
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

class _GenerateAssignmentHeader extends StatelessWidget {
  const _GenerateAssignmentHeader({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
      child: Column(
        children: [
          Container(
            width: 32,
            height: 3,
            decoration: BoxDecoration(
              color: AppColors.textPrimary,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              const SizedBox(width: 28),
              const Expanded(
                child: AppTextView.body1(
                  AppStrings.trainingGenerateAssignmentDialogTitle,
                  color: AppColors.secondaryColor,
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  textAlign: TextAlign.center,
                ),
              ),
              Tooltip(
                message: MaterialLocalizations.of(context).closeButtonTooltip,
                child: AppOverlayCloseButton(onTap: onClose),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const AppDotDivider(dotSize: 5),
        ],
      ),
    );
  }
}
