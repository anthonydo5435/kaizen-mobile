part of 'package:sparrowkaizen/features/training/presentation/pages/edit_training_screen.dart';

/// Uses the same player and summary layout without exposing media or editing actions.
class TrainingReadOnlyVideoTab extends StatelessWidget {
  const TrainingReadOnlyVideoTab({
    super.key,
    required this.controller,
    this.contentHorizontalPadding = 0,
  });

  final TrainingModuleController controller;
  final double contentHorizontalPadding;

  @override
  Widget build(BuildContext context) {
    return _VideoTabContent(
      detail: controller.selectedModuleDetail,
      localVideoPath: controller.selectedModuleLocalVideoPath,
      isReadOnly: true,
      isUploadEnabled: false,
      isPickingVideo: false,
      isFinalizingVideoSetup: false,
      isUploadingVideo: false,
      isDeletingVideo: false,
      isUploadingThumbnail: false,
      canEditSummary: false,
      isEditingSummary: false,
      isSavingSummary: false,
      summaryController: controller.summaryController,
      contentHorizontalPadding: contentHorizontalPadding,
    );
  }
}

/// Displays the editor's compact question cards with no management actions.
class TrainingReadOnlyQuizTab extends StatelessWidget {
  const TrainingReadOnlyQuizTab({super.key, required this.controller});

  final TrainingModuleController controller;

  @override
  Widget build(BuildContext context) {
    return _QuizTabContent(
      isLoading: controller.isQuestionsLoading,
      questions: controller.selectedModuleQuestions,
      canManageQuestions: false,
      canAddQuestion: false,
      canGenerateQuiz: false,
      isGeneratingQuiz: false,
      isAddingQuestion: false,
      savingQuestionId: null,
      deletingQuestionId: null,
      onAddQuestionTap: () {},
      onGenerateQuizTap: () {},
      onDeleteQuestionTap: (_) async {},
      onEditQuestionTap: (_) async {},
    );
  }
}
