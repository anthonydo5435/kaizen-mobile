part of 'package:sparrowkaizen/features/training/presentation/pages/edit_training_screen.dart';

class _QuizQuestionCard extends StatelessWidget {
  const _QuizQuestionCard({
    super.key,
    required this.number,
    required this.question,
    required this.canManageQuestions,
    required this.isSaving,
    required this.isDeleting,
    required this.onDeleteQuestionTap,
    required this.onEditQuestionTap,
  });

  final int number;
  final SeatDescriptionTrainingQuestion question;
  final bool canManageQuestions;
  final bool isSaving;
  final bool isDeleting;
  final Future<void> Function(SeatDescriptionTrainingQuestion question) onDeleteQuestionTap;
  final Future<void> Function(SeatDescriptionTrainingQuestion question) onEditQuestionTap;

  Future<void> _showQuestionActions(BuildContext context) async {
    if (!canManageQuestions || isSaving || isDeleting) return;

    FocusScope.of(context).unfocus();
    final action = await showModalBottomSheet<_QuizQuestionAction>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.56),
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => _QuizQuestionActionsSheet(
        onSelected: (action) => Navigator.of(sheetContext).pop(action),
        onClose: () => Navigator.of(sheetContext).pop(),
      ),
    );
    if (!context.mounted) return;

    switch (action) {
      case _QuizQuestionAction.edit:
        await onEditQuestionTap(question);
      case _QuizQuestionAction.delete:
        await onDeleteQuestionTap(question);
      case null:
        return;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 8, top: 6),
      decoration: BoxDecoration(
        color: AppColors.trainingLessonActionSurface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _QuizQuestionHeader(
            number: number,
            canManageQuestions: canManageQuestions,
            isBusy: isSaving || isDeleting,
            onActions: () => _showQuestionActions(context),
          ),
          const SizedBox(height: 6),
          _QuizQuestionPrompt(question: question),
          const SizedBox(height: 10),
          ...question.options.asMap().entries.map(
            (entry) => Padding(
              padding: EdgeInsets.only(bottom: entry.key == question.options.length - 1 ? 0 : 10),
              child: _QuizAnswerRow(
                text: entry.value.text,
                isSelected: question.selectedOptionUuid == entry.value.uuid,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuizQuestionPrompt extends StatelessWidget {
  const _QuizQuestionPrompt({required this.question});

  final SeatDescriptionTrainingQuestion question;

  @override
  Widget build(BuildContext context) {
    final imageUrl = CustomFunctions.resolveImageUrl(question.imageUrl);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppTextView.body1(
          question.question,
          color: AppColors.textPrimary,
          fontSize: 14,
          fontWeight: FontWeight.w600,
          height: 1.35,
        ),
        if (imageUrl != null) ...[
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: AspectRatio(
              aspectRatio: 2,
              child: CachedNetworkImage(
                imageUrl: imageUrl,
                width: double.infinity,
                fit: BoxFit.contain,
                placeholder: (_, _) => const Center(child: FastCircularProgressIndicator()),
                errorWidget: (_, _, _) => const ColoredBox(
                  color: AppColors.mainBg,
                  child: Center(
                    child: Icon(Icons.broken_image_outlined, color: AppColors.textSecondary),
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

enum _QuizQuestionAction { edit, delete }

class _QuizQuestionHeader extends StatelessWidget {
  const _QuizQuestionHeader({
    required this.number,
    required this.canManageQuestions,
    required this.isBusy,
    required this.onActions,
  });

  final int number;
  final bool canManageQuestions;
  final bool isBusy;
  final VoidCallback onActions;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.mainBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: AppTextView.body3(
                AppStrings.trainingQuestionBadge(number),
                color: AppColors.secondaryColor,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        if (canManageQuestions) ...[
          const SizedBox(width: 8),
          SizedBox(
            width: 40,
            height: 40,
            child: isBusy
                ? const Align(
                    alignment: Alignment.centerRight,
                    child: FastCircularProgressIndicator(width: 16, height: 16),
                  )
                : IconButton(
                    tooltip: AppStrings.trainingQuestionActions,
                    onPressed: onActions,
                    padding: EdgeInsets.zero,
                    alignment: Alignment.centerRight,
                    icon: const Icon(
                      Icons.more_vert_rounded,
                      size: 18,
                      color: AppColors.textPrimary,
                    ),
                  ),
          ),
        ],
      ],
    );
  }
}

class _QuizAnswerRow extends StatelessWidget {
  const _QuizAnswerRow({required this.text, required this.isSelected});

  final String text;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      checked: isSelected,
      inMutuallyExclusiveGroup: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isSelected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
            size: 18,
            color: isSelected ? AppColors.secondaryColor : AppColors.textPrimary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: AppTextView.body2(
              text,
              color: isSelected ? AppColors.secondaryColor : AppColors.textPrimary,
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w500 : FontWeight.w400,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
