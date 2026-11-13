import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/app_text_view.dart';

class TrainingSelectionStepField extends StatelessWidget {
  const TrainingSelectionStepField({
    super.key,
    this.stepNumber,
    required this.hintText,
    required this.selectedText,
    required this.enabled,
    required this.onTap,
  });

  final int? stepNumber;
  final String hintText;
  final String? selectedText;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final resolvedText = selectedText?.trim();
    final hasSelection = resolvedText?.isNotEmpty ?? false;
    final foregroundColor = enabled
        ? AppColors.textPrimary
        : AppColors.textSecondary.withValues(alpha: 0.3);
    final borderColor = enabled
        ? AppColors.fieldBorder.withValues(alpha: 0.75)
        : AppColors.grey1.withValues(alpha: 0.35);

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            children: <Widget>[
              if (stepNumber != null) ...[
                Container(
                  width: 22,
                  height: 22,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: enabled ? AppColors.secondaryColor : AppColors.grey1,
                    shape: BoxShape.circle,
                  ),
                  child: AppTextView.body(
                    '$stepNumber',
                    color: enabled ? AppColors.textPrimary : AppColors.mainBg,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: AppTextView.body(
                  hasSelection ? resolvedText! : hintText,
                  color: foregroundColor,
                  fontSize: 15,
                  fontWeight: hasSelection ? FontWeight.w600 : FontWeight.w400,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 10),
              Icon(Icons.arrow_drop_down_rounded, color: foregroundColor, size: 21),
            ],
          ),
        ),
      ),
    );
  }
}
