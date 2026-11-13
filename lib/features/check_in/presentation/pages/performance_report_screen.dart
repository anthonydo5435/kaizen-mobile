import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/utils/custom_functions.dart';
import '../../../../core/widgets/app_text_view.dart';
import '../../data/datasources/audit_remote_data_source.dart';
import '../../data/repositories/audit_repository_impl.dart';
import '../../domain/entities/audit_profile.dart';
import '../../domain/entities/performance_report.dart';
import '../../domain/usecases/get_audit_overview_usecase.dart';
import '../providers/check_in_controller.dart';
import '../providers/performance_report_controller.dart';
import '../widgets/performance_report_content.dart';
import 'performance_report_certified_reports_sheet.dart';
import 'performance_report_dialogs.dart';
import 'seat_description_final_check_in_report.dart';

class PerformanceReportScreen extends StatelessWidget {
  const PerformanceReportScreen({
    super.key,
    required this.profile,
    this.isMyReport = false,
  });
  final AuditProfile profile;
  final bool isMyReport;
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<AuditRemoteDataSource>(
          create: (_) => createAuditRemoteDataSource(),
        ),
        ProxyProvider<AuditRemoteDataSource, AuditRepositoryImpl>(
          update: (_, remoteDataSource, __) =>
              createAuditRepository(remoteDataSource),
        ),
        ProxyProvider<AuditRepositoryImpl, GetAuditOverviewUseCase>(
          update: (_, repository, __) =>
              createGetAuditOverviewUseCase(repository),
        ),
        ChangeNotifierProvider<CheckInController>(
          create: (context) => CheckInController(
            context.read<GetAuditOverviewUseCase>(),
            null,
            null,
            null,
            null,
            null,
            null,
            context.read<AuditRepositoryImpl>(),
          )..initializePerformanceReport(profile),
        ),
        ChangeNotifierProvider<PerformanceReportController>(
          create: (context) => PerformanceReportController(
            checkInController: context.read<CheckInController>(),
          )..loadAccess(),
        ),
      ],
      child: PerformanceReportView(isMyReport: isMyReport),
    );
  }
}

/// Displays the report using its provided presentation controller.
class PerformanceReportView extends StatelessWidget {
  const PerformanceReportView({super.key, this.isMyReport = false});

  final bool isMyReport;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<PerformanceReportController>();
    return Scaffold(
      backgroundColor: AppColors.mainBg,
      appBar: AppBar(
        backgroundColor: AppColors.mainBg,
        foregroundColor: AppColors.textPrimary,
        centerTitle: true,
        leadingWidth: 40,
        title: AppTextView.title1(
          AppStrings.reportsScreenTitle,
          color: AppColors.secondaryColor,
          fontWeight: FontWeight.w500,
        ),
      ),
      body: SafeArea(
        top: false,
        bottom: false,
        child: _buildBody(context, controller),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    PerformanceReportController controller,
  ) {
    final report = controller.report;
    final viewData = controller.viewData;
    return PerformanceReportContent(
      controller: controller,
      report: report,
      viewData: viewData,
      isMyReport: isMyReport,
      onDateRangePressed: () => _changeTimeRange(context, controller),
      onHistoryPressed: () => _openHistory(context, controller),
      onDescriptionGo: (row) {
        if (report != null) _openFinalReport(context, controller, report, row);
      },
      onEmployeeSignature: () => showPerformanceReportSignatureDialog(
        context,
        title: AppStrings.performanceReportEmployeeSignature,
        existingSignatureUrl: report?.selectedProfileSignatureUrl,
        onSaved: controller.checkInController.saveEmployeeSignature,
      ),
      onFacilitatorSignature: () =>
          _addFacilitatorSignature(context, controller),
      onCertify: () => _certify(context, controller),
    );
  }

  Future<void> _openHistory(
    BuildContext context,
    PerformanceReportController controller,
  ) {
    final auditController = controller.checkInController;
    final today = controller.currentQuarterRange.end;
    return showPerformanceReportCertifiedReportsSheet(
      context,
      value: controller.state.selectedCertifiedReportUuid,
      options: controller.state.certifiedReportOptions,
      minDate: controller.minDate,
      maxDate: today,
      loadReports: (range) => auditController.loadPerformanceReportHistory(
        startDate: range?.start,
        endDate: range?.end,
      ),
      isDownloading: auditController.isCertifiedReportPdfDownloading,
      onChanged: auditController.selectCertifiedReport,
      onDownload: (option) =>
          auditController.downloadCertifiedReportPdf(option.uuid),
    );
  }

  Future<void> _changeTimeRange(
    BuildContext context,
    PerformanceReportController controller,
  ) async {
    final range = controller.dateRange;
    final minDate = controller.minDate;
    final localizations = MaterialLocalizations.of(context);
    final result = await showPerformanceReportTimeRangeDialog(
      context,
      startDate: range.start,
      endDate: range.end,
      minDate: minDate.isBefore(range.start) ? minDate : range.start,
      maxDate: controller.currentQuarterRange.end,
      selectStartDateInitially: true,
      calendarOnly: true,
      formatDate: localizations.formatShortDate,
    );
    if (!context.mounted || result is! DateTimeRange) return;
    await controller.selectDateRange(result);
  }

  Future<void> _addFacilitatorSignature(
    BuildContext context,
    PerformanceReportController controller,
  ) async {
    final imageUrl = await controller.loadFacilitatorSignatureUrl();
    if (!context.mounted) return;
    await showPerformanceReportSignatureDialog(
      context,
      title: AppStrings.performanceReportFacilitatorSignature,
      existingSignatureUrl: imageUrl,
      onSaved: controller.checkInController.saveFacilitatorSignature,
    );
  }

  Future<void> _certify(
    BuildContext context,
    PerformanceReportController controller,
  ) async {
    final message = await controller.checkInController
        .certifyPerformanceReport();
    if (!context.mounted) return;
    if (message != AppStrings.performanceReportCertifiedSuccessfully) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _openFinalReport(
    BuildContext context,
    PerformanceReportController controller,
    PerformanceReport report,
    PerformanceReportRatingRow row,
  ) {
    final currentYearQuarter = CustomFunctions.currentYearQuarter();
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ChangeNotifierProvider<CheckInController>.value(
          value: controller.checkInController,
          child: SeatDescriptionFinalCheckInReportScreen(
            flowFirstId: report.profile.profileJob,
            profileUuid: report.profile.profileUuid,
            descriptionId: row.descriptionUuid,
            quarter: currentYearQuarter.quarter,
            year: currentYearQuarter.year,
          ),
        ),
      ),
    );
  }
}
