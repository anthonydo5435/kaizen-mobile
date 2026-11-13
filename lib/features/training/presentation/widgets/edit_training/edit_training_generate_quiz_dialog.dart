part of 'package:sparrowkaizen/features/training/presentation/pages/edit_training_screen.dart';

class _GenerateQuizDialog extends StatelessWidget {
  const _GenerateQuizDialog();

  Future<void> _generate(BuildContext context) async {
    final generated = await context
        .read<TrainingModuleController>()
        .generateQuizForSelectedModule();
    if (context.mounted && generated) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<TrainingModuleController>();
    final mediaQuery = MediaQuery.of(context);
    final availableHeight =
        mediaQuery.size.height - mediaQuery.viewInsets.bottom - mediaQuery.padding.top - 16;

    return Padding(
      padding: EdgeInsets.only(bottom: mediaQuery.viewInsets.bottom),
      child: Container(
        width: double.infinity,
        constraints: BoxConstraints(
          maxWidth: 620,
          maxHeight: availableHeight.clamp(0.0, mediaQuery.size.height * 0.92),
        ),
        decoration: const BoxDecoration(
          color: AppColors.mainBg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _GenerateQuizHeader(onClose: () => Navigator.of(context).pop()),
              Flexible(child: _GenerateQuizContent(controller: controller)),
              _GenerateQuizFooter(
                isEnabled: controller.canGenerateQuizForSelectedModule,
                isGenerating: controller.isGeneratingQuiz,
                onGenerate: () => _generate(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GenerateQuizHeader extends StatelessWidget {
  const _GenerateQuizHeader({required this.onClose});

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
                  AppStrings.trainingGenerateQuizDialogTitle,
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

class _GenerateQuizContent extends StatelessWidget {
  const _GenerateQuizContent({required this.controller});

  final TrainingModuleController controller;

  @override
  Widget build(BuildContext context) {
    final error = controller.questionsErrorMessage?.trim();
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 24, 18, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AppTextView.body1(
            AppStrings.trainingGenerateQuiz,
            color: AppColors.hexd9deff,
            fontSize: 20,
            fontWeight: FontWeight.w600,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const AppTextView.body2(
            AppStrings.trainingGenerateQuizDialogDescription,
            color: AppColors.lightPurple1,
            fontSize: 14,
            height: 1.45,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          _QuizGenerationSettings(controller: controller),
          if (error != null && error.isNotEmpty) ...[
            const SizedBox(height: 12),
            _DialogErrorMessageCard(message: error),
          ],
          const SizedBox(height: 12),
          _QuizReplaceToggle(
            value: controller.replaceExistingQuestions,
            onChanged: controller.canGenerateQuizForSelectedModule
                ? controller.setReplaceExistingQuestions
                : null,
          ),
        ],
      ),
    );
  }
}

class _QuizGenerationSettings extends StatelessWidget {
  const _QuizGenerationSettings({required this.controller});

  final TrainingModuleController controller;

  @override
  Widget build(BuildContext context) {
    final isEnabled = controller.canGenerateQuizForSelectedModule;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _QuizGenerationStepper(
          label: AppStrings.trainingQuizNumberOfQuestions,
          value: controller.quizGenerationQuestionCount,
          onIncrement: controller.incrementQuizQuestionCount,
          onDecrement: controller.decrementQuizQuestionCount,
          canIncrement:
              isEnabled &&
              controller.quizGenerationQuestionCount <
                  TrainingModuleController.maxQuizQuestionCount,
          canDecrement:
              isEnabled &&
              controller.quizGenerationQuestionCount >
                  TrainingModuleController.minQuizQuestionCount,
        ),
        const SizedBox(height: 12),
        _QuizGenerationStepper(
          label: AppStrings.trainingQuizOptionsPerQuestion,
          value: controller.quizGenerationOptionsPerQuestion,
          onIncrement: controller.incrementQuizOptionsPerQuestion,
          onDecrement: controller.decrementQuizOptionsPerQuestion,
          canIncrement:
              isEnabled &&
              controller.quizGenerationOptionsPerQuestion <
                  TrainingModuleController.maxQuizOptionsPerQuestion,
          canDecrement:
              isEnabled &&
              controller.quizGenerationOptionsPerQuestion >
                  TrainingModuleController.minQuizOptionsPerQuestion,
        ),
        const SizedBox(height: 12),
        _QuizDifficultySetting(controller: controller, isEnabled: isEnabled),
        const SizedBox(height: 12),
        _QuizSourceSetting(controller: controller, isEnabled: isEnabled),
      ],
    );
  }
}

class _QuizDifficultySetting extends StatelessWidget {
  const _QuizDifficultySetting({required this.controller, required this.isEnabled});

  final TrainingModuleController controller;
  final bool isEnabled;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.trainingLessonActionSurface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AppTextView.body2(
            AppStrings.trainingQuizDifficultyLevel,
            color: AppColors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w400,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _QuizDifficultyChip(
                  label: AppStrings.trainingQuizDifficultyEasy,
                  isSelected: controller.quizGenerationDifficulty == QuizGenerationDifficulty.easy,
                  onTap: isEnabled
                      ? () => controller.setQuizGenerationDifficulty(QuizGenerationDifficulty.easy)
                      : null,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _QuizDifficultyChip(
                  label: AppStrings.trainingQuizDifficultyMedium,
                  isSelected:
                      controller.quizGenerationDifficulty == QuizGenerationDifficulty.medium,
                  onTap: isEnabled
                      ? () =>
                            controller.setQuizGenerationDifficulty(QuizGenerationDifficulty.medium)
                      : null,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _QuizDifficultyChip(
                  label: AppStrings.trainingQuizDifficultyHard,
                  isSelected: controller.quizGenerationDifficulty == QuizGenerationDifficulty.hard,
                  onTap: isEnabled
                      ? () => controller.setQuizGenerationDifficulty(QuizGenerationDifficulty.hard)
                      : null,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuizSourceSetting extends StatelessWidget {
  const _QuizSourceSetting({required this.controller, required this.isEnabled});

  final TrainingModuleController controller;
  final bool isEnabled;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.trainingLessonActionSurface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AppTextView.body2(
            AppStrings.trainingQuizGenerateFrom,
            color: AppColors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w400,
          ),
          const SizedBox(height: 12),
          Row(
            spacing: 8,
            children: QuizGenerationSource.values
                .map((source) {
                  final label = switch (source) {
                    QuizGenerationSource.video => AppStrings.trainingVideoTab,
                    QuizGenerationSource.sop => AppStrings.trainingSopTab,
                    QuizGenerationSource.both => AppStrings.trainingQuizSourceBoth,
                  };
                  return Expanded(
                    child: _QuizDifficultyChip(
                      label: label,
                      isSelected: controller.quizGenerationSource == source,
                      onTap: isEnabled ? () => controller.setQuizGenerationSource(source) : null,
                    ),
                  );
                })
                .toList(growable: false),
          ),
        ],
      ),
    );
  }
}

class _QuizReplaceToggle extends StatelessWidget {
  const _QuizReplaceToggle({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.trainingLessonActionSurface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Expanded(
            child: AppTextView.body2(
              AppStrings.trainingQuizReplaceExistingQuestions,
              color: AppColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(width: 8),
          AppTextView.body3(
            value ? AppStrings.trainingQuizEnabled : AppStrings.trainingQuizDisabled,
            color: value ? AppColors.secondaryColor : AppColors.textSecondary,
            fontSize: 14,
          ),
          const SizedBox(width: 4),
          Switch.adaptive(
            value: value,
            activeThumbColor: AppColors.secondaryColor,
            activeTrackColor: AppColors.secondaryColor.withValues(alpha: 0.4),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _GenerateQuizFooter extends StatelessWidget {
  const _GenerateQuizFooter({
    required this.isEnabled,
    required this.isGenerating,
    required this.onGenerate,
  });

  final bool isEnabled;
  final bool isGenerating;
  final VoidCallback onGenerate;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AppDotDivider(dotSize: 5),
          const SizedBox(height: 18),
          TextButton.icon(
            onPressed: isEnabled && !isGenerating ? onGenerate : null,
            style: TextButton.styleFrom(
              backgroundColor: AppColors.secondaryColor,
              disabledBackgroundColor: AppColors.secondaryColor.withValues(alpha: 0.55),
              foregroundColor: AppColors.textPrimary,
              disabledForegroundColor: AppColors.textPrimary,
              minimumSize: const Size.fromHeight(44),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: isGenerating
                ? const FastCircularProgressIndicator(width: 16, height: 16)
                : const Icon(Icons.auto_awesome_rounded, size: 18),
            label: const AppTextView.body2(
              AppStrings.trainingQuizGenerateWithAi,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              textAlign: TextAlign.center,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
