import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/widgets/app_overlay_close_button.dart';
import '../../../../core/widgets/app_dialog_style.dart';
import '../../../../core/widgets/app_text_view.dart';
import '../../domain/entities/performance_report.dart';
import '../providers/check_in_controller.dart';

Future<void> showPaygradeDetailDialog(
  BuildContext context, {
  required PerformanceReportPaygradeStep step,
  required String paygradeUnit,
  required CheckInController auditController,
  PerformanceReportPaygradeStep? currentStep,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (dialogContext) => _PaygradeDetailDialog(
      step: step,
      paygradeUnit: paygradeUnit,
      currentStep: currentStep,
      auditController: auditController,
    ),
  );
}

class _PaygradeDetailDialog extends StatelessWidget {
  const _PaygradeDetailDialog({
    required this.step,
    required this.paygradeUnit,
    required this.auditController,
    this.currentStep,
  });

  final PerformanceReportPaygradeStep step;
  final String paygradeUnit;
  final CheckInController auditController;
  final PerformanceReportPaygradeStep? currentStep;

  @override
  Widget build(BuildContext context) {
    final requirements = auditController
        .buildPerformanceReportPaygradeRequirements(step.promotionRequirement);
    final maxDialogHeight = MediaQuery.of(context).size.height * 0.5;
    final payRateDisplay = auditController
        .formatPerformanceReportPaygradeDisplay(
          paygradeDisplay: step.payRateDisplay,
          paygradeUnit: paygradeUnit,
        );

    return Dialog(
      backgroundColor: AppColors.mainBg,
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 28),
      shape: AppDialogStyle.shape(radius: 16),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 760, maxHeight: maxDialogHeight),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 20, 10, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppTextView.title(
                    step.title,
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                  const Spacer(),
                  AppOverlayCloseButton(
                    onTap: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              Container(
                height: 2,
                width: double.infinity,
                color: AppColors.textSecondary.withValues(alpha: 0.18),
              ),
              const SizedBox(height: 48),
              if (step.isCurrent || currentStep == null) ...[
                _CurrentPaygrade(
                  auditController: auditController,
                  step: step,
                  paygradeUnit: paygradeUnit,
                ),
              ] else ...[
                _TargetPaygrade(
                  auditController: auditController,
                  currentStep: currentStep!,
                  targetStep: step,
                  paygradeUnit: paygradeUnit,
                ),
              ],
              const SizedBox(height: 22),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const AppTextView.title(
                        AppStrings
                            .performanceReportPaygradeAdvancementRequirementsTitle,
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                      const SizedBox(height: 12),
                      for (final requirement in requirements) ...[
                        _RequirementBullet(text: requirement),
                        const SizedBox(height: 12),
                      ],
                      if (!step.isCurrent && currentStep != null) ...[
                        const SizedBox(height: 24),
                        RichText(
                          text: TextSpan(
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                            children: [
                              TextSpan(
                                text:
                                    'Estimated Target Payrate at ${step.label}: ',
                                style: const TextStyle(
                                  color: AppColors.secondaryColor,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              TextSpan(
                                text: payRateDisplay,
                                style: TextStyle(
                                  color: auditController
                                      .resolvePerformanceReportPaygradeDisplayColor(
                                        payRateDisplay,
                                      ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CurrentPaygrade extends StatelessWidget {
  const _CurrentPaygrade({
    required this.auditController,
    required this.step,
    required this.paygradeUnit,
  });

  final CheckInController auditController;
  final PerformanceReportPaygradeStep step;
  final String paygradeUnit;

  @override
  Widget build(BuildContext context) {
    final payRateDisplay = auditController
        .formatPerformanceReportPaygradeDisplay(
          paygradeDisplay: step.payRateDisplay,
          paygradeUnit: paygradeUnit,
        );

    return Column(
      children: [
        Center(child: _PaygradeCircle(step: step, isCurrent: true)),
        const SizedBox(height: 16),
        Center(
          child: AppTextView.title1(
            payRateDisplay,
            color: auditController.resolvePerformanceReportPaygradeDisplayColor(
              payRateDisplay,
            ),
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _TargetPaygrade extends StatelessWidget {
  const _TargetPaygrade({
    required this.auditController,
    required this.currentStep,
    required this.targetStep,
    required this.paygradeUnit,
  });

  final CheckInController auditController;
  final PerformanceReportPaygradeStep currentStep;
  final PerformanceReportPaygradeStep targetStep;
  final String paygradeUnit;

  @override
  Widget build(BuildContext context) {
    final currentPayRate = auditController.resolvePerformanceReportPaygradeRate(
      currentStep,
    );
    final targetPayRate = auditController.resolvePerformanceReportPaygradeRate(
      targetStep,
    );
    final currentPayRateDisplay = auditController
        .formatPerformanceReportPaygradeDisplay(
          paygradeDisplay: currentStep.payRateDisplay,
          paygradeUnit: paygradeUnit,
        );
    final targetPayRateDisplay = auditController
        .formatPerformanceReportPaygradeDisplay(
          paygradeDisplay: targetStep.payRateDisplay,
          paygradeUnit: paygradeUnit,
        );
    final payDelta = targetPayRate - currentPayRate;
    final normalizedDelta = payDelta <= 0 ? 0.0 : payDelta;
    final payDeltaDisplay = auditController
        .formatPerformanceReportPaygradeDelta(
          value: normalizedDelta,
          paygradeUnit: paygradeUnit,
        );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            children: [
              _PaygradeCircle(step: currentStep, isCurrent: false),
              const SizedBox(height: 10),
              AppTextView.title1(
                currentPayRateDisplay,
                color: auditController
                    .resolvePerformanceReportPaygradeDisplayColor(
                      currentPayRateDisplay,
                    ),
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
              const SizedBox(height: 2),
              const AppTextView.title1(
                'Current Grade',
                color: AppColors.secondaryColor,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 30),
          child: _TargetPaygradeConnector(value: payDeltaDisplay),
        ),
        Expanded(
          child: Column(
            children: [
              _PaygradeCircle(step: targetStep, isCurrent: true),
              const SizedBox(height: 10),
              AppTextView.title1(
                targetPayRateDisplay,
                color: auditController
                    .resolvePerformanceReportPaygradeDisplayColor(
                      targetPayRateDisplay,
                    ),
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TargetPaygradeConnector extends StatelessWidget {
  const _TargetPaygradeConnector({required this.value});

  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 168,
      height: 28,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            left: 0,
            right: 0,
            child: Row(
              children: [
                Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.mainBg,
                    border: Border.all(color: AppColors.hex31d4ff, width: 2.2),
                  ),
                ),
                Expanded(
                  child: Container(
                    height: 10,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.hex3fd8ff.withValues(alpha: 0.28),
                          AppColors.secondaryColor.withValues(alpha: 0.45),
                        ],
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  width: 18,
                  height: 20,
                  child: CustomPaint(painter: _ArrowHeadPainter()),
                ),
              ],
            ),
          ),
          _PaygradeDeltaChip(value: value),
        ],
      ),
    );
  }
}

class _PaygradeCircle extends StatelessWidget {
  const _PaygradeCircle({required this.step, required this.isCurrent});

  final PerformanceReportPaygradeStep step;
  final bool isCurrent;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 78,
      height: 78,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.surfaceDark,
        border: Border.all(
          color: isCurrent
              ? AppColors.secondaryColor
              : AppColors.textSecondary.withValues(alpha: 0.45),
          width: 3,
        ),
        boxShadow: isCurrent
            ? [
                BoxShadow(
                  color: AppColors.secondaryColor.withValues(alpha: 0.55),
                  blurRadius: 28,
                  spreadRadius: 2,
                ),
              ]
            : null,
      ),
      child: AppTextView.title1(
        step.label,
        color: AppColors.textPrimary,
        fontSize: 16,
        fontWeight: FontWeight.w800,
        textAlign: TextAlign.center,
      ),
    );
  }
}

class _PaygradeDeltaChip extends StatelessWidget {
  const _PaygradeDeltaChip({required this.value});

  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.mainBg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: AppColors.textSecondary.withValues(alpha: 0.35),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 8),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const AppTextView.title1(
            '+',
            color: AppColors.hex31d4ff,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
          const SizedBox(width: 4),
          AppTextView.title1(
            value.replaceFirst('+ ', ''),
            color: AppColors.textPrimary,
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ],
      ),
    );
  }
}

class _ArrowHeadPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, size.height * 0.18)
      ..lineTo(size.width * 0.48, size.height * 0.18)
      ..lineTo(size.width, size.height / 2)
      ..lineTo(size.width * 0.48, size.height * 0.82)
      ..lineTo(size.width * 0.12, size.height * 0.82)
      ..lineTo(size.width * 0.28, size.height / 2)
      ..lineTo(size.width * 0.12, size.height * 0.18)
      ..close();

    final paint = Paint()
      ..shader = LinearGradient(
        colors: [
          AppColors.secondaryColor.withValues(alpha: 0.78),
          AppColors.secondaryColor,
        ],
      ).createShader(Offset.zero & size);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _RequirementBullet extends StatelessWidget {
  const _RequirementBullet({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: AppTextView.body3(
            text,
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w500,
            height: 1.45,
          ),
        ),
      ],
    );
  }
}
