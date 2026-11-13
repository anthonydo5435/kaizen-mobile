import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import 'app_dialog_style.dart';
import 'app_text_view.dart';
import 'fast_circular_progress.dart';

class AppConfirmationDialog extends StatelessWidget {
  const AppConfirmationDialog({
    super.key,
    required this.title,
    required this.description,
    required this.onConfirmCallback,
    required this.onCancelCallback,
    this.confirmText = 'Yes',
    this.cancelText = 'No',
    this.isConfirmLoading = false,
  });

  final String title;
  final String description;
  final Future<void> Function() onConfirmCallback;
  final Future<void> Function() onCancelCallback;
  final String confirmText;
  final String cancelText;
  final bool isConfirmLoading;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surfaceDark,
      shape: AppDialogStyle.shape(radius: 18),
      title: AppTextView.body1(
        title,
        color: AppColors.textPrimary,
        fontWeight: FontWeight.w700,
        textAlign: TextAlign.center,
      ),
      content: AppTextView.body(
        description,
        color: AppColors.textPrimary,
        textAlign: TextAlign.center,
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: isConfirmLoading
          ? [
              SizedBox(
                width: double.infinity,
                height: 45,
                child: Center(child: FastCircularProgressIndicator()),
              ),
            ]
          : [
              TextButton(
                onPressed: onCancelCallback,
                child: AppTextView.body(
                  cancelText,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              TextButton(
                onPressed: onConfirmCallback,
                child: AppTextView.body(
                  confirmText,
                  color: AppColors.secondaryColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
    );
  }
}
