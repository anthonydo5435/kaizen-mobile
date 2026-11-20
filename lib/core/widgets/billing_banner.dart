import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../constants/app_colors.dart';
import '../constants/app_strings.dart';
import '../managers/app_manager.dart';
import 'app_text_view.dart';

class BillingBanner extends StatelessWidget {
  const BillingBanner({super.key, this.message = AppStrings.billingBannerText});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 8,
      right: 8,
      top: 45,
      child: SafeArea(
        bottom: false,
        top: false,
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
            decoration: BoxDecoration(
              color: AppColors.mainBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.blue),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: AppTextView.body(
                    message,
                    color: AppColors.blue,
                    textAlign: TextAlign.center,
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: () =>
                      context.read<AppManager>().dismissBillingBanner(),
                  borderRadius: BorderRadius.circular(16),
                  child: const Padding(
                    padding: EdgeInsets.all(2),
                    child: Icon(Icons.close, size: 18, color: AppColors.blue),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
