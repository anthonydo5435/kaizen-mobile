import 'package:flutter/material.dart';
import 'package:sparrowkaizen/features/compliance/domain/entities/learning_module_detail_track.dart';

import '../../../../../core/constants/app_colors.dart';
import '../../../../../core/constants/app_strings.dart';
import '../../../../../core/widgets/app_back_button.dart';
import '../../../../../core/widgets/app_button.dart';
import '../../../../../core/widgets/app_text_view.dart';

class BreakPointScreen extends StatelessWidget {
  const BreakPointScreen({super.key, required this.learningTrack});

  final LearningTrackModuleDetail learningTrack;

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
              AppTextView.title1(
                learningTrack.displayBreakPointTitle,
                color: AppColors.secondaryColor,
                fontWeight: FontWeight.w500,
                textAlign: TextAlign.center,
                fontSize: 24,
              ),
              const SizedBox(height: 10),
              AppTextView.body(
                learningTrack.displayBreakPointSubtitle,
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 52),
              const Spacer(),
              AppButton(
                text: 'Next',
                onPressed: () => Navigator.of(context).pop('next_video'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop('track_modules'),
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
