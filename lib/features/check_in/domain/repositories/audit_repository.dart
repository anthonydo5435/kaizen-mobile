import '../entities/audit_description_audit.dart';
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
import '../../../training/domain/entities/seat_description_training.dart';
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

  Future<List<SeatDescriptionTrainingModule>>
  getSeatDescriptionTrainingModules({
    required String descriptionId,
    bool forceRefresh = false,
  });

  Future<SeatDescriptionTrainingModule> createSeatDescriptionTrainingModule({
    required String jobId,
    required String descriptionId,
    required String title,
  });

  Future<SeatDescriptionTrainingModuleDetail>
  getSeatDescriptionTrainingModuleDetail({
    required String moduleId,
    bool forceRefresh = false,
  });

  Future<SeatDescriptionTrainingDocument>
  getSeatDescriptionTrainingModuleDocument({required String moduleId});

  Future<SeatDescriptionTrainingAssignment>
  getSeatDescriptionTrainingModuleAssignment({required String moduleId});

  Future<List<SeatDescriptionTrainingQuestion>>
  getSeatDescriptionTrainingModuleQuestions({required String moduleId});

  Future<SeatDescriptionTrainingQuestion> addSeatDescriptionTrainingQuestion({
    required String moduleId,
    required String questionText,
    required List<SeatDescriptionTrainingQuestionOption> options,
    required String correctOptionUuid,
    String? imageId,
  });

  /// Returns the uploaded image UUID to attach when creating a quiz question.
  Future<String> uploadTrainingQuestionImage({
    required String fileName,
    required List<int> fileBytes,
    required String contentType,
  });

  Future<void> generateSeatDescriptionTrainingModuleQuiz({
    required String moduleId,
    required int numQuestions,
    required int optionsPerQuestion,
    required String difficultyLevel,
    required bool replaceExistingQuestions,
  });

  Future<void> generateSeatDescriptionTrainingModuleSop({
    required String moduleId,
  });

  Future<void> generateSeatDescriptionTrainingModuleAssignment({
    required String moduleId,
  });

  Future<String?> generateSeatDescriptionTrainingModuleSummary({
    required String moduleId,
  });

  Future<void> updateSeatDescriptionTrainingModule({
    required String moduleId,
    String? title,
    String? description,
  });

  Future<void> updateSeatDescriptionTrainingModuleSummary({
    required String moduleId,
    required String description,
    required bool isPubliclyAvailable,
  });

  Future<void> updateSeatDescriptionTrainingModuleVisibility({
    required String moduleId,
    required bool isPubliclyAvailable,
  });

  Future<void> updateSeatDescriptionTrainingModuleDocument({
    required String moduleId,
    required String documentId,
    required String text,
  });

  Future<void> updateSeatDescriptionTrainingModuleAssignment({
    required String moduleId,
    String? assignmentId,
    String? title,
    required String instructions,
  });

  Future<String> generateSeatDescriptionTrainingModuleVideoUploadUrl({
    required String fileName,
  });

  Future<void> uploadSeatDescriptionTrainingModuleVideoFile({
    required String uploadUrl,
    required String fileName,
    required List<int> fileBytes,
    required String contentType,
  });

  Future<SeatDescriptionTrainingVideo> addSeatDescriptionTrainingModuleVideo({
    required String moduleId,
    required String videoUuid,
    required String title,
    required String videoUrl,
    required int duration,
  });

  Future<void> deleteSeatDescriptionTrainingModuleVideo({
    required String videoId,
  });

  Future<void> updateSeatDescriptionTrainingModuleThumbnail({
    required String moduleId,
    required String thumbnailUrl,
  });

  Future<void> deleteSeatDescriptionTrainingModule({required String moduleId});

  Future<SeatDescriptionTrainingQuestion>
  updateSeatDescriptionTrainingQuestion({
    required String questionId,
    required String questionText,
    required List<SeatDescriptionTrainingQuestionOption> options,
    String? correctOptionUuid,
  });

  Future<void> deleteSeatDescriptionTrainingQuestion({
    required String questionId,
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
