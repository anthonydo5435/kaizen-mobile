import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/widgets/app_text_view.dart';
import '../../../../core/widgets/fast_circular_progress.dart';
import '../../domain/entities/performance_report.dart';

class PerformanceReportPersonaCard extends StatelessWidget {
  const PerformanceReportPersonaCard({
    super.key,
    required this.report,
    required this.showPersonaHeader,
    required this.showGenerateRemarksAction,
    required this.isGeneratingRemarks,
    required this.onGenerateRemarks,
  });

  final PerformanceReport report;
  final bool showPersonaHeader;
  final bool showGenerateRemarksAction;
  final bool isGeneratingRemarks;
  final Future<void> Function() onGenerateRemarks;

  String get _displayArchetypeSubtitle {
    final value = report.archetypeSubtitle.trim();
    if (value.isEmpty) {
      return value;
    }

    final separatorIndex = value.indexOf('_');
    if (separatorIndex == -1) {
      return value;
    }

    return value.substring(0, separatorIndex).trim();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          if (report.hasPersonalityData) ...[
            if (showPersonaHeader) ...[
              Image.asset(
                report.personalityAvatarImagePath!,
                width: 160,
                height: 160,
              ),
              const SizedBox(height: 1),
              AppTextView.body2(
                report.archetypeTitle,
                color: AppColors.lightPurple1,
                fontWeight: FontWeight.w600,
              ),
              AppTextView.body1(
                _displayArchetypeSubtitle,
                color: AppColors.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
              const SizedBox(height: 12),
              AppTextView.body1(
                report.archetypeSummary,
                color: AppColors.secondaryColor,
                textAlign: TextAlign.center,
                fontSize: 15,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
              const SizedBox(height: 16),
              ...report.guidanceParagraphs.map(
                (paragraph) => Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: AppTextView.body(
                    paragraph,
                    color: AppColors.textPrimary,
                    fontSize: 13,
                    height: 1.45,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (showGenerateRemarksAction) ...[
                Align(
                  alignment: Alignment.centerLeft,
                  child: SizedBox(
                    height: 32,
                    child: OutlinedButton(
                      onPressed: isGeneratingRemarks ? null : onGenerateRemarks,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.secondaryColor,
                        side: const BorderSide(color: AppColors.secondaryColor),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Opacity(
                            opacity: isGeneratingRemarks ? 0 : 1,
                            child: const Text(
                              AppStrings.performanceReportGenerateRemarks,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppColors.secondaryColor,
                              ),
                            ),
                          ),
                          if (isGeneratingRemarks)
                            const SizedBox(
                              width: 12,
                              height: 12,
                              child: FastCircularProgressIndicator(
                                width: 12,
                                height: 12,
                                color: AppColors.secondaryColor,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
            ],
          ],
        ],
      ),
    );
  }
}
