import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/widgets/app_text_view.dart';
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
    required this.onTimeRangeChanged,
    required this.onDescriptionGo,
    required this.onEmployeeSignature,
    required this.onFacilitatorSignature,
    required this.onCertify,
  });

  final PerformanceReportController controller;
  final PerformanceReport report;
  final PerformanceReportViewData viewData;
  final bool isMyReport;
  final ValueChanged<String> onTimeRangeChanged;
  final ValueChanged<PerformanceReportRatingRow> onDescriptionGo;
  final VoidCallback onEmployeeSignature;
  final VoidCallback onFacilitatorSignature;
  final VoidCallback onCertify;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(8, 10, 8, 24),
      child: Column(
        children: [
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
          if (viewData.isOpenSeatView)
            PerformanceReportOpenSeatView(message: viewData.reportMessage)
          else if (viewData.shouldShowCompleteReportUi)
            _buildCompleteReport(context)
          else if (viewData.shouldShowMessageOnly &&
              viewData.reportMessage != null)
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

  Widget _buildCompleteReport(BuildContext context) {
    final auditController = controller.checkInController;
    return Column(
      children: [
        _ReportFilters(
          controller: controller,
          onTimeRangeChanged: onTimeRangeChanged,
        ),
        if (report.hasPersonalityData) ...[
          PerformanceReportPersonaCard(
            report: report,
            showPersonaHeader: controller.state.isOwner,
            showGenerateRemarksAction: controller.canGenerateRemarks,
            isGeneratingRemarks:
                controller.state.isGeneratingPerformanceReportRemarks,
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
    required this.onTimeRangeChanged,
  });

  final PerformanceReportController controller;
  final ValueChanged<String> onTimeRangeChanged;

  @override
  Widget build(BuildContext context) {
    final state = controller.state;
    final auditController = controller.checkInController;
    final formatDate = MaterialLocalizations.of(context).formatShortDate;
    final start = state.performanceReportStartDate;
    final end = state.performanceReportEndDate;
    final hasCustomRange =
        state.performanceReportTimeRange ==
            AppStrings.performanceReportCustomDateRange &&
        start != null &&
        end != null;
    return Column(
      children: [
        PerformanceReportTimeRangeSelector(
          value: state.performanceReportTimeRange,
          options: PerformanceReportController.timeRanges,
          customRangeLabel: hasCustomRange
              ? '${formatDate(start)} - ${formatDate(end)}'
              : null,
          onChanged: onTimeRangeChanged,
        ),
        const SizedBox(height: 12),
        if (state.certifiedReportOptions.isNotEmpty) ...[
          PerformanceReportCertifiedReportsSelector(
            value: state.selectedCertifiedReportUuid,
            options: state.certifiedReportOptions,
            isDownloading: auditController.isCertifiedReportPdfDownloading,
            onChanged: auditController.selectCertifiedReport,
            onDownload: (option) =>
                auditController.downloadCertifiedReportPdf(option.uuid),
          ),
          const SizedBox(height: 16),
        ],
      ],
    );
  }
}
