import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import 'app_dialog_style.dart';
import 'app_text_view.dart';

class CustomAlertDialog extends StatelessWidget {
  const CustomAlertDialog(this.title, this.description, {super.key});
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final maxDialogBodyHeight = MediaQuery.sizeOf(context).height * 0.5;
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          Container(
            width: 350,
            margin: const EdgeInsets.only(top: 45), // Space for logo to overlap
            decoration: BoxDecoration(
              color: AppColors.mainBg, // Semi-transparent background
              borderRadius: BorderRadius.circular(12),
              border: AppDialogStyle.border,
            ),
            padding: const EdgeInsets.only(
              top: 20, // Extra padding for logo
              left: 20,
              right: 20,
              bottom: 10,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 15),
                ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: maxDialogBodyHeight),
                  child: SingleChildScrollView(
                    child: Text(
                      description,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.textPrimary),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 35),
                    decoration: const BoxDecoration(
                      color: AppColors.purple1,
                      borderRadius: BorderRadius.all(Radius.circular(12)),
                    ),
                    child: AppTextView.body(
                      "OK",
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Image.asset('${AppStrings.imagePath}round_icon.png', width: 90, height: 90),
        ],
      ),
    );
  }
}
