import 'package:flutter/material.dart';

import '../../../../../core/constants/app_colors.dart';
import '../../../../../core/constants/app_strings.dart';
import '../../../../../core/widgets/app_back_button.dart';
import '../../../../../core/widgets/app_button.dart';
import '../../../../../core/widgets/app_text_view.dart';

class NextQuizVideoScreen extends StatelessWidget {
  const NextQuizVideoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceDark,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        leadingWidth: 40,
        leading: const AppBackButton(),
      ),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 12, 8, 24),
          child: Column(
            children: [
              const Spacer(),
              const AppTextView.title1(
                AppStrings.trainingWelcomeQuizTitle,
                color: AppColors.secondaryColor,
                fontWeight: FontWeight.w500,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 1),
              AppTextView.body(
                'Foundations of Clinical Excellence',
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w500,
                textAlign: TextAlign.center,
              ),
              const Spacer(),
              AppButton(
                text: AppStrings.next,
                onPressed: () => Navigator.of(context).pop(true),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const AppTextView.body3(
                  AppStrings.trainingBackToTrackModules,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
