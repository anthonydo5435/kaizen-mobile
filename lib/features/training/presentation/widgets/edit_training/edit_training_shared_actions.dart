part of 'package:sparrowkaizen/features/training/presentation/pages/edit_training_screen.dart';

class _TrainingCreateWithAiButton extends StatelessWidget {
  const _TrainingCreateWithAiButton({
    required this.isEnabled,
    required this.isLoading,
    required this.onTap,
  });

  final bool isEnabled;
  final bool isLoading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppAiGenerateButton(
      label: AppStrings.trainingCreateWithAi,
      onTap: onTap,
      isEnabled: isEnabled,
      isLoading: isLoading,
      showOutline: true,
    );
  }
}

class _SecondaryTrainingActionButton extends StatelessWidget {
  const _SecondaryTrainingActionButton({
    required this.label,
    this.icon,
    required this.onTap,
    this.isEnabled = true,
    this.isLoading = false,
    this.isDottedBorder = false,
    this.borderStrokeWidth = 1.2,
    this.borderDashLength = 6,
    this.borderGapLength = 4,
    this.horizontalPadding = 14,
    this.verticalPadding = 10,
    this.borderRadius = 999,
    this.mainAxisAlignment = MainAxisAlignment.start,
    this.fontWeight = FontWeight.w700,
    this.fontSize,
    this.iconSize = 16,
    this.backgroundColor,
    this.activeBorderColor,
    this.activeTextColor,
    this.activeIconColor,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final bool isEnabled;
  final bool isLoading;
  final bool isDottedBorder;
  final double borderStrokeWidth;
  final double borderDashLength;
  final double borderGapLength;
  final double horizontalPadding;
  final double verticalPadding;
  final double borderRadius;
  final MainAxisAlignment mainAxisAlignment;
  final FontWeight fontWeight;
  final double? fontSize;
  final double iconSize;
  final Color? backgroundColor;
  final Color? activeBorderColor;
  final Color? activeTextColor;
  final Color? activeIconColor;

  @override
  Widget build(BuildContext context) {
    final isInteractive = isEnabled && !isLoading && onTap != null;
    final borderColor = isInteractive
        ? activeBorderColor ?? AppColors.fieldBorder.withValues(alpha: 0.22)
        : AppColors.fieldBorder.withValues(alpha: 0.14);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isInteractive ? onTap : null,
        borderRadius: BorderRadius.circular(borderRadius),
        child: CustomPaint(
          foregroundPainter: isDottedBorder
              ? _DottedRoundedBorderPainter(
                  color: borderColor,
                  radius: borderRadius,
                  strokeWidth: borderStrokeWidth,
                  dashLength: borderDashLength,
                  gapLength: borderGapLength,
                )
              : null,
          child: Ink(
            padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: verticalPadding),
            decoration: BoxDecoration(
              color: backgroundColor ?? AppColors.surfaceDark,
              borderRadius: BorderRadius.circular(borderRadius),
              border: isDottedBorder ? null : Border.all(color: borderColor),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: mainAxisAlignment,
              children: [
                if (icon != null) ...[
                  Icon(
                    icon,
                    size: iconSize,
                    color: isInteractive
                        ? activeIconColor ?? AppColors.secondaryColor
                        : AppColors.textSecondary,
                  ),
                  const SizedBox(width: 8),
                ],
                Flexible(
                  child: AppTextView.body2(
                    label,
                    color: isInteractive
                        ? activeTextColor ?? AppColors.textPrimary
                        : AppColors.textSecondary,
                    fontWeight: fontWeight,
                    fontSize: fontSize,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isLoading) ...[
                  const SizedBox(width: 10),
                  FastCircularProgressIndicator(width: 14, height: 14),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TrainingSectionHeader extends StatelessWidget {
  const _TrainingSectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return AppTextView.body3(title, color: AppColors.textSecondary, fontWeight: FontWeight.w700);
  }
}

class _TrainingDisplayCard extends StatelessWidget {
  const _TrainingDisplayCard({required this.child, this.padding = const EdgeInsets.all(16)});

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.surfaceDark2.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.fieldBorder.withValues(alpha: 0.16)),
      ),
      child: child,
    );
  }
}

class _TrainingEditableTextCard extends StatelessWidget {
  const _TrainingEditableTextCard({
    required this.controller,
    required this.hintText,
    required this.minLines,
    required this.maxLines,
    this.wrapWithCard = true,
    this.expands = false,
    this.textColor = AppColors.textPrimary,
    this.hintColor,
    this.padding = const EdgeInsets.all(16),
  });

  final TextEditingController controller;
  final String hintText;
  final int minLines;
  final int maxLines;
  final bool wrapWithCard;
  final bool expands;
  final Color textColor;
  final Color? hintColor;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final textField = Padding(
      padding: padding,
      child: TextField(
        controller: controller,
        cursorColor: textColor,
        cursorHeight: 15,
        expands: expands,
        minLines: expands ? null : minLines,
        maxLines: expands ? null : maxLines,
        textAlignVertical: TextAlignVertical.top,
        keyboardType: TextInputType.multiline,
        style: TextStyle(color: textColor, fontSize: 13, fontWeight: FontWeight.w400, height: 1.65),
        decoration: InputDecoration(
          isCollapsed: true,
          border: InputBorder.none,
          hintText: hintText,
          hintStyle: TextStyle(
            color: hintColor ?? AppColors.textSecondary.withValues(alpha: 0.74),
            fontSize: 13,
            fontWeight: FontWeight.w400,
            height: 1.65,
          ),
        ),
      ),
    );

    if (!wrapWithCard) {
      return textField;
    }

    return _TrainingDisplayCard(child: textField);
  }
}

/// Keeps lesson titles in the same field layout for editing and read-only previews.
class TrainingLessonTitleField extends StatelessWidget {
  const TrainingLessonTitleField({
    super.key,
    required this.valueText,
    required this.hintText,
    this.onTap,
    this.isLoading = false,
    this.isReadOnly = false,
  });

  final String valueText;
  final String hintText;
  final VoidCallback? onTap;
  final bool isLoading;
  final bool isReadOnly;

  @override
  Widget build(BuildContext context) {
    final hasValue = valueText.trim().isNotEmpty;

    return Semantics(
      textField: true,
      readOnly: isReadOnly,
      enabled: !isReadOnly,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isReadOnly ? null : onTap,
          borderRadius: BorderRadius.circular(16),
          splashFactory: NoSplash.splashFactory,
          overlayColor: const WidgetStatePropertyAll(Colors.transparent),
          child: Ink(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.surfaceDark2.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.fieldBorder.withValues(alpha: 0.6)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    hasValue ? valueText.trim() : hintText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: hasValue
                          ? AppColors.textPrimary
                          : AppColors.textSecondary.withValues(alpha: 0.74),
                      fontSize: 16,
                      fontWeight: hasValue ? FontWeight.w600 : FontWeight.w500,
                      height: 1.25,
                    ),
                  ),
                ),
                if (isLoading || !isReadOnly) const SizedBox(width: 12),
                if (isLoading)
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: FastCircularProgressIndicator(width: 12, height: 12),
                  )
                else if (!isReadOnly)
                  Icon(
                    Icons.edit_outlined,
                    color: onTap != null ? AppColors.secondaryColor : AppColors.textSecondary,
                    size: 18,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TrainingOutlinedTextField extends StatelessWidget {
  const _TrainingOutlinedTextField({
    required this.controller,
    required this.hintText,
    required this.minLines,
    required this.maxLines,
    this.readOnly = false,
    this.showCursor,
    this.onTap,
    this.textInputAction,
    this.fontSize = 14,
    this.fontWeight = FontWeight.w600,
    this.textHeight = 1.4,
    this.hintFontWeight = FontWeight.w500,
    this.contentPadding = const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
  });

  final TextEditingController controller;
  final String hintText;
  final int minLines;
  final int maxLines;
  final bool readOnly;
  final bool? showCursor;
  final VoidCallback? onTap;
  final TextInputAction? textInputAction;
  final double fontSize;
  final FontWeight fontWeight;
  final double textHeight;
  final FontWeight hintFontWeight;
  final EdgeInsetsGeometry contentPadding;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      autofocus: false,
      readOnly: readOnly,
      showCursor: showCursor,
      onTap: onTap,
      cursorColor: Colors.white,
      cursorHeight: 15,
      minLines: minLines,
      maxLines: maxLines,
      textInputAction: textInputAction,
      keyboardType: maxLines > 1 ? TextInputType.multiline : TextInputType.text,
      style: TextStyle(
        color: AppColors.textPrimary,
        fontSize: fontSize,
        fontWeight: fontWeight,
        height: textHeight,
      ),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(
          color: AppColors.textSecondary.withValues(alpha: 0.74),
          fontSize: fontSize,
          fontWeight: hintFontWeight,
          height: textHeight,
        ),
        filled: true,
        fillColor: AppColors.surfaceDark2.withValues(alpha: 0.42),
        contentPadding: contentPadding,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: AppColors.fieldBorder.withValues(alpha: 0.16)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: AppColors.fieldBorder.withValues(alpha: 0.16)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: AppColors.secondaryColor),
        ),
      ),
    );
  }
}
