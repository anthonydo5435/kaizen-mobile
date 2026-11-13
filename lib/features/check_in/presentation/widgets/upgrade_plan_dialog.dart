import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_dialog_style.dart';
import '../../../../core/widgets/app_text_view.dart';

class UpgradePlanDialog extends StatelessWidget {
  const UpgradePlanDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(maxWidth: 420),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
        decoration: BoxDecoration(
          color: AppColors.mainBg,
          borderRadius: BorderRadius.circular(12),
          border: AppDialogStyle.border,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.24),
              blurRadius: 22,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppTextView.body1(
              AppStrings.paidFeaturesUnavailable,
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 14),
            AppTextView.body(
              AppStrings.yourSubscriptionEnded,
              color: AppColors.textSecondary,
              textAlign: TextAlign.center,
              height: 1.4,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: 132,
              child: AppButton(
                text: AppStrings.upgradePlanButton,
                backgroundColor: AppColors.secondaryColor,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
