import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/utils/custom_functions.dart';
import '../../../../core/widgets/app_text_view.dart';
import '../../../../core/widgets/fast_circular_progress.dart';
import '../../data/datasources/audit_remote_data_source.dart';
import '../../data/repositories/audit_repository_impl.dart';
import '../../domain/entities/audit_profile.dart';
import '../../domain/entities/performance_report.dart';
import '../../domain/usecases/get_audit_overview_usecase.dart';
import '../providers/check_in_controller.dart';
import '../providers/performance_report_controller.dart';
import '../widgets/performance_report_content.dart';
import 'performance_report_dialogs.dart';
import 'seat_description_final_check_in_report.dart';

class PerformanceReportScreen extends StatelessWidget {
  const PerformanceReportScreen({super.key, required this.profile, this.isMyReport = false});
  final AuditProfile profile;
  final bool isMyReport;
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<AuditRemoteDataSource>(create: (_) => createAuditRemoteDataSource()),
        ProxyProvider<AuditRemoteDataSource, AuditRepositoryImpl>(
          update: (_, remoteDataSource, __) => createAuditRepository(remoteDataSource),
        ),
        ProxyProvider<AuditRepositoryImpl, GetAuditOverviewUseCase>(
          update: (_, repository, __) => createGetAuditOverviewUseCase(repository),
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
          create: (context) =>
              PerformanceReportController(checkInController: context.read<CheckInController>())
                ..loadAccess(),
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
      body: SafeArea(top: false, bottom: false, child: _buildBody(context, controller)),
    );
  }

  Widget _buildBody(BuildContext context, PerformanceReportController controller) {
    if (controller.state.isPerformanceReportLoading) {
      return const FastCircularProgressIndicator();
    }
    final report = controller.report;
    final viewData = controller.viewData;
    if (report == null || viewData == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 24),
          child: AppTextView.body(
            AppStrings.performanceReportUnavailable,
            color: AppColors.textSecondary,
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return PerformanceReportContent(
      controller: controller,
      report: report,
      viewData: viewData,
      isMyReport: isMyReport,
      onTimeRangeChanged: (value) => _changeTimeRange(context, controller, value),
      onDescriptionGo: (row) => _openFinalReport(context, controller, report, row),
      onEmployeeSignature: () => showPerformanceReportSignatureDialog(
        context,
        title: AppStrings.performanceReportEmployeeSignature,
        existingSignatureUrl: report.selectedProfileSignatureUrl,
        onSaved: controller.checkInController.saveEmployeeSignature,
      ),
      onFacilitatorSignature: () => _addFacilitatorSignature(context, controller),
      onCertify: () => _certify(context, controller),
    );
  }

  Future<void> _changeTimeRange(
    BuildContext context,
    PerformanceReportController controller,
    String value,
  ) async {
    final auditController = controller.checkInController;
    if (value == AppStrings.performanceReportThisQuarter) {
      await auditController.selectPerformanceReportTimeRange(value);
      return;
    }
    final now = DateTime.now();
    final localizations = MaterialLocalizations.of(context);
    final result = await showPerformanceReportTimeRangeDialog(
      context,
      startDate: controller.state.performanceReportStartDate,
      endDate: controller.state.performanceReportEndDate,
      minDate: controller.minDate,
      maxDate: DateTime(now.year, now.month, now.day),
      formatDate: localizations.formatShortDate,
    );
    if (!context.mounted || result == null) return;
    if (result == PerformanceReportTimeRangeDialogResult.thisQuarter) {
      await auditController.selectPerformanceReportTimeRange(
        AppStrings.performanceReportThisQuarter,
      );
    } else if (result is DateTimeRange) {
      await auditController.applyPerformanceReportCustomDateRange(
        startDate: result.start,
        endDate: result.end,
      );
    }
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

  Future<void> _certify(BuildContext context, PerformanceReportController controller) async {
    final message = await controller.checkInController.certifyPerformanceReport();
    if (!context.mounted) return;
    if (message != AppStrings.performanceReportCertifiedSuccessfully) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
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
