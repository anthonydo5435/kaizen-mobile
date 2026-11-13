import 'dart:typed_data';

import '../../domain/entities/audit_member_status.dart';
import '../../domain/entities/audit_details.dart';
import '../../domain/entities/audit_evaluation_chart.dart';
import '../../domain/entities/audit_main_list.dart';
import '../../domain/entities/performance_report.dart';
import '../../domain/entities/quarterly_audit.dart';

class CheckInState {
  const CheckInState({
    this.isLoading = true,
    this.isOwner = true,
    this.isActualOwner = false,
    this.isSelfAudit = false,
    this.mainList,
    this.isLoadingMore = false,
    this.isAuditActionLoading = false,
    this.details,
    this.quarterlyAudit,
    this.quarterlyAuditDate,
    this.evaluationCharts = const <AuditEvaluationChart>[],
    this.isEvaluationChartLoading = false,
    this.selectedStatus = AuditMemberStatus.active,
    this.searchQuery = '',
    this.selectedYearQuarter,
    this.selectedSeatProfile,
    this.selectedAuditYear,
    this.selectedAuditQuarter,
    this.performanceReport,
    this.isPerformanceReportLoading = false,
    this.isGeneratingPerformanceReportRemarks = false,
    this.performanceReportTimeRange = 'This Quarter',
    this.performanceReportStartDate,
    this.performanceReportEndDate,
    this.performanceReportCommitment = '',
    this.certifiedReportOptions = const <CertifiedReportOption>[],
    this.selectedCertifiedReportUuid,
    this.employeeSignatureBytes,
    this.employeeSignatureImageId,
    this.facilitatorSignatureBytes,
    this.facilitatorSignatureImageId,
    this.isFacilitatorSignatureUploading = false,
    this.downloadingCertifiedReportUuids = const <String>{},
    this.selectedQuarterlyAuditDescriptionUuid,
    this.selectedAuditDetailsProfileUuid,
    this.favoriteUpdatingProfileJobs = const <String>{},
  });

  final bool isLoading;
  final bool isOwner;
  final bool isActualOwner;
  final bool isSelfAudit;
  final AuditMainList? mainList;
  final bool isLoadingMore;
  final bool isAuditActionLoading;
  final AuditDetails? details;
  final QuarterlyAudit? quarterlyAudit;
  final String? quarterlyAuditDate;
  final List<AuditEvaluationChart> evaluationCharts;
  final bool isEvaluationChartLoading;
  final AuditMemberStatus selectedStatus;
  final String searchQuery;
  final String? selectedYearQuarter;
  final String? selectedSeatProfile;
  final int? selectedAuditYear;
  final int? selectedAuditQuarter;
  final PerformanceReport? performanceReport;
  final bool isPerformanceReportLoading;
  final bool isGeneratingPerformanceReportRemarks;
  final String performanceReportTimeRange;
  final DateTime? performanceReportStartDate;
  final DateTime? performanceReportEndDate;
  final String performanceReportCommitment;
  final List<CertifiedReportOption> certifiedReportOptions;
  final String? selectedCertifiedReportUuid;
  final Uint8List? employeeSignatureBytes;
  final String? employeeSignatureImageId;
  final Uint8List? facilitatorSignatureBytes;
  final String? facilitatorSignatureImageId;
  final bool isFacilitatorSignatureUploading;
  final Set<String> downloadingCertifiedReportUuids;
  final String? selectedQuarterlyAuditDescriptionUuid;
  final String? selectedAuditDetailsProfileUuid;
  final Set<String> favoriteUpdatingProfileJobs;

