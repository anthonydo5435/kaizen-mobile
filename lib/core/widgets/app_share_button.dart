import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../constants/app_strings.dart';
import 'app_gradient_action_button.dart';

class AppShareButton extends StatelessWidget {
  const AppShareButton({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: AppStrings.shareAction,
    excludeFromSemantics: true,
    child: AppGradientActionButton(
      label: AppStrings.shareAction,
      icon: Icons.share_outlined,
      iconSize: 16,
      textSize: 13,
      fontWeight: FontWeight.w500,
      foregroundColor: AppColors.secondaryColor,
      iconSpacing: 6,
      minHeight: 35,
      borderRadius: 12,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      boxShadows: const <BoxShadow>[],
      gradientColors: const [AppColors.surfaceDark3, AppColors.hex1b1e27],
      borderColor: AppColors.fieldBorder.withValues(alpha: 0.16),
      onTap: onTap,
    ),
  );
}
