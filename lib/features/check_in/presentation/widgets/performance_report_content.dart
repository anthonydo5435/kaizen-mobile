import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/widgets/app_text_view.dart';
import '../../../../core/widgets/fast_circular_progress.dart';
import '../../domain/entities/performance_report.dart';
import '../pages/performance_report_paygrade_pipeline_sheet.dart';
import '../providers/check_in_controller.dart';
import '../providers/performance_report_controller.dart';
import 'performance_report_commitment_section.dart';
import 'performance_report_core_values_card.dart';
import 'performance_report_persona_card.dart';
import 'performance_report_ratings.dart';
import 'performance_report_selectors.dart';
import 'performance_report_summary.dart';

class PerformanceReportContent extends StatelessWidget {
  const PerformanceReportContent({
    super.key,
    required this.controller,
    required this.report,
    required this.viewData,
    required this.isMyReport,
    required this.onDateRangePressed,
    required this.onHistoryPressed,
    required this.onDescriptionGo,
    required this.onEmployeeSignature,
    required this.onFacilitatorSignature,
    required this.onCertify,
  });

  final PerformanceReportController controller;
  final PerformanceReport? report;
  final PerformanceReportViewData? viewData;
  final bool isMyReport;
  final VoidCallback onDateRangePressed;
  final VoidCallback onHistoryPressed;
  final ValueChanged<PerformanceReportRatingRow> onDescriptionGo;
  final VoidCallback onEmployeeSignature;
  final VoidCallback onFacilitatorSignature;
  final VoidCallback onCertify;

  @override
  Widget build(BuildContext context) {
    final report = this.report;
    final viewData = this.viewData;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(8, 10, 8, 24),
      child: Column(
        children: [
          if (report != null) ...[
            PerformanceReportSummaryCard(report: report),
            const SizedBox(height: 14),
            if (report.profile.profiles.length > 1) ...[
              PerformanceReportProfileChips(
                report: report,
                isLoading: controller.state.isPerformanceReportLoading,
                onProfileTap: controller.selectProfile,
              ),
              const SizedBox(height: 12),
            ],
          ],
          if (!controller.state.isPerformanceReportLoading)
            _ReportFilters(
              controller: controller,
              onDateRangePressed: onDateRangePressed,
              onHistoryPressed: onHistoryPressed,
            ),
          if (controller.state.isPerformanceReportLoading)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: FastCircularProgressIndicator(),
            )
          else if (report == null || viewData == null)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 24),
              child: AppTextView.body(
                AppStrings.performanceReportUnavailable,
                color: AppColors.textSecondary,
                textAlign: TextAlign.center,
              ),
            )
          else if (viewData.isOpenSeatView)
            PerformanceReportOpenSeatView(message: viewData.reportMessage)
          else if (viewData.shouldShowCompleteReportUi)
            _buildCompleteReport(context, report, viewData)
          else if (viewData.shouldShowMessageOnly && viewData.reportMessage != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 24, 12, 0),
              child: AppTextView.body2(
                viewData.reportMessage!,
                color: AppColors.textSecondary,
                textAlign: TextAlign.center,
                fontWeight: FontWeight.w500,
                height: 1.5,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCompleteReport(
    BuildContext context,
    PerformanceReport report,
    PerformanceReportViewData viewData,
  ) {
    final auditController = controller.checkInController;
    return Column(
      children: [
        if (report.hasPersonalityData) ...[
          PerformanceReportPersonaCard(
            report: report,
            showPersonaHeader: controller.state.isOwner,
            showGenerateRemarksAction: controller.canGenerateRemarks,
            isGeneratingRemarks: controller.state.isGeneratingPerformanceReportRemarks,
            onGenerateRemarks: auditController.generatePerformanceReportRemarks,
          ),
          const SizedBox(height: 16),
        ],
        PerformanceReportRatings(
          rows: controller.ratingRows,
          categoryTabs: report.categoryTabs,
          selectedCategoryIndex: controller.selectedCategoryIndex,
          onCategorySelected: controller.selectCategory,
          onDescriptionGo: onDescriptionGo,
        ),
        const SizedBox(height: 16),
        PerformanceReportPaygradePipelineSection(
          report: report,
          onTap: () => showPerformanceReportPaygradePipelineSheet(
            context,
            report: report,
            currentStep: viewData.currentPaygradeStep,
          ),
        ),
        if (report.coreValues.isNotEmpty) ...[
          const SizedBox(height: 16),
          PerformanceReportCoreValuesCard(
            values: report.coreValues,
            isExpanded: controller.isCoreValuesExpanded,
            onToggle: controller.toggleCoreValues,
          ),
        ],
        if (!isMyReport) ...[
          const SizedBox(height: 16),
          PerformanceReportCommitmentSection(
            controller: controller,
            report: report,
            onEmployeeSignature: onEmployeeSignature,
            onFacilitatorSignature: onFacilitatorSignature,
            onCertify: onCertify,
          ),
        ],
      ],
    );
  }
}

class _ReportFilters extends StatelessWidget {
  const _ReportFilters({
    required this.controller,
    required this.onDateRangePressed,
    required this.onHistoryPressed,
  });

  final PerformanceReportController controller;
  final VoidCallback onDateRangePressed;
  final VoidCallback onHistoryPressed;

  @override
  Widget build(BuildContext context) {
    final state = controller.state;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Expanded(
            child: PerformanceReportTimeRangeSelector(
              label: controller.dateRangeLabel,
              onTap: state.isPerformanceReportLoading ? null : onDateRangePressed,
            ),
          ),
          const SizedBox(width: 8),
          PerformanceReportHistoryButton(
            onPressed: state.isPerformanceReportLoading ? null : onHistoryPressed,
          ),
        ],
      ),
    );
  }
}
