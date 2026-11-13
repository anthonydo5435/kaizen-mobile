part of 'package:sparrowkaizen/features/training/presentation/pages/edit_training_screen.dart';

class _DeleteModuleDialog extends StatelessWidget {
  const _DeleteModuleDialog({required this.module});

  final SeatDescriptionTrainingModule module;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<TrainingModuleController>();

    return AppConfirmationDialog(
      title: AppStrings.trainingDeleteModuleTitle,
      description: AppStrings.trainingDeleteModuleDescription(module.title),
      confirmText: AppStrings.trainingDeleteModuleAction,
      cancelText: AppStrings.trainingCancel,
      isConfirmLoading: controller.isDeletingModule(module.uuid),
      onCancelCallback: () async {
        if (context.mounted) {
          Navigator.of(context).pop();
        }
      },
      onConfirmCallback: () async {
        final didDelete = await context
            .read<TrainingModuleController>()
            .deleteModule(module.uuid);
        if (!context.mounted) {
          return;
        }

        Navigator.of(context).pop(didDelete);
      },
    );
  }
}

class _ReUploadTrainingVideoDialog extends StatelessWidget {
  const _ReUploadTrainingVideoDialog({required this.moduleTitle});

  final String moduleTitle;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<TrainingModuleController>();

    return AppConfirmationDialog(
      title: AppStrings.trainingReUploadVideoAction,
      description: AppStrings.trainingReUploadVideoDescription(moduleTitle),
      confirmText: AppStrings.trainingDeleteAndContinueAction,
      cancelText: AppStrings.trainingCancel,
      isConfirmLoading: controller.isDeletingVideo,
      onCancelCallback: () async {
        if (context.mounted) {
          Navigator.of(context).pop();
        }
      },
      onConfirmCallback: () async {
        final didDelete = await context
            .read<TrainingModuleController>()
            .deleteVideoForSelectedModule();
        if (!context.mounted) {
          return;
        }

        Navigator.of(context).pop(didDelete);
      },
    );
  }
}

class _DeleteQuestionDialog extends StatelessWidget {
  const _DeleteQuestionDialog({required this.question});

  final SeatDescriptionTrainingQuestion question;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<TrainingModuleController>();

    return AppConfirmationDialog(
      title: AppStrings.trainingDeleteQuestionTitle,
      description: AppStrings.trainingDeleteQuestionDescription,
      confirmText: AppStrings.trainingDeleteQuestionAction,
      cancelText: AppStrings.trainingCancel,
      isConfirmLoading: controller.isDeletingQuestion(question.uuid),
      onCancelCallback: () async {
        if (context.mounted) {
          Navigator.of(context).pop();
        }
      },
      onConfirmCallback: () async {
        final didDelete = await context
            .read<TrainingModuleController>()
            .deleteQuestion(questionId: question.uuid);
        if (!context.mounted) {
          return;
        }

        Navigator.of(context).pop(didDelete);
      },
    );
  }
}

class _TrainingThumbnailPickerDialog extends StatelessWidget {
  const _TrainingThumbnailPickerDialog({
    required this.onSelectThumbnailTap,
    required this.onSkipTap,
  });

  final Future<void> Function() onSelectThumbnailTap;
  final VoidCallback onSkipTap;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<TrainingModuleController>();

    return AlertDialog(
      backgroundColor: AppColors.surfaceDark,
      shape: AppDialogStyle.shape(radius: 18),
      title: const AppTextView.body1(
        AppStrings.trainingAddThumbnailTitle,
        color: AppColors.textPrimary,
        fontWeight: FontWeight.w700,
        textAlign: TextAlign.center,
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const AppTextView.body(
            AppStrings.trainingAddThumbnailDescription,
            color: AppColors.textPrimary,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 18),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: controller.isUploadingThumbnail
                  ? null
                  : onSelectThumbnailTap,
              borderRadius: BorderRadius.circular(14),
              child: Ink(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 20,
                ),
                decoration: BoxDecoration(
                  color: AppColors.mainBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: AppColors.secondaryColor.withValues(alpha: 0.28),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        color: AppColors.secondaryColor.withValues(alpha: 0.18),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: controller.isUploadingThumbnail
                            ? FastCircularProgressIndicator(
                                width: 18,
                                height: 18,
                              )
                            : const Icon(
                                Icons.add_photo_alternate_outlined,
                                color: AppColors.textPrimary,
                                size: 28,
                              ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const AppTextView.body2(
                      AppStrings.trainingSelectThumbnailAction,
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    const AppTextView.body4(
                      AppStrings.trainingSelectThumbnailHint,
                      color: AppColors.textSecondary,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        TextButton(
          onPressed: controller.isUploadingThumbnail ? null : onSkipTap,
          child: const AppTextView.body(
            AppStrings.trainingSkipThumbnailAction,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _ModuleThumbnailPlaceholder extends StatelessWidget {
  const _ModuleThumbnailPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      '${AppStrings.imagePath}fallback.png',
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) {
        return Container(
          color: AppColors.mainBg,
          alignment: Alignment.center,
          child: const Icon(
            Icons.play_circle_outline_rounded,
            color: AppColors.textSecondary,
            size: 24,
          ),
        );
      },
    );
  }
}
