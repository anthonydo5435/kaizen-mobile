part of 'package:sparrowkaizen/features/training/presentation/pages/edit_training_screen.dart';

class _QuizTabContent extends StatelessWidget {
  const _QuizTabContent({
    required this.isLoading,
    required this.questions,
    required this.canManageQuestions,
    required this.canManageGeneration,
    required this.canAddQuestion,
    required this.canGenerateQuiz,
    required this.isGeneratingQuiz,
    required this.isAddingQuestion,
    required this.savingQuestionId,
    required this.deletingQuestionId,
    required this.onAddQuestionTap,
    required this.onGenerateQuizTap,
    required this.onDeleteQuestionTap,
    required this.onEditQuestionTap,
  });

  final bool isLoading;
  final List<SeatDescriptionTrainingQuestion> questions;
  final bool canManageQuestions;
  final bool canManageGeneration;
  final bool canAddQuestion;
  final bool canGenerateQuiz;
  final bool isGeneratingQuiz;
  final bool isAddingQuestion;
  final String? savingQuestionId;
  final String? deletingQuestionId;
  final VoidCallback onAddQuestionTap;
  final VoidCallback onGenerateQuizTap;
  final Future<void> Function(SeatDescriptionTrainingQuestion question) onDeleteQuestionTap;
  final Future<void> Function(SeatDescriptionTrainingQuestion question) onEditQuestionTap;

  @override
  Widget build(BuildContext context) {
    if (isLoading && !canManageGeneration) {
      return const Center(child: FastCircularProgressIndicator());
    }
    if (questions.isEmpty && !canManageGeneration && !canManageQuestions) {
      return const _QuizEmptyState();
    }

    final creationHeader = _QuizCreationHeader(
      canGenerateQuiz: canGenerateQuiz && !isLoading,
      isGeneratingQuiz: isGeneratingQuiz,
      onGenerateQuizTap: onGenerateQuizTap,
    );
    if (isLoading) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          creationHeader,
          const SizedBox(height: 14),
          const Expanded(
            child: Center(child: FastCircularProgressIndicator()),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (canManageGeneration) ...[
          creationHeader,
          const SizedBox(height: 14),
        ],
        if (questions.isNotEmpty)
          ListView.separated(
            shrinkWrap: true,
            primary: false,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            itemCount: questions.length,
            findItemIndexCallback: (key) {
              final index = questions.indexWhere(
                (question) => ValueKey(question.uuid) == key,
              );
              return index < 0 ? null : index;
            },
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final question = questions[index];
              return _QuizQuestionCard(
                key: ValueKey(question.uuid),
                number: index + 1,
                question: question,
                canManageQuestions: canManageQuestions,
                isSaving: savingQuestionId == question.uuid,
                isDeleting: deletingQuestionId == question.uuid,
                onDeleteQuestionTap: onDeleteQuestionTap,
                onEditQuestionTap: onEditQuestionTap,
              );
            },
          )
        else if (!canManageQuestions)
          const Expanded(child: _QuizEmptyState()),
        if (canManageQuestions) ...[
          if (questions.isNotEmpty) const SizedBox(height: 12),
          _QuizAddQuestionButton(
            canAddQuestion: canAddQuestion,
            isAddingQuestion: isAddingQuestion,
            onAddQuestionTap: onAddQuestionTap,
          ),
        ],
      ],
    );
  }
}

class _QuizCreationHeader extends StatelessWidget {
  const _QuizCreationHeader({
    required this.canGenerateQuiz,
    required this.isGeneratingQuiz,
    required this.onGenerateQuizTap,
  });

  final bool canGenerateQuiz;
  final bool isGeneratingQuiz;
  final VoidCallback onGenerateQuizTap;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: [
        const AppTextView.body1(
          AppStrings.trainingCreateQuiz,
          color: AppColors.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
        _TrainingCreateWithAiButton(
          isEnabled: canGenerateQuiz,
          isLoading: isGeneratingQuiz,
          onTap: onGenerateQuizTap,
        ),
      ],
    );
  }
}

class _QuizAddQuestionButton extends StatelessWidget {
  const _QuizAddQuestionButton({
    required this.canAddQuestion,
    required this.isAddingQuestion,
    required this.onAddQuestionTap,
  });

  final bool canAddQuestion;
  final bool isAddingQuestion;
  final VoidCallback onAddQuestionTap;

  @override
  Widget build(BuildContext context) {
    return _SecondaryTrainingActionButton(
      label: AppStrings.trainingAddNewQuestion,
      icon: Icons.add_circle_outline_rounded,
      isEnabled: canAddQuestion,
      isLoading: isAddingQuestion,
      isDottedBorder: true,
      borderStrokeWidth: 0.6,
      borderDashLength: 1.5,
      borderGapLength: 1,
      mainAxisAlignment: MainAxisAlignment.center,
      fontWeight: FontWeight.w400,
      fontSize: 12,
      iconSize: 14,
      horizontalPadding: 12,
      verticalPadding: 13,
      borderRadius: 12,
      backgroundColor: Colors.transparent,
      activeBorderColor: AppColors.secondaryColor,
      activeTextColor: AppColors.lightPurple1,
      activeIconColor: AppColors.lightPurple1,
      onTap: guardPaidAction(context, canAddQuestion ? onAddQuestionTap : null),
    );
  }
}
