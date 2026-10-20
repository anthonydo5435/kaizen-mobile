import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import 'app_text_view.dart';
import 'fast_circular_progress.dart';

class AppAiGenerateButton extends StatelessWidget {
  const AppAiGenerateButton({
    super.key,
    required this.label,
    required this.onTap,
    this.isEnabled = true,
    this.isLoading = false,
    this.expand = false,
    this.showOutline = false,
    this.minHeight,
    this.textSize,
    this.maxLines = 1,
    this.fontWeight = FontWeight.w700,
    this.outerPadding = const EdgeInsets.all(6),
    this.contentPadding = const EdgeInsets.symmetric(horizontal: 20, vertical: 7),
  });

  final String label;
  final VoidCallback? onTap;
  final bool isEnabled;
  final bool isLoading;
  final bool expand;
  final bool showOutline;
  final double? minHeight;
  final double? textSize;
  final int? maxLines;
  final FontWeight fontWeight;
  final EdgeInsetsGeometry outerPadding;
  final EdgeInsetsGeometry contentPadding;

  @override
  Widget build(BuildContext context) {
    final isInteractive = isEnabled && !isLoading && onTap != null;

    return Padding(
      // Keep the glow inside the surrounding scroll view or page clip.
      padding: outerPadding,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: isInteractive
                ? const [AppColors.secondaryColor, AppColors.purple1]
                : [
                    AppColors.secondaryColor.withValues(alpha: 0.55),
                    AppColors.purple1.withValues(alpha: 0.55),
                  ],
          ),
          border: showOutline
              ? Border.all(
                  color: AppColors.lightPurple1.withValues(alpha: isInteractive ? 0.9 : 0.45),
                  width: 1.2,
                )
              : null,
          boxShadow: isInteractive
              ? [
                  BoxShadow(
                    color: AppColors.purple1.withValues(alpha: 0.38),
                    blurRadius: 9,
                    spreadRadius: -1,
                    offset: const Offset(-2, 0),
                  ),
                  BoxShadow(
                    color: AppColors.secondaryColor.withValues(alpha: 0.42),
                    blurRadius: 10,
                    spreadRadius: -1,
                    offset: const Offset(2, 0),
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 4,
                    offset: const Offset(0, 3),
                  ),
                ]
              : const <BoxShadow>[],
        ),
        child: SizedBox(
          width: expand ? double.infinity : null,
          child: TextButton.icon(
            onPressed: isInteractive ? onTap : null,
            clipBehavior: Clip.antiAlias,
            style: TextButton.styleFrom(
              backgroundColor: Colors.transparent,
              foregroundColor: AppColors.textPrimary,
              disabledBackgroundColor: Colors.transparent,
              disabledForegroundColor: AppColors.textSecondary,
              minimumSize: Size(0, minHeight ?? 38),
              padding: contentPadding,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              side: BorderSide.none,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(12)),
              ),
            ),
            icon: SizedBox.square(
              dimension: 20,
              child: Center(
                child: isLoading
                    ? const FastCircularProgressIndicator(width: 16, height: 16)
                    : const Icon(Icons.auto_awesome_rounded, size: 20),
              ),
            ),
            label: AppTextView.body2(
              label,
              color: isInteractive ? AppColors.textPrimary : AppColors.textSecondary,
              fontSize: textSize ?? 15,
              fontWeight: fontWeight,
              maxLines: maxLines,
              overflow: maxLines == null ? TextOverflow.visible : TextOverflow.ellipsis,
            ),
          ),
        ),
      ),
    );
  }
}
