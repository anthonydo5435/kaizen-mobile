import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/widgets/app_overlay_close_button.dart';
import '../../../../core/widgets/app_text_view.dart';
import '../../domain/entities/performance_report.dart';
import '../providers/check_in_controller.dart';
import 'paygrade_detail_dialog.dart';

Future<void> showPerformanceReportPaygradePipelineSheet(
  BuildContext context, {
  required PerformanceReport report,
  required PerformanceReportPaygradeStep? currentStep,
}) {
  final auditController = context.read<CheckInController>();
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.mainBg,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
    ),
    builder: (sheetContext) {
      final maxSheetHeight = MediaQuery.sizeOf(sheetContext).height * 0.88;

      return SafeArea(
        top: false,
        child: SafeArea(
          top: false,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxSheetHeight),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.textSecondary.withValues(alpha: 0.36),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 18),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Row(
                    children: [
                      const Expanded(
                        child: AppTextView.body1(
                          AppStrings.sheetPaygradePipelineTitle,
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      AppOverlayCloseButton(
                        onTap: () => Navigator.of(sheetContext).pop(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 14),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: AppTextView.body4(
                      AppStrings.performanceReportPaygradeTapHint,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                      height: 1.4,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                    child: _PaygradePipelineCard(
                      report: report,
                      controller: auditController,
                      onStepTap: (step) => showPaygradeDetailDialog(
                        sheetContext,
                        step: step,
                        paygradeUnit: report.paygradeUnit,
                        auditController: auditController,
                        currentStep: currentStep,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

class PerformanceReportPaygradePipelineSection extends StatelessWidget {
  const PerformanceReportPaygradePipelineSection({
    super.key,
    required this.report,
    required this.onTap,
  });

  final PerformanceReport report;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final summary = context
        .read<CheckInController>()
        .buildPerformanceReportPaygradeSummary(report);

    return _PaygradeSummaryCard(
      onTap: onTap,
      currentPosition: summary.currentPosition,
      currentPay: summary.currentPay,
      totalLevels: summary.totalLevels,
    );
  }
}

class _PaygradePipelineCard extends StatelessWidget {
  const _PaygradePipelineCard({
    required this.report,
    required this.controller,
    required this.onStepTap,
  });

  final PerformanceReport report;
  final CheckInController controller;
  final ValueChanged<PerformanceReportPaygradeStep> onStepTap;

  @override
  Widget build(BuildContext context) {
    final hasPaygrades = report.paygradePipeline.isNotEmpty;
    final currentStepIndex = report.paygradePipeline.indexWhere(
      (step) => step.isCurrent,
    );
    if (!hasPaygrades) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: AppTextView.body3(
          AppStrings.performanceReportPaygradePipelineEmpty,
          color: AppColors.textSecondary,
          fontWeight: FontWeight.w600,
        ),
      );
    }

    return Column(
      children: List<Widget>.generate(report.paygradePipeline.length, (index) {
        final step = report.paygradePipeline[index];
        final status = controller.resolvePerformanceReportPaygradeStageStatus(
          step: step,
          index: index,
          currentStepIndex: currentStepIndex,
        );
        final paygradeDisplay = controller
            .formatPerformanceReportPaygradeDisplay(
              paygradeDisplay: step.caption,
              paygradeUnit: report.paygradeUnit,
            );

        return Padding(
          padding: EdgeInsets.only(
            bottom: index == report.paygradePipeline.length - 1 ? 0 : 12,
          ),
          child: _PipelineStageTile(
            step: step,
            paygradeDisplay: paygradeDisplay,
            paygradeDisplayColor: controller
                .resolvePerformanceReportPaygradeDisplayColor(
                  paygradeDisplay,
                  payRateAmount: step.payRateAmount,
                ),
            status: status,
            showConnector: index < report.paygradePipeline.length - 1,
            onTap: () => onStepTap(step),
          ),
        );
      }),
    );
  }
}

class _PaygradeSummaryCard extends StatefulWidget {
  const _PaygradeSummaryCard({
    required this.onTap,
    required this.currentPosition,
    required this.currentPay,
    required this.totalLevels,
  });

  final VoidCallback onTap;
  final String currentPosition;
  final String currentPay;
  final String totalLevels;

  @override
  State<_PaygradeSummaryCard> createState() => _PaygradeSummaryCardState();
}

class _PaygradeSummaryCardState extends State<_PaygradeSummaryCard> {
  late final ValueNotifier<bool> _isExpandedNotifier;

  @override
  void initState() {
    super.initState();
    _isExpandedNotifier = ValueNotifier<bool>(false);
  }

  @override
  void dispose() {
    _isExpandedNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: _isExpandedNotifier,
      builder: (context, isExpanded, _) {
        void toggleExpanded() {
          _isExpandedNotifier.value = !isExpanded;
        }

        return Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: toggleExpanded,
            splashFactory: NoSplash.splashFactory,
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
            hoverColor: Colors.transparent,
            focusColor: Colors.transparent,
            child: Ink(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              decoration: BoxDecoration(
                color: AppColors.surfaceDark,
                borderRadius: BorderRadius.circular(14),
              ),
              child: AnimatedSize(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeInOut,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: AppTextView.body2(
                            AppStrings.sheetPaygradePipelineTitle,
                            color: AppColors.secondaryColor,
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                        _PaygradeSummaryChevron(
                          isExpanded: isExpanded,
                          onTap: toggleExpanded,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _PaygradeSummaryRow(
                      label: AppStrings
                          .performanceReportPaygradeCurrentPositionValueLabel,
                      value: widget.currentPosition,
                    ),
                    if (isExpanded) ...[
                      const SizedBox(height: 6),
                      _PaygradeSummaryRow(
                        label:
                            AppStrings.performanceReportPaygradeCurrentPayLabel,
                        value: widget.currentPay,
                      ),
                      const SizedBox(height: 6),
                      _PaygradeSummaryRow(
                        label: AppStrings
                            .performanceReportPaygradeTotalLevelsLabel,
                        value: widget.totalLevels,
                      ),
                      const SizedBox(height: 8),
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(999),
                          onTap: widget.onTap,
                          splashFactory: NoSplash.splashFactory,
                          splashColor: Colors.transparent,
                          highlightColor: Colors.transparent,
                          hoverColor: Colors.transparent,
                          focusColor: Colors.transparent,
                          child: const Padding(
                            padding: EdgeInsets.symmetric(vertical: 2),
                            child: Text(
                              AppStrings.performanceReportPaygradePipelineTitle,
                              style: TextStyle(
                                color: AppColors.secondaryColor,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                decoration: TextDecoration.underline,
                                decorationColor: AppColors.secondaryColor,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PaygradeSummaryChevron extends StatelessWidget {
  const _PaygradeSummaryChevron({
    required this.isExpanded,
    required this.onTap,
  });

  final bool isExpanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedRotation(
      turns: isExpanded ? 0.5 : 0,
      duration: const Duration(milliseconds: 220),
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          splashFactory: NoSplash.splashFactory,
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          hoverColor: Colors.transparent,
          focusColor: Colors.transparent,
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.mainBg,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: AppColors.fieldBorder.withValues(alpha: 0.28),
              ),
            ),
            child: const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: AppColors.textSecondary,
              size: 20,
            ),
          ),
        ),
      ),
    );
  }
}

class _PaygradeSummaryRow extends StatelessWidget {
  const _PaygradeSummaryRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: '$label ',
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              height: 1.3,
            ),
          ),
          TextSpan(
            text: value,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              height: 1.3,
            ),
          ),
        ],
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }
}

class _PipelineStageTile extends StatelessWidget {
  const _PipelineStageTile({
    required this.step,
    required this.paygradeDisplay,
    required this.paygradeDisplayColor,
    required this.status,
    required this.showConnector,
    this.onTap,
  });

  final PerformanceReportPaygradeStep step;
  final String paygradeDisplay;
  final Color paygradeDisplayColor;
  final PerformanceReportPaygradeStageStatus status;
  final bool showConnector;
  final VoidCallback? onTap;
  static const double _indicatorSize = 46;
  static const double _connectorThickness = 3;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 72,
              child: Column(
                children: [
                  Container(
                    width: _indicatorSize,
                    height: _indicatorSize,
                    alignment: Alignment.center,
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: status.indicatorFillColor,
                      border: Border.all(color: status.borderColor, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.secondaryColor.withValues(
                            alpha: step.isCurrent ? 0.28 : 0.18,
                          ),
                          blurRadius: step.isCurrent ? 18 : 12,
                          spreadRadius: step.isCurrent ? 1 : 0,
                        ),
                      ],
                    ),
                    child: AppTextView.body4(
                      step.label,
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      height: 1.2,
                    ),
                  ),
                  if (showConnector)
                    Expanded(
                      child: Container(
                        width: _connectorThickness,
                        margin: const EdgeInsets.only(top: 8),
                        decoration: BoxDecoration(
                          color: AppColors.secondaryColor.withValues(
                            alpha: 0.72,
                          ),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Container(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                decoration: BoxDecoration(
                  color: status.surfaceColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColors.secondaryColor.withValues(alpha: 0.18),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              _PipelineMetaChip(
                                icon: Icons.payments_outlined,
                                text: paygradeDisplay,
                                textColor: paygradeDisplayColor,
                                borderColor: status.borderColor,
                              ),
                              const Spacer(),
                              _PipelineStatusBadge(status: status),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(999),
                              onTap: onTap,
                              child: const Padding(
                                padding: EdgeInsets.symmetric(vertical: 2),
                                child: Text(
                                  AppStrings
                                      .performanceReportPaygradeAdvancementRequirementsTitle,
                                  style: TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    decoration: TextDecoration.underline,
                                    decorationColor: AppColors.textPrimary,
                                    height: 1.2,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: status.accentColor,
                      size: 18,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PipelineStatusBadge extends StatelessWidget {
  const _PipelineStatusBadge({required this.status});

  final PerformanceReportPaygradeStageStatus status;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: status.badgeBackgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: AppTextView.body4(
        status.label,
        color: status.badgeTextColor,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _PipelineMetaChip extends StatelessWidget {
  const _PipelineMetaChip({
    required this.icon,
    required this.text,
    required this.textColor,
    required this.borderColor,
  });

  final IconData icon;
  final String text;
  final Color textColor;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.mainBg.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: borderColor.withValues(alpha: 0.38)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: textColor, size: 14),
          const SizedBox(width: 6),
          Flexible(
            child: AppTextView.body4(
              text,
              color: textColor,
              fontWeight: FontWeight.w700,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