  CheckInState copyWith({
    bool? isLoading,
    bool? isOwner,
    bool? isActualOwner,
    bool? isSelfAudit,
    AuditMainList? mainList,
    bool? isLoadingMore,
    bool? isAuditActionLoading,
    AuditDetails? details,
    QuarterlyAudit? quarterlyAudit,
    String? quarterlyAuditDate,
    List<AuditEvaluationChart>? evaluationCharts,
    bool? isEvaluationChartLoading,
    AuditMemberStatus? selectedStatus,
    String? searchQuery,
    String? selectedYearQuarter,
    String? selectedSeatProfile,
    int? selectedAuditYear,
    int? selectedAuditQuarter,
    PerformanceReport? performanceReport,
    bool? isPerformanceReportLoading,
    bool? isGeneratingPerformanceReportRemarks,
    String? performanceReportTimeRange,
    DateTime? performanceReportStartDate,
    DateTime? performanceReportEndDate,
    String? performanceReportCommitment,
    List<CertifiedReportOption>? certifiedReportOptions,
    String? selectedCertifiedReportUuid,
    Uint8List? employeeSignatureBytes,
    String? employeeSignatureImageId,
    Uint8List? facilitatorSignatureBytes,
    String? facilitatorSignatureImageId,
    bool? isFacilitatorSignatureUploading,
    Set<String>? downloadingCertifiedReportUuids,
    String? selectedQuarterlyAuditDescriptionUuid,
    String? selectedAuditDetailsProfileUuid,
    Set<String>? favoriteUpdatingProfileJobs,
    bool clearMainList = false,
    bool clearDetails = false,
    bool clearQuarterlyAudit = false,
    bool clearEvaluationCharts = false,
    bool clearSelectedYearQuarter = false,
    bool clearSelectedSeatProfile = false,
    bool clearPerformanceReport = false,
    bool clearPerformanceReportStartDate = false,
    bool clearPerformanceReportEndDate = false,
    bool clearCertifiedReportOptions = false,
    bool clearSelectedCertifiedReportUuid = false,
    bool clearEmployeeSignatureBytes = false,
    bool clearEmployeeSignatureImageId = false,
    bool clearFacilitatorSignatureBytes = false,
    bool clearFacilitatorSignatureImageId = false,
    bool clearSelectedQuarterlyAuditDescription = false,
    bool clearSelectedAuditDetailsProfileUuid = false,
  }) {
    return CheckInState(
      isLoading: isLoading ?? this.isLoading,
      isOwner: isOwner ?? this.isOwner,
      isActualOwner: isActualOwner ?? this.isActualOwner,
      isSelfAudit: isSelfAudit ?? this.isSelfAudit,
      mainList: clearMainList ? null : mainList ?? this.mainList,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      isAuditActionLoading: isAuditActionLoading ?? this.isAuditActionLoading,
      details: clearDetails ? null : details ?? this.details,
      quarterlyAudit: clearQuarterlyAudit
          ? null
          : quarterlyAudit ?? this.quarterlyAudit,
      quarterlyAuditDate: clearQuarterlyAudit
          ? null
          : quarterlyAuditDate ?? this.quarterlyAuditDate,
      evaluationCharts: clearEvaluationCharts
          ? const <AuditEvaluationChart>[]
          : evaluationCharts ?? this.evaluationCharts,
      isEvaluationChartLoading:
          isEvaluationChartLoading ?? this.isEvaluationChartLoading,
      selectedStatus: selectedStatus ?? this.selectedStatus,
      searchQuery: searchQuery ?? this.searchQuery,
      selectedYearQuarter: clearSelectedYearQuarter
          ? null
          : selectedYearQuarter ?? this.selectedYearQuarter,
      selectedSeatProfile: clearSelectedSeatProfile
          ? null
          : selectedSeatProfile ?? this.selectedSeatProfile,
      selectedAuditYear: selectedAuditYear ?? this.selectedAuditYear,
      selectedAuditQuarter: selectedAuditQuarter ?? this.selectedAuditQuarter,
      performanceReport: clearPerformanceReport
          ? null
          : performanceReport ?? this.performanceReport,
      isPerformanceReportLoading:
          isPerformanceReportLoading ?? this.isPerformanceReportLoading,
      isGeneratingPerformanceReportRemarks:
          isGeneratingPerformanceReportRemarks ??
          this.isGeneratingPerformanceReportRemarks,
      performanceReportTimeRange:
          performanceReportTimeRange ?? this.performanceReportTimeRange,
      performanceReportStartDate: clearPerformanceReportStartDate
          ? null
          : performanceReportStartDate ?? this.performanceReportStartDate,
      performanceReportEndDate: clearPerformanceReportEndDate
          ? null
          : performanceReportEndDate ?? this.performanceReportEndDate,
      performanceReportCommitment:
          performanceReportCommitment ?? this.performanceReportCommitment,
      certifiedReportOptions: clearCertifiedReportOptions
          ? const <CertifiedReportOption>[]
          : certifiedReportOptions ?? this.certifiedReportOptions,
      selectedCertifiedReportUuid: clearSelectedCertifiedReportUuid
          ? null
          : selectedCertifiedReportUuid ?? this.selectedCertifiedReportUuid,
      employeeSignatureBytes: clearEmployeeSignatureBytes
          ? null
          : employeeSignatureBytes ?? this.employeeSignatureBytes,
      employeeSignatureImageId: clearEmployeeSignatureImageId
          ? null
          : employeeSignatureImageId ?? this.employeeSignatureImageId,
      facilitatorSignatureBytes: clearFacilitatorSignatureBytes
          ? null
          : facilitatorSignatureBytes ?? this.facilitatorSignatureBytes,
      facilitatorSignatureImageId: clearFacilitatorSignatureImageId
          ? null
          : facilitatorSignatureImageId ?? this.facilitatorSignatureImageId,
      isFacilitatorSignatureUploading:
          isFacilitatorSignatureUploading ??
          this.isFacilitatorSignatureUploading,
      downloadingCertifiedReportUuids:
          downloadingCertifiedReportUuids ??
          this.downloadingCertifiedReportUuids,
      selectedQuarterlyAuditDescriptionUuid:
          clearSelectedQuarterlyAuditDescription
          ? null
          : selectedQuarterlyAuditDescriptionUuid ??
                this.selectedQuarterlyAuditDescriptionUuid,
      selectedAuditDetailsProfileUuid: clearSelectedAuditDetailsProfileUuid
          ? null
          : selectedAuditDetailsProfileUuid ??
                this.selectedAuditDetailsProfileUuid,
      favoriteUpdatingProfileJobs:
          favoriteUpdatingProfileJobs ?? this.favoriteUpdatingProfileJobs,
    );
  }
}
