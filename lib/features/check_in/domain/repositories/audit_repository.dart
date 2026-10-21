import '../entities/audit_description_audit.dart';
import '../entities/description_comments_response.dart';
import '../entities/audit_details.dart';
import '../entities/audit_evaluation_chart.dart';
import '../entities/audit_list.dart';
import '../entities/audit_main_list.dart';
import '../entities/audit_job_option.dart';
import '../entities/audit_profile.dart';
import '../entities/performance_report.dart';
import '../entities/quarterly_audit.dart';
import '../entities/seat_description_audit_report_comments.dart';
import '../entities/seat_description_final_audit_report.dart';
import '../entities/single_audit_report_category_details.dart';

abstract class AuditRepository {
  Future<AuditMainList> getAuditMainList({
    required int page,
    required int pageSize,
    required int year,
    required int quarter,
    String? search,
    String? jobUuid,
    bool forceRefresh = false,
  });

  Future<AuditMainList> getAuditTeamMembers({
    required int page,
    required int pageSize,
    int? year,
    int? quarter,
    String? search,
  });

  Future<AuditMainList> getMyAudits({
    required int page,
    required int pageSize,
    int? year,
    int? quarter,
    String? search,
    bool forceRefresh = false,
  });

  Future<dynamic> getMyPerformanceSnapshot({
    required int page,
    required int pageSize,
    String? search,
    bool forceRefresh = false,
  });

  Future<dynamic> getPerformanceSnapshot({
    required int page,
    required int pageSize,
    String? search,
    bool forceRefresh = false,
  });

  Future<List<String>> getSubordinateJobTitles();

  Future<List<AuditJobOption>> getSubordinateJobOptions();

  Future<PerformanceReport> getPerformanceReportOverview({
    required AuditProfile profile,
    int? year,
    int? quarter,
    DateTime? startDate,
    DateTime? endDate,
  });

  Future<Map<String, String>> getPerformanceReportRemarks({
    required AuditProfile profile,
    int? year,
    int? quarter,
    DateTime? startDate,
    DateTime? endDate,
  });

  Future<List<CertifiedReportOption>> getCertifiedReports({
    required AuditProfile profile,
    int? year,
    int? quarter,
    DateTime? startDate,
    DateTime? endDate,
  });

  Future<CertifiedReportDetail> getCertifiedReportDetail({
    required String certifiedReportUuid,
    required AuditProfile fallbackProfile,
  });

  Future<String> getCertifiedReportPdfUrl({
    required String certifiedReportUuid,
  });

  Future<String?> certifyPerformanceReport({
    required String profileJobId,
    required Map<String, dynamic> payload,
  });

  Future<AuditDetails> getAuditDetails({
    required String profileJobId,
    required int year,
    required int quarter,
    String? profileUuid,
  });

  Future<List<AuditEvaluationChart>> getAuditEvaluationChart({
    required String profileJobId,
    String? profileUuid,
  });

  Future<List<AuditList>> getAuditReport({
    required int quarter,
    required int year,
    required String profileJobId,
  });

  Future<List<SingleAuditReportCategoryDetails>> getAuditReportCategoryDetails({
    required String categoryId,
    required int quarter,
    required int year,
  });

  Future<SeatDescriptionFinalAuditReport> getSeatDescriptionFinalAuditReport({
    required String flowFirstId,
    String? profileUuid,
    required String descriptionId,
    int? quarter,
    int? year,
    String? timeRange,
  });

  Future<SeatDescriptionAuditReportComments>
  getSeatDescriptionAuditReportComments({
    required String flowFirstId,
    String? profileUuid,
    required String descriptionId,
    int? quarter,
    int? year,
    String? timeRange,
  });

  Future<List<SeatDescriptionFinalAuditProfile>>
  getSeatDescriptionAuditReportProfiles({
    required String flowFirstId,
    String? profileUuid,
    required String descriptionId,
    int? quarter,
    int? year,
    String? timeRange,
  });

  Future<QuarterlyAudit> getQuarterlyAudit({
    required String quarterlyAuditId,
    required String date,
  });

  Future<AuditDescriptionAudit> getAuditDescriptionAudit({
    required String quarterlyAuditId,
    required String descriptionId,
    required String date,
  });

  Future<AuditDescriptionAudit> submitDescriptionAudit({
    required String descriptionId,
    required Map<String, int> audit,
  });

  Future<String> generateAuditDescriptionMediaUploadUrl({
    required String fileName,
  });

  Future<void> uploadAuditDescriptionMediaFile({
    required String uploadUrl,
    required String fileName,
    required List<int> fileBytes,
    required String contentType,
  });

  Future<void> createAuditDescriptionMedia({
    required String descriptionId,
    required String comment,
    String? mediaUrl,
    String? mediaType,
  });

  Future<void> updateAuditMedia({
    required String auditMediaId,
    required String mediaUrl,
    required String mediaType,
  });

  Future<DescriptionCommentsResponse> getDescriptionComments({
    required String auditMediaId,
  });

  Future<CommentAdditionResponse> addComment({
    required String auditMediaId,
    required String comment,
    String? parent,
  });

  Future<void> deleteAuditMedia({required String auditMediaId});

  Future<void> createAuditDescriptionComment({
    required String descriptionId,
    required String comment,
  });

  Future<String> uploadPerformanceReportSignatureImage({
    required String fileName,
    required List<int> fileBytes,
    required String contentType,
  });

  Future<void> markFavoriteSubordinate({required String profileJobId});

  Future<void> markUnfavoriteSubordinate({required String profileJobId});
}
