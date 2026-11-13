import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:sparrowkaizen/core/constants/app_colors.dart';

import '../../../../../core/constants/app_strings.dart';
import '../../../../../core/widgets/app_button.dart';
import '../../../../../core/widgets/app_dialog_style.dart';
import '../../../../../core/widgets/app_text_view.dart';
import '../../../domain/entities/compliance_quiz_result.dart';

class QuizResultDialog extends StatefulWidget {
  const QuizResultDialog({
    super.key,
    required this.result,
    required this.fallbackTitle,
    required this.primaryActionText,
    this.fallbackSubtitle,
    this.onPrimaryAction,
    this.onDismiss,
  });

  final ComplianceQuizResult result;
  final String fallbackTitle;
  final String primaryActionText;
  final String? fallbackSubtitle;
  final Future<String?> Function()? onPrimaryAction;
  final VoidCallback? onDismiss;

  @override
  State<QuizResultDialog> createState() => _QuizResultDialogState();
}

class _QuizResultDialogState extends State<QuizResultDialog> {
  bool _isPrimaryActionLoading = false;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surfaceDark2,
      shape: AppDialogStyle.shape(radius: 16),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(widget.result.displayScore),
            const SizedBox(height: 4),
            _buildScoreSection(),
            const SizedBox(height: 32),
            _buildStatistics(context),
            const SizedBox(height: 40),
            _buildActionButtons(context),
            _buildFooterLink(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(String score) {
    return Column(
      children: [
        Container(
          width: 108,
          height: 108,
          alignment: Alignment.center,
          child: SvgPicture.asset(
            widget.result.isPassed
                ? '${AppStrings.imagePath}congrats.svg'
                : '${AppStrings.imagePath}failed.svg',
            width: 92,
            height: 92,
          ),
        ),
        const SizedBox(height: 2),
        AppTextView.title(
          score,
          fontSize: 48,
          fontWeight: FontWeight.w500,
          color: widget.result.isPassed
              ? AppColors.textPrimary
              : AppColors.red1,
        ),
      ],
    );
  }

  Widget _buildScoreSection() {
    return Column(
      children: [
        AppTextView.title1(
          widget.result.displayHeading,
          color: AppColors.secondaryColor,
          fontWeight: FontWeight.w500,
          textAlign: TextAlign.center,
          fontSize: 24,
        ),
        const SizedBox(height: 8),
        AppTextView.body(
          widget.fallbackTitle,
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w500,
        ),
        AppTextView.body2(
          widget.fallbackSubtitle ?? '',
          color: AppColors.grey1,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildStatistics(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _statRow('Your Score: ', widget.result.displayScore),
        const SizedBox(height: 2),
        Row(
          children: [
            AppTextView.body2(
              'Correct Answers: ',
              color: AppColors.grey1,
              fontWeight: FontWeight.w400,
              fontSize: 14,
            ),
            AppTextView.body2(
              widget.result.displayCorrectAnswers,
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap:
                  widget.result.questionResponses.isEmpty ||
                      _isPrimaryActionLoading
                  ? null
                  : () => _openReviewQuiz(context),
              child: Text(
                'Review Quiz',
                style: TextStyle(
                  color: AppColors.secondaryColor,
                  decoration: TextDecoration.underline,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _statRow('Status: ', widget.result.displayStatus),
      ],
    );
  }

  Widget _statRow(String label, String value) {
    return RichText(
      text: TextSpan(
        style: const TextStyle(fontSize: 13),
        children: [
          TextSpan(
            text: label,
            style: TextStyle(
              color: AppColors.textSecondary.withValues(alpha: 0.78),
              fontSize: 14,
              fontWeight: FontWeight.w400,
            ),
          ),
          TextSpan(
            text: value,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Row(
      children: [
        if (!widget.result.isPassed)
          Expanded(
            child: AppButton(
              text: 'Retake Quiz',
              onPressed: _isPrimaryActionLoading
                  ? null
                  : () => Navigator.of(context).pop('retake_quiz'),
              textSize: 12,
              minimumHeight: 30,
              backgroundColor: AppColors.lightPurple1,
              textColor: AppColors.grey3,
            ),
          ),
        if (widget.result.isPassed) ...[
          Expanded(
            child: AppButton(
              text: widget.primaryActionText,
              onPressed: _isPrimaryActionLoading
                  ? null
                  : () => _handlePrimaryAction(context),
              isLoading: _isPrimaryActionLoading,
              textSize: 12,
              minimumHeight: 30,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildFooterLink(BuildContext context) {
    return TextButton(
      onPressed: _isPrimaryActionLoading
          ? null
          : () => Navigator.of(context).pop('track_modules'),
      child: const AppTextView.body3(
        AppStrings.trainingBackToLearningTrack,
        color: AppColors.textPrimary,
      ),
    );
  }

  Future<void> _handlePrimaryAction(BuildContext context) async {
    final primaryAction = widget.onPrimaryAction;
    if (primaryAction == null) {
      Navigator.of(context).pop('next_module');
      widget.onDismiss?.call();
      return;
    }

    final navigator = Navigator.of(context);

    setState(() {
      _isPrimaryActionLoading = true;
    });

    final action = await primaryAction();
    if (!mounted) {
      return;
    }

    if (action == null) {
      setState(() {
        _isPrimaryActionLoading = false;
      });
      return;
    }

    navigator.pop(action);
    widget.onDismiss?.call();
  }

  Future<void> _openReviewQuiz(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.surfaceDark,
          shape: AppDialogStyle.shape(radius: 12),
          title: const AppTextView.body1(
            'Review Quiz',
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: widget.result.questionResponses.length,
              separatorBuilder: (_, __) => const SizedBox(height: 16),
              itemBuilder: (context, index) {
                final response = widget.result.questionResponses[index];
                final selectedOptionText = _selectedOptionText(response);

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppTextView.body2(
                      '${index + 1}. ${response.question}',
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                    const SizedBox(height: 6),
                    AppTextView.body2(
                      'Selected: $selectedOptionText',
                      color: AppColors.grey1,
                    ),
                    const SizedBox(height: 4),
                    AppTextView.body2(
                      response.isCorrect ? 'Correct' : 'Incorrect',
                      color: response.isCorrect
                          ? AppColors.secondaryColor
                          : AppColors.red1,
                      fontWeight: FontWeight.w600,
                    ),
                  ],
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const AppTextView.body2(
                'Close',
                color: AppColors.secondaryColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        );
      },
    );
  }

  String _selectedOptionText(ComplianceQuizQuestionResponse response) {
    final selectedOptionUuid = response.selectedOption;
    if (selectedOptionUuid == null || selectedOptionUuid.isEmpty) {
      return 'Not answered';
    }

    for (final option in response.options) {
      if (option.uuid == selectedOptionUuid) {
        return option.text;
      }
    }

    return selectedOptionUuid;
  }
}
