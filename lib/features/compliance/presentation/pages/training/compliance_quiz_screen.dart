import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sparrowkaizen/core/widgets/fast_circular_progress.dart';

import '../../../../../core/constants/app_colors.dart';
import '../../../../../core/widgets/app_text_view.dart';
import '../../../domain/entities/compliance_quiz_question.dart';
import '../../providers/compliance_quiz_controller.dart';

class ComplianceQuizScreen extends StatefulWidget {
  const ComplianceQuizScreen({
    super.key,
    required this.trackAssignmentUuid,
    required this.trainingModuleUuid,
    required this.isActive,
  });

  final String trackAssignmentUuid;
  final String trainingModuleUuid;
  final bool isActive;

  @override
  State<ComplianceQuizScreen> createState() => _ComplianceQuizScreenState();
}

class _ComplianceQuizScreenState extends State<ComplianceQuizScreen> {
  ComplianceQuizController? _controller;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      final controller = context.read<ComplianceQuizController>();
      _controller = controller;
      if (!controller.isPreparingQuiz) {
        controller.initialize(
          trackAssignmentUuid: widget.trackAssignmentUuid,
          trainingModuleUuid: widget.trainingModuleUuid,
        );
      }
      _syncQuizTimer(controller);
    });
  }

  @override
  void didUpdateWidget(covariant ComplianceQuizScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isActive != widget.isActive) {
      _syncQuizTimer(context.read<ComplianceQuizController>());
    }
  }

  @override
  void dispose() {
    _controller?.cancelQuizTimer();
    super.dispose();
  }

  void _syncQuizTimer(ComplianceQuizController controller) {
    if (widget.isActive) {
      controller.startQuizTimer();
      return;
    }

    controller.cancelQuizTimer();
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ComplianceQuizController>();
    final questions = controller.questions;

    if (controller.isLoading) {
      return FastCircularProgressIndicator();
    }

    if (questions.isEmpty) {
      return const Center(
        child: AppTextView.body(
          'No quiz questions available.',
          color: AppColors.textSecondary,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: _QuizTimerPill(timeText: controller.quizElapsedTimeText),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.separated(
              itemCount: questions.length,
              padding: EdgeInsets.zero,
              separatorBuilder: (_, __) => const SizedBox(height: 14),
              itemBuilder: (context, index) {
                final question = questions[index];

                return _QuizQuestionCard(
                  number: index + 1,
                  question: question,
                  selectedOptionUuid: controller.selectedOptionUuid(
                    question.uuid,
                  ),
                  onOptionTap: (optionUuid) {
                    controller.selectOption(
                      questionUuid: question.uuid,
                      optionUuid: optionUuid,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _QuizTimerPill extends StatelessWidget {
  const _QuizTimerPill({required this.timeText});

  final String timeText;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.green1.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.green1, width: 1.2),
      ),
      child: AppTextView.body3(
        timeText,
        color: AppColors.green1,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _QuizQuestionCard extends StatelessWidget {
  const _QuizQuestionCard({
    required this.number,
    required this.question,
    required this.selectedOptionUuid,
    required this.onOptionTap,
  });

  final int number;
  final ComplianceQuizQuestion question;
  final String? selectedOptionUuid;
  final ValueChanged<String> onOptionTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppTextView.body3(
            '$number. ${question.question}',
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
            height: 1.4,
          ),
          const SizedBox(height: 7),
          ...List.generate(question.options.length, (index) {
            final option = question.options[index];
            return _QuizOption(
              text: option.text,
              isSelected: selectedOptionUuid == option.uuid,
              onTap: () => onOptionTap(option.uuid),
            );
          }),
        ],
      ),
    );
  }
}

class _QuizOption extends StatelessWidget {
  const _QuizOption({
    required this.text,
    required this.isSelected,
    required this.onTap,
  });

  static const double _singleLineTopSpacing = 10;
  static const double _multiLineTopSpacing = 12;
  static const double _singleLineTextHeight = 1.2;
  static const double _multiLineTextHeight = 1.4;
  static const double _indicatorSize = 14;
  static const double _indicatorLeftPadding = 6;
  static const double _indicatorRightPadding = 10;

  final String text;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isSingleLine = _isSingleLine(context, constraints.maxWidth);
        final optionTopSpacing = isSingleLine
            ? _singleLineTopSpacing
            : _multiLineTopSpacing;
        final optionTextHeight = isSingleLine
            ? _singleLineTextHeight
            : _multiLineTextHeight;

        return Padding(
          padding: EdgeInsets.only(top: optionTopSpacing),
          child: GestureDetector(
            onTap: onTap,
            child: Row(
              crossAxisAlignment: isSingleLine
                  ? CrossAxisAlignment.center
                  : CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(
                    left: _indicatorLeftPadding,
                    right: _indicatorRightPadding,
                  ),
                  child: Container(
                    width: _indicatorSize,
                    height: _indicatorSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected
                            ? AppColors.secondaryColor
                            : AppColors.textPrimary,
                        width: 1.5,
                      ),
                    ),
                    child: isSelected
                        ? Center(
                            child: Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: AppColors.secondaryColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                          )
                        : null,
                  ),
                ),
                Expanded(
                  child: AppTextView.body3(
                    text,
                    color: AppColors.textPrimary,
                    height: optionTextHeight,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  bool _isSingleLine(BuildContext context, double maxWidth) {
    if (!maxWidth.isFinite) {
      return false;
    }

    final textMaxWidth =
        maxWidth -
        _indicatorSize -
        _indicatorLeftPadding -
        _indicatorRightPadding;
    if (textMaxWidth <= 0) {
      return false;
    }

    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          height: _multiLineTextHeight,
        ),
      ),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout(maxWidth: textMaxWidth);

    return textPainter.computeLineMetrics().length <= 1;
  }
}
