import 'dart:async';

import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../constants/app_strings.dart';
import '../managers/app_manager.dart';
import 'app_button.dart';
import 'app_dialog_style.dart';
import 'app_text_view.dart';

bool showBillingRestrictionIfNeeded(BuildContext context) {
  if (AppManager.instance.canUsePaidFeatures) return false;
  unawaited(PaidFeaturesUnavailableDialog.show(context));
  return true;
}

VoidCallback? guardPaidAction(BuildContext context, VoidCallback? onTap) {
  if (onTap == null) return null;
  return () {
    if (!showBillingRestrictionIfNeeded(context)) onTap();
  };
}

class PaidFeaturesUnavailableDialog extends StatelessWidget {
  const PaidFeaturesUnavailableDialog({super.key});

  static Future<void> show(BuildContext context) => showDialog<void>(
    context: context,
    builder: (_) => const PaidFeaturesUnavailableDialog(),
    barrierDismissible: false,
  );

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
        child: SingleChildScrollView(
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
                AppStrings.paidFeaturesUnavailableMessage,
                color: AppColors.textSecondary,
                textAlign: TextAlign.center,
                height: 1.4,
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: 132,
                child: AppButton(
                  text: AppStrings.paidFeaturesUnavailableOk,
                  backgroundColor: AppColors.secondaryColor,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
