part of 'package:sparrowkaizen/features/training/presentation/pages/edit_training_screen.dart';

class _DraftQuizOptionTile extends StatelessWidget {
  const _DraftQuizOptionTile({
    required this.controller,
    required this.hintText,
    required this.isSelected,
    required this.isEditable,
    this.onSelect,
  });

  final TextEditingController controller;
  final String hintText;
  final bool isSelected;
  final VoidCallback? onSelect;
  final bool isEditable;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.025),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.fieldBorder.withValues(alpha: 0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          InkWell(
            onTap: onSelect,
            borderRadius: BorderRadius.circular(999),
            child: Padding(
              padding: const EdgeInsets.only(right: 10, top: 2, bottom: 2),
              child: Icon(
                isSelected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                color: isSelected ? AppColors.secondaryColor : AppColors.textSecondary,
                size: 18,
              ),
            ),
          ),
          Expanded(
            child: TextField(
              controller: controller,
              enabled: isEditable,
              autofocus: true,
              keyboardType: TextInputType.multiline,
              minLines: 1,
              maxLines: null,
              textCapitalization: TextCapitalization.sentences,
              cursorColor: Colors.white,
              cursorHeight: 15,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              decoration: InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                hintText: hintText,
                hintStyle: TextStyle(
                  color: AppColors.textSecondary.withValues(alpha: 0.72),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuestionCorrectAnswerSelector extends StatelessWidget {
  const _QuestionCorrectAnswerSelector({
    required this.label,
    required this.onPrevious,
    required this.onNext,
  });

  final String label;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AppTextView.body2(
          AppStrings.trainingQuestionCorrectAnswerLabel,
          color: AppColors.grey1,
          fontWeight: FontWeight.w400,
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surfaceDark3,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                tooltip: AppStrings.trainingQuestionPreviousAnswer,
                onPressed: onPrevious,
                color: AppColors.secondaryColor,
                disabledColor: AppColors.grey1,
                icon: const Icon(Icons.chevron_left_rounded, size: 22),
              ),
              SizedBox(
                width: 44,
                child: AppTextView.body1(
                  label,
                  color: AppColors.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  textAlign: TextAlign.center,
                ),
              ),
              IconButton(
                tooltip: AppStrings.trainingQuestionNextAnswer,
                onPressed: onNext,
                color: AppColors.secondaryColor,
                disabledColor: AppColors.grey1,
                icon: const Icon(Icons.chevron_right_rounded, size: 22),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _QuizOptionTile extends StatelessWidget {
  const _QuizOptionTile({
    required this.controller,
    required this.hintText,
    required this.isSelected,
    required this.isEditable,
    this.onTap,
  });

  final TextEditingController controller;
  final String hintText;
  final bool isSelected;
  final bool isEditable;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: isSelected
            ? AppColors.secondaryColor.withValues(alpha: 0.09)
            : Colors.white.withValues(alpha: 0.025),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected
              ? AppColors.secondaryColor.withValues(alpha: 0.58)
              : AppColors.fieldBorder.withValues(alpha: 0.18),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(999),
            child: Padding(
              padding: const EdgeInsets.only(top: 2, right: 10, bottom: 2),
              child: Icon(
                isSelected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                color: isSelected ? AppColors.secondaryColor : AppColors.textSecondary,
                size: 18,
              ),
            ),
          ),
          Expanded(
            child: TextField(
              controller: controller,
              enabled: isEditable,
              keyboardType: TextInputType.multiline,
              minLines: 1,
              maxLines: null,
              textCapitalization: TextCapitalization.sentences,
              cursorColor: Colors.white,
              cursorHeight: 15,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                height: 1.45,
              ),
              decoration: InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                hintText: hintText,
                hintStyle: TextStyle(
                  color: AppColors.textSecondary.withValues(alpha: 0.72),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuizEmptyState extends StatelessWidget {
  const _QuizEmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 24),
        child: AppTextView.body3(
          AppStrings.trainingNoQuizQuestionsAvailable,
          color: AppColors.textSecondary,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

class _ContentMessage extends StatelessWidget {
  const _ContentMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark2.withValues(alpha: 0.38),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.fieldBorder.withValues(alpha: 0.16)),
      ),
      child: AppTextView.body3(
        message,
        color: AppColors.textSecondary,
        textAlign: TextAlign.center,
      ),
    );
  }
}

class _DottedRoundedBorderPainter extends CustomPainter {
  const _DottedRoundedBorderPainter({
    required this.color,
    required this.radius,
    this.strokeWidth = 1.2,
    this.dashLength = 6,
    this.gapLength = 4,
  }) : assert(strokeWidth > 0),
       assert(dashLength > 0),
       assert(gapLength >= 0);

  final Color color;
  final double radius;
  final double strokeWidth;
  final double dashLength;
  final double gapLength;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius)));

    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final nextDistance = distance + dashLength;
        canvas.drawPath(metric.extractPath(distance, nextDistance), paint);
        distance = nextDistance + gapLength;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DottedRoundedBorderPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.radius != radius ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.dashLength != dashLength ||
        oldDelegate.gapLength != gapLength;
  }
}
