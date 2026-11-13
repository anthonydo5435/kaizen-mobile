import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import 'app_text_view.dart';
import 'fast_circular_progress.dart';

class AppGradientActionButton extends StatelessWidget {
  const AppGradientActionButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
    this.iconOnly = false,
    this.isLoading = false,
    this.iconSize = 18,
    this.textSize = 15,
    this.fontWeight = FontWeight.w600,
    this.foregroundColor = AppColors.textPrimary,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
    this.borderRadius = 24,
    this.minHeight = 48,
    this.iconSpacing = 10,
    this.gradientColors = const <Color>[
      AppColors.purple1,
      AppColors.secondaryColor,
    ],
    this.borderColor,
    this.boxShadows,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final bool iconOnly;
  final bool isLoading;
  final double iconSize;
  final double textSize;
  final FontWeight fontWeight;
  final Color foregroundColor;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final double minHeight;
  final double iconSpacing;
  final List<Color> gradientColors;
  final Color? borderColor;
  final List<BoxShadow>? boxShadows;

  @override
  Widget build(BuildContext context) {
    final isEnabled = onTap != null || isLoading;
    final resolvedBorderRadius = BorderRadius.circular(borderRadius);
    final resolvedBorderColor =
        borderColor ?? AppColors.lightPurple1.withValues(alpha: 0.35);
    final resolvedBoxShadows =
        boxShadows ??
        (isEnabled
            ? <BoxShadow>[
                BoxShadow(
                  color: AppColors.purple1.withValues(alpha: 0.36),
                  blurRadius: 10,
                  offset: const Offset(-6, 0),
                  spreadRadius: -1,
                ),
                BoxShadow(
                  color: AppColors.secondaryColor.withValues(alpha: 0.42),
                  blurRadius: 16,
                  offset: const Offset(12, 0),
                  spreadRadius: -2,
                ),
              ]
            : const <BoxShadow>[]);

    final button = Opacity(
      opacity: isEnabled ? 1 : 0.58,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: resolvedBorderRadius,
          onTap: isLoading ? null : onTap,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: minHeight),
            child: Ink(
              padding: padding,
              decoration: BoxDecoration(
                borderRadius: resolvedBorderRadius,
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: gradientColors,
                ),
                border: Border.all(color: resolvedBorderColor),
                boxShadow: resolvedBoxShadows,
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // The label keeps sizing the button while the loader is shown.
                  Visibility(
                    visible: !isLoading,
                    maintainState: true,
                    maintainAnimation: true,
                    maintainSize: true,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        Icon(icon, color: foregroundColor, size: iconSize),
                        if (!iconOnly) ...[
                          SizedBox(width: iconSpacing),
                          Flexible(
                            child: AppTextView.body(
                              label,
                              color: foregroundColor,
                              fontWeight: fontWeight,
                              fontSize: textSize,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (isLoading)
                    const Positioned.fill(
                      child: Center(
                        child: SizedBox.square(
                          dimension: 18,
                          child: FastCircularProgressIndicator(
                            width: 18,
                            height: 18,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    return iconOnly
        ? Tooltip(
            message: label,
            child: Semantics(button: true, child: button),
          )
        : button;
  }
}
