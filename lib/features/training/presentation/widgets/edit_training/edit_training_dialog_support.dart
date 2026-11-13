part of 'package:sparrowkaizen/features/training/presentation/pages/edit_training_screen.dart';

class _DialogCloseButton extends StatelessWidget {
  const _DialogCloseButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppOverlayCloseButton(onTap: onTap);
  }
}

class _DialogErrorMessageCard extends StatelessWidget {
  const _DialogErrorMessageCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.red.withValues(alpha: 0.22)),
      ),
      child: AppTextView.body3(
        message,
        color: AppColors.textPrimary,
        height: 1.45,
      ),
    );
  }
}

class _QuizGenerationStepper extends StatelessWidget {
  const _QuizGenerationStepper({
    required this.label,
    required this.value,
    required this.onIncrement,
    required this.onDecrement,
    required this.canIncrement,
    required this.canDecrement,
  });

  final String label;
  final int value;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final bool canIncrement;
  final bool canDecrement;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.trainingLessonActionSurface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: AppTextView.body2(
              label,
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 8),
          _StepperActionButton(
            icon: Icons.remove_circle_outline_rounded,
            tooltip: AppStrings.trainingQuizDecreaseSetting(label),
            onTap: canDecrement ? onDecrement : null,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: AppTextView.body1(
              '$value',
              fontSize: 20,
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
              textAlign: TextAlign.center,
            ),
          ),
          _StepperActionButton(
            icon: Icons.add_circle_outline_rounded,
            tooltip: AppStrings.trainingQuizIncreaseSetting(label),
            onTap: canIncrement ? onIncrement : null,
          ),
        ],
      ),
    );
  }
}

class _StepperActionButton extends StatelessWidget {
  const _StepperActionButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onTap,
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      padding: const EdgeInsets.all(6),
      color: AppColors.secondaryColor,
      disabledColor: AppColors.secondaryColor.withValues(alpha: 0.4),
      icon: Icon(icon, size: 20),
    );
  }
}

class _QuizDifficultyChip extends StatelessWidget {
  const _QuizDifficultyChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: isSelected,
      child: TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(
          backgroundColor: isSelected
              ? AppColors.secondaryColor
              : Colors.transparent,
          disabledBackgroundColor: isSelected
              ? AppColors.secondaryColor.withValues(alpha: 0.55)
              : Colors.transparent,
          foregroundColor: isSelected ? AppColors.textPrimary : AppColors.grey1,
          disabledForegroundColor: AppColors.grey1,
          minimumSize: const Size(0, 32),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
            side: BorderSide(
              color: isSelected
                  ? AppColors.secondaryColor
                  : AppColors.grey1.withValues(alpha: 0.45),
            ),
          ),
        ),
        child: AppTextView.body2(
          label,
          fontSize: 14,
          fontWeight: FontWeight.w500,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

class _DividerDot extends StatelessWidget {
  const _DividerDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 10,
      margin: const EdgeInsets.symmetric(horizontal: 2),
      decoration: const BoxDecoration(
        color: AppColors.hex51597a,
        shape: BoxShape.circle,
      ),
    );
  }
}

class _SopAlertCard extends StatelessWidget {
  const _SopAlertCard({required this.confirmationController});

  final TextEditingController confirmationController;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.red.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.red.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.red.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.warning_amber_rounded,
                  color: AppColors.textPrimary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: AppTextView.body1(
                  AppStrings.trainingGenerateSopAlertTitle,
                  color: AppColors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const AppTextView.body(
            AppStrings.trainingGenerateSopAlertInstruction,
            color: AppColors.textPrimary,
            fontSize: 12,
            fontWeight: FontWeight.w500,
            height: 1.45,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: confirmationController,
            textCapitalization: TextCapitalization.characters,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.1,
            ),
            decoration: InputDecoration(
              hintText: AppStrings.trainingGenerateSopConfirmation,
              hintStyle: TextStyle(
                color: AppColors.textSecondary.withValues(alpha: 0.72),
                fontSize: 14,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.1,
              ),
              filled: true,
              fillColor: AppColors.surfaceDark2,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: Colors.white.withValues(alpha: 0.08),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppColors.red),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
