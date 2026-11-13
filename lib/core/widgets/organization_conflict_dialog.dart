import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sparrowkaizen/core/widgets/app_button.dart';

import '../constants/app_colors.dart';
import '../constants/app_strings.dart';
import '../managers/app_manager.dart';
import 'app_dialog_style.dart';
import 'app_text_view.dart';

class OrganizationConflictDialog extends StatelessWidget {
  const OrganizationConflictDialog({super.key});
  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: ColoredBox(
        color: Colors.black.withValues(alpha: 0.28),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: double.infinity,
                constraints: const BoxConstraints(maxWidth: 420),
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
                decoration: BoxDecoration(
                  color: AppColors.mainBg,
                  borderRadius: BorderRadius.circular(12),
                  border: AppDialogStyle.border,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.purple1.withValues(alpha: 0.18),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AppTextView.body(
                      AppStrings.organizationsBannerText,
                      color: AppColors.secondaryColor,
                      textAlign: TextAlign.center,
                      fontWeight: FontWeight.w700,
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: 120,
                      child: AppButton(
                        text: "Ok",
                        borderRadius: 12,
                        onPressed: () {
                          context.read<AppManager>().openOrganizationsScreen(
                            openedForConflict: true,
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
