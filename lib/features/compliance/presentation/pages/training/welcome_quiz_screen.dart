import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

import '../../../../../core/constants/app_colors.dart';
import '../../../../../core/constants/app_strings.dart';
import '../../../../../core/utils/custom_functions.dart';
import '../../../../../core/widgets/app_back_button.dart';
import '../../../../../core/widgets/app_button.dart';
import '../../../../../core/widgets/app_text_view.dart';
import '../../../domain/entities/learning_module_detail_track.dart';
import '../../providers/compliance_quiz_controller.dart';

class WelcomeQuizScreen extends StatefulWidget {
  const WelcomeQuizScreen({
    super.key,
    required this.track,
    required this.trackAssignmentUuid,
    required this.trainingModuleUuid,
    this.clearAnswersOnStart = false,
  });

  final LearningTrackModuleDetail? track;
  final String trackAssignmentUuid;
  final String trainingModuleUuid;
  final bool clearAnswersOnStart;

  @override
  State<WelcomeQuizScreen> createState() => _WelcomeQuizScreenState();
}

class _WelcomeQuizScreenState extends State<WelcomeQuizScreen> {
  Future<void> _handleStartPressed() async {
    final quizController = context.read<ComplianceQuizController>();
    final didStart = await quizController.startQuiz(
      trackAssignmentUuid: widget.trackAssignmentUuid,
      trainingModuleUuid: widget.trainingModuleUuid,
      clearAnswers: widget.clearAnswersOnStart,
    );

    if (!mounted) {
      return;
    }

    if (!didStart) {
      CustomFunctions.showCustomAlert(
        context,
        'Failed',
        'Unable to start quiz. Please try again!',
      );
      return;
    }

    Navigator.of(context).pop('start_quiz');
  }

  @override
  Widget build(BuildContext context) {
    final learningTrack = widget.track;
    final quizController = context.watch<ComplianceQuizController>();
    final isStartingQuiz = quizController.isStartingQuiz;
    final buttonText = quizController.canResumeQuiz
        ? AppStrings.resume
        : AppStrings.start;
    final passingPercentage = learningTrack?.passingPercentage ?? 0;
    final completionPercentage = learningTrack?.completionPercentage ?? 0;

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
              Container(
                width: 108,
                height: 108,
                decoration: const BoxDecoration(
                  color: AppColors.secondaryColor,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: SvgPicture.asset(
                  'lib/assets/images/quiz.svg',
                  width: 92,
                  height: 92,
                ),
              ),
              const SizedBox(height: 14),
              const AppTextView.title1(
                AppStrings.trainingWelcomeQuizTitle,
                color: AppColors.secondaryColor,
                fontWeight: FontWeight.w500,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 1),
              AppTextView.body(
                learningTrack?.displayTrackName ??
                    'Foundations of Clinical Excellence',
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w500,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 52),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const AppTextView.body2(
                    AppStrings.trainingPassingScore,
                    color: AppColors.textSecondary,
                    textAlign: TextAlign.center,
                  ),
                  AppTextView.body2(
                    '$passingPercentage%',
                    color: AppColors.textPrimary,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const AppTextView.body2(
                    '${AppStrings.trainingProgressLabel}: ',
                    color: AppColors.textSecondary,
                    textAlign: TextAlign.center,
                  ),
                  AppTextView.body2(
                    '$completionPercentage%',
                    color: AppColors.textPrimary,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
              const Spacer(),
              AppButton(
                text: buttonText,
                isLoading: isStartingQuiz,
                onPressed: isStartingQuiz ? null : _handleStartPressed,
              ),
              TextButton(
                onPressed: isStartingQuiz
                    ? null
                    : () => Navigator.of(context).pop('track_modules'),
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
