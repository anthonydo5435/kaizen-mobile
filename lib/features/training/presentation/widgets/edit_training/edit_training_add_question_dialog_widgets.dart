part of 'package:sparrowkaizen/features/training/presentation/pages/edit_training_screen.dart';

class _QuestionTextField extends StatelessWidget {
  const _QuestionTextField({required this.controller, required this.isEnabled});

  final TextEditingController controller;
  final bool isEnabled;

  @override
  Widget build(BuildContext context) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: AppColors.grey1),
    );
    return TextField(
      controller: controller,
      readOnly: !isEnabled,
      minLines: 1,
      maxLines: 4,
      textCapitalization: TextCapitalization.sentences,
      cursorColor: AppColors.textPrimary,
      cursorHeight: 15,
      style: const TextStyle(color: AppColors.textPrimary, fontSize: 16),
      decoration: InputDecoration(
        hintText: AppStrings.trainingNewQuestionHint,
        hintStyle: const TextStyle(color: AppColors.textPrimary, fontSize: 16),
        filled: true,
        fillColor: AppColors.mainBg,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: border,
        enabledBorder: border,
        focusedBorder: border.copyWith(
          borderSide: const BorderSide(color: AppColors.secondaryColor),
        ),
      ),
    );
  }
}

class _QuestionPictureField extends StatelessWidget {
  const _QuestionPictureField({
    required this.image,
    required this.isPicking,
    required this.onPick,
    required this.onRemove,
  });

  final File? image;
  final bool isPicking;
  final VoidCallback? onPick;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: image == null
          ? AppStrings.trainingQuestionUploadPicture
          : AppStrings.trainingQuestionReplacePicture,
      child: Material(
        color: AppColors.mainBg,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: CustomPaint(
          foregroundPainter: const _DottedRoundedBorderPainter(
            color: AppColors.grey1,
            radius: 14,
            strokeWidth: 1,
            dashLength: 2,
            gapLength: 2,
          ),
          child: InkWell(
            onTap: onPick,
            child: image == null
                ? _QuestionPicturePlaceholder(isPicking: isPicking)
                : _QuestionPicturePreview(
                    image: image!,
                    isPicking: isPicking,
                    onRemove: onRemove,
                  ),
          ),
        ),
      ),
    );
  }
}

class _QuestionPicturePlaceholder extends StatelessWidget {
  const _QuestionPicturePlaceholder({required this.isPicking});

  final bool isPicking;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              color: AppColors.secondaryColor,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: isPicking
                ? const FastCircularProgressIndicator()
                : SvgPicture.asset(
                    AppAssets.upload,
                    width: 18,
                    height: 18,
                    excludeFromSemantics: true,
                    colorFilter: const ColorFilter.mode(
                      AppColors.textPrimary,
                      BlendMode.srcIn,
                    ),
                  ),
          ),
          const SizedBox(height: 10),
          const AppTextView.body(
            AppStrings.trainingQuestionUploadPicture,
            color: AppColors.textPrimary,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          const AppTextView.body2(
            AppStrings.trainingQuestionPictureHint,
            color: AppColors.grey1,
            fontWeight: FontWeight.w400,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _QuestionPicturePreview extends StatelessWidget {
  const _QuestionPicturePreview({
    required this.image,
    required this.isPicking,
    required this.onRemove,
  });

  final File image;
  final bool isPicking;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 140,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.file(
            image,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => const Center(
              child: AppTextView.body3(
                AppStrings.pickImageError,
                color: AppColors.textPrimary,
                textAlign: TextAlign.center,
              ),
            ),
          ),
          if (isPicking) const Center(child: FastCircularProgressIndicator()),
          Positioned(
            top: 4,
            right: 4,
            child: IconButton(
              tooltip: AppStrings.trainingQuestionRemovePicture,
              onPressed: onRemove,
              style: IconButton.styleFrom(
                backgroundColor: AppColors.mainBg,
                foregroundColor: AppColors.textPrimary,
              ),
              icon: const Icon(Icons.close_rounded, size: 18),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuestionOptionsList extends StatelessWidget {
  const _QuestionOptionsList({
    required this.form,
    required this.isEnabled,
    required this.onRemove,
  });

  final TrainingQuestionFormController form;
  final bool isEnabled;
  final ValueChanged<TextEditingController> onRemove;

  @override
  Widget build(BuildContext context) {
    final options = form.optionControllers;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AppTextView.body2(
          AppStrings.trainingQuestionOptionsPrompt,
          color: AppColors.grey1,
          fontWeight: FontWeight.w400,
        ),
        const SizedBox(height: 12),
        ...options.asMap().entries.map(
          (entry) => Padding(
            key: ObjectKey(entry.value),
            padding: const EdgeInsets.only(bottom: 10),
            child: TrainingSwipeDeleteAction(
              deleteSemanticLabel: AppStrings.trainingDeleteOption,
              onDelete: isEnabled ? () => onRemove(entry.value) : null,
              child: _QuestionOptionRow(
                controller: entry.value,
                label: AppStrings.trainingQuestionOptionLetter(entry.key),
                hintText: AppStrings.trainingQuestionOptionHint(entry.key + 1),
                isEnabled: isEnabled,
              ),
            ),
          ),
        ),
        _SecondaryTrainingActionButton(
          label: AppStrings.trainingQuestionAddOption,
          onTap: guardPaidAction(
            context,
            isEnabled && form.canAddOption ? form.addOptionField : null,
          ),
          isEnabled: isEnabled && form.canAddOption,
          isDottedBorder: true,
          borderStrokeWidth: 1,
          borderDashLength: 2,
          borderGapLength: 2,
          mainAxisAlignment: MainAxisAlignment.center,
          fontWeight: FontWeight.w400,
          verticalPadding: 10,
          borderRadius: 14,
          backgroundColor: AppColors.mainBg,
          activeBorderColor: AppColors.grey1,
          activeTextColor: AppColors.textPrimary,
        ),
      ],
    );
  }
}

class _QuestionOptionRow extends StatelessWidget {
  const _QuestionOptionRow({
    required this.controller,
    required this.label,
    required this.hintText,
    required this.isEnabled,
  });

  final TextEditingController controller;
  final String label;
  final String hintText;
  final bool isEnabled;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: BoxDecoration(
        color: AppColors.mainBg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.secondaryColor.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(12),
            ),
            child: AppTextView.body2(
              label,
              color: AppColors.lightPurple1,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              autofocus: true,
              readOnly: !isEnabled,
              minLines: 1,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              cursorColor: AppColors.textPrimary,
              cursorHeight: 15,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
              ),
              decoration: InputDecoration(
                hintText: hintText,
                hintStyle: const TextStyle(
                  color: AppColors.grey1,
                  fontSize: 14,
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineTextAction extends StatelessWidget {
  const _InlineTextAction({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: onTap != null
                  ? AppColors.secondaryColor
                  : AppColors.textSecondary,
            ),
            const SizedBox(width: 6),
            AppTextView.body3(
              label,
              color: onTap != null
                  ? AppColors.secondaryColor
                  : AppColors.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ],
        ),
      ),
    );
  }
}
