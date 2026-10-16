import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/widgets/app_text_view.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_dialog_style.dart';

class CheckInMediaDeleteDialog extends StatelessWidget {
  const CheckInMediaDeleteDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surfaceDark,
          borderRadius: BorderRadius.circular(12),
          border: AppDialogStyle.border,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const AppTextView.body1(
              AppStrings.auditMediaDeleteTitle,
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
            const SizedBox(height: 10),
            const AppTextView.body2(
              AppStrings.auditMediaDeleteMessage,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
              fontSize: 13,
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    text: AppStrings.auditMediaDeleteNo,
                    onPressed: () => Navigator.of(context).pop(false),
                    backgroundColor: AppColors.surfaceDark3,
                    textColor: AppColors.textPrimary,
                    borderRadius: 12,
                    minimumHeight: 42,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AppButton(
                    text: AppStrings.auditMediaDeleteYes,
                    onPressed: () => Navigator.of(context).pop(true),
                    backgroundColor: AppColors.hexc62828,
                    textColor: Colors.white,
                    borderRadius: 12,
                    minimumHeight: 42,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class CheckInMediaUploadTypeSheet extends StatelessWidget {
  const CheckInMediaUploadTypeSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const AppTextView.body1(
              AppStrings.auditMediaUploadTypeTitle,
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
            const SizedBox(height: 14),
            _MediaSelectionOption(
              icon: Icons.image_outlined,
              title: AppStrings.auditMediaImage,
              subtitle: AppStrings.auditMediaImageFormats,
              onTap: () => Navigator.of(context).pop(true),
            ),
            const SizedBox(height: 10),
            _MediaSelectionOption(
              icon: Icons.videocam_outlined,
              title: AppStrings.auditVideo,
              subtitle: AppStrings.auditMediaVideoFormats,
              onTap: () => Navigator.of(context).pop(false),
            ),
          ],
        ),
      ),
    );
  }
}

class _MediaSelectionOption extends StatelessWidget {
  const _MediaSelectionOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surfaceDark3,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.grey2.withValues(alpha: 0.4)),
          ),
          child: Row(
            children: [
              Icon(icon, color: AppColors.lightPurple1, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppTextView.body2(
                      title,
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                    const SizedBox(height: 3),
                    AppTextView.body2(
                      subtitle,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                      fontSize: 12,
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
