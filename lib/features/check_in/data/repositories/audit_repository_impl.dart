import '../../../training/domain/entities/seat_description_training.dart';
import '../../domain/entities/audit_description_audit.dart';
import '../../domain/entities/audit_details.dart';
import '../../domain/entities/audit_evaluation_chart.dart';
import '../../domain/entities/audit_list.dart';
import '../../domain/entities/audit_main_list.dart';
import '../../domain/entities/audit_job_option.dart';
import '../../domain/entities/audit_profile.dart';
import '../../domain/entities/performance_report.dart';
import '../../domain/entities/quarterly_audit.dart';
import '../../domain/entities/seat_description_audit_report_comments.dart';
import '../../domain/entities/seat_description_final_audit_report.dart';
import '../../domain/entities/single_audit_report_category_details.dart';
import '../../domain/repositories/audit_repository.dart';
import '../datasources/audit_remote_data_source.dart';

class AuditRepositoryImpl implements AuditRepository {
  const AuditRepositoryImpl(this._remoteDataSource);

  final AuditRemoteDataSource _remoteDataSource;

  @override
  Future<AuditMainList> getAuditMainList({
    required int page,
    required int pageSize,
    required int year,
    required int quarter,
    String? search,
    String? jobUuid,
    bool forceRefresh = false,
  }) {
    return _remoteDataSource.getAuditMainList(
      page: page,
      pageSize: pageSize,
      year: year,
      quarter: quarter,
      search: search,
      jobUuid: jobUuid,
      forceRefresh: forceRefresh,
    );
  }

  @override
  Future<AuditMainList> getAuditTeamMembers({
    required int page,
    required int pageSize,
    int? year,
    int? quarter,
    String? search,
  }) {
    return _remoteDataSource.getAuditTeamMembers(
      page: page,
      pageSize: pageSize,
      year: year,
      quarter: quarter,
      search: search,
    );
  }

  @override
  Future<AuditMainList> getMyAudits({
    required int page,
    required int pageSize,
    int? year,
    int? quarter,
    String? search,
    bool forceRefresh = false,
  }) {
    return _remoteDataSource.getMyAudits(
      page: page,
      pageSize: pageSize,
      year: year,
      quarter: quarter,
      search: search,
      forceRefresh: forceRefresh,
    );
  }

  @override
  Future<dynamic> getMyPerformanceSnapshot({
    required int page,
    required int pageSize,
    String? search,
    bool forceRefresh = false,
  }) {
    return _remoteDataSource.getMyPerformanceSnapshot(
      page: page,
      pageSize: pageSize,
      search: search,
      forceRefresh: forceRefresh,
    );
  }

  @override
  Future<dynamic> getPerformanceSnapshot({
    required int page,
    required int pageSize,
    String? search,
    bool forceRefresh = false,
  }) {
    return _remoteDataSource.getPerformanceSnapshot(
      page: page,
      pageSize: pageSize,
      search: search,
      forceRefresh: forceRefresh,
    );
  }

  @override
  Future<List<String>> getSubordinateJobTitles() {
    return _remoteDataSource.getSubordinateJobTitles();
  }

  @override
  Future<List<AuditJobOption>> getSubordinateJobOptions() {
    return _remoteDataSource.getSubordinateJobOptions();
  }

  @override
  Future<PerformanceReport> getPerformanceReportOverview({
    required AuditProfile profile,
    int? year,
    int? quarter,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    return _remoteDataSource.getPerformanceReportOverview(
      profile: profile,
      year: year,
      quarter: quarter,
      startDate: startDate,
      endDate: endDate,
    );
  }

  @override
  Future<Map<String, String>> getPerformanceReportRemarks({
    required AuditProfile profile,
    int? year,
    int? quarter,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    return _remoteDataSource.getPerformanceReportRemarks(
      profile: profile,
      year: year,
      quarter: quarter,
      startDate: startDate,
      endDate: endDate,
    );
  }

  @override
  Future<List<CertifiedReportOption>> getCertifiedReports({
    required AuditProfile profile,
    int? year,
    int? quarter,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    return _remoteDataSource.getCertifiedReports(
      profile: profile,
      year: year,
      quarter: quarter,
      startDate: startDate,
      endDate: endDate,
    );
  }

  @override
  Future<CertifiedReportDetail> getCertifiedReportDetail({
    required String certifiedReportUuid,
    required AuditProfile fallbackProfile,
  }) {
    return _remoteDataSource.getCertifiedReportDetail(
      certifiedReportUuid: certifiedReportUuid,
      fallbackProfile: fallbackProfile,
    );
  }

  @override
  Future<String> getCertifiedReportPdfUrl({
    required String certifiedReportUuid,
  }) {
    return _remoteDataSource.getCertifiedReportPdfUrl(
      certifiedReportUuid: certifiedReportUuid,
    );
  }

  @override
  Future<String?> certifyPerformanceReport({
    required String profileJobId,
    required Map<String, dynamic> payload,
  }) {
    return _remoteDataSource.certifyPerformanceReport(
      profileJobId: profileJobId,
      payload: payload,
    );
  }

  @override
  Future<AuditDetails> getAuditDetails({
    required String profileJobId,
    required int year,
    required int quarter,
    String? profileUuid,
  }) {
    return _remoteDataSource.getAuditDetails(
      profileJobId: profileJobId,
      year: year,
      quarter: quarter,
      profileUuid: profileUuid,
    );
  }

  @override
  Future<List<AuditEvaluationChart>> getAuditEvaluationChart({
    required String profileJobId,
    String? profileUuid,
  }) {
    return _remoteDataSource.getAuditEvaluationChart(
      profileJobId: profileJobId,
      profileUuid: profileUuid,
    );
  }

  @override
  Future<List<AuditList>> getAuditReport({
    required int quarter,
    required int year,
    required String profileJobId,
  }) {
    return _remoteDataSource.getAuditReport(
      quarter: quarter,
      year: year,
      profileJobId: profileJobId,
    );
  }

  @override
  Future<List<SingleAuditReportCategoryDetails>> getAuditReportCategoryDetails({
    required String categoryId,
    required int quarter,
    required int year,
  }) {
    return _remoteDataSource.getAuditReportCategoryDetails(
      categoryId: categoryId,
      quarter: quarter,
      year: year,
    );
  }

  @override
  Future<SeatDescriptionFinalAuditReport> getSeatDescriptionFinalAuditReport({
    required String flowFirstId,
    String? profileUuid,
    required String descriptionId,
    int? quarter,
    int? year,
    String? timeRange,
  }) {
    return _remoteDataSource.getSeatDescriptionFinalAuditReport(
      flowFirstId: flowFirstId,
      profileUuid: profileUuid,
      descriptionId: descriptionId,
      quarter: quarter,
      year: year,
      timeRange: timeRange,
    );
  }

  @override
  Future<SeatDescriptionAuditReportComments>
  getSeatDescriptionAuditReportComments({
    required String flowFirstId,
    String? profileUuid,
    required String descriptionId,
    int? quarter,
    int? year,
    String? timeRange,
  }) {
    return _remoteDataSource.getSeatDescriptionAuditReportComments(
      flowFirstId: flowFirstId,
      profileUuid: profileUuid,
      descriptionId: descriptionId,
      quarter: quarter,
      year: year,
      timeRange: timeRange,
    );
  }

  @override
  Future<List<SeatDescriptionFinalAuditProfile>>
  getSeatDescriptionAuditReportProfiles({
    required String flowFirstId,
    String? profileUuid,
    required String descriptionId,
    int? quarter,
    int? year,
    String? timeRange,
  }) {
    return _remoteDataSource.getSeatDescriptionAuditReportProfiles(
      flowFirstId: flowFirstId,
      profileUuid: profileUuid,
      descriptionId: descriptionId,
      quarter: quarter,
      year: year,
      timeRange: timeRange,
    );
  }

  @override
  Future<List<SeatDescriptionTrainingModule>>
  getSeatDescriptionTrainingModules({
    required String descriptionId,
    bool forceRefresh = false,
  }) {
    return _remoteDataSource.getSeatDescriptionTrainingModules(
      descriptionId: descriptionId,
      forceRefresh: forceRefresh,
    );
  }

  @override
  Future<SeatDescriptionTrainingModule> createSeatDescriptionTrainingModule({
    required String jobId,
    required String descriptionId,
    required String title,
  }) {
    return _remoteDataSource.createSeatDescriptionTrainingModule(
      jobId: jobId,
      descriptionId: descriptionId,
      title: title,
    );
  }

  @override
  Future<SeatDescriptionTrainingModuleDetail>
  getSeatDescriptionTrainingModuleDetail({
    required String moduleId,
    bool forceRefresh = false,
  }) {
    return _remoteDataSource.getSeatDescriptionTrainingModuleDetail(
      moduleId: moduleId,
      forceRefresh: forceRefresh,
    );
  }

  @override
  Future<SeatDescriptionTrainingDocument>
  getSeatDescriptionTrainingModuleDocument({required String moduleId}) {
    return _remoteDataSource.getSeatDescriptionTrainingModuleDocument(
      moduleId: moduleId,
    );
  }

  @override
  Future<SeatDescriptionTrainingAssignment>
  getSeatDescriptionTrainingModuleAssignment({required String moduleId}) {
    return _remoteDataSource.getSeatDescriptionTrainingModuleAssignment(
      moduleId: moduleId,
    );
  }

  @override
  Future<List<SeatDescriptionTrainingQuestion>>
  getSeatDescriptionTrainingModuleQuestions({required String moduleId}) {
    return _remoteDataSource.getSeatDescriptionTrainingModuleQuestions(
      moduleId: moduleId,
    );
  }

  @override
  Future<SeatDescriptionTrainingQuestion> addSeatDescriptionTrainingQuestion({
    required String moduleId,
    required String questionText,
    required List<SeatDescriptionTrainingQuestionOption> options,
    required String correctOptionUuid,
    String? imageId,
  }) {
    return _remoteDataSource.addSeatDescriptionTrainingQuestion(
      moduleId: moduleId,
      questionText: questionText,
      options: options,
      correctOptionUuid: correctOptionUuid,
      imageId: imageId,
    );
  }

  @override
  Future<String> uploadTrainingQuestionImage({
    required String fileName,
    required List<int> fileBytes,
    required String contentType,
  }) {
    return _remoteDataSource.uploadTrainingQuestionImage(
      fileName: fileName,
      fileBytes: fileBytes,
      contentType: contentType,
    );
  }

  @override
  Future<void> generateSeatDescriptionTrainingModuleQuiz({
    required String moduleId,
    required int numQuestions,
    required int optionsPerQuestion,
    required String difficultyLevel,
    required bool replaceExistingQuestions,
  }) {
    return _remoteDataSource.generateSeatDescriptionTrainingModuleQuiz(
      moduleId: moduleId,
      numQuestions: numQuestions,
      optionsPerQuestion: optionsPerQuestion,
      difficultyLevel: difficultyLevel,
      replaceExistingQuestions: replaceExistingQuestions,
    );
  }

  @override
  Future<void> generateSeatDescriptionTrainingModuleSop({
    required String moduleId,
  }) {
    return _remoteDataSource.generateSeatDescriptionTrainingModuleSop(
      moduleId: moduleId,
    );
  }

  @override
  Future<void> generateSeatDescriptionTrainingModuleAssignment({
    required String moduleId,
  }) {
    return _remoteDataSource.generateSeatDescriptionTrainingModuleAssignment(
      moduleId: moduleId,
    );
  }

  @override
  Future<String?> generateSeatDescriptionTrainingModuleSummary({
    required String moduleId,
  }) {
    return _remoteDataSource.generateSeatDescriptionTrainingModuleSummary(
      moduleId: moduleId,
    );
  }

  @override
  Future<void> updateSeatDescriptionTrainingModule({
    required String moduleId,
    String? title,
    String? description,
  }) {
    return _remoteDataSource.updateSeatDescriptionTrainingModule(
      moduleId: moduleId,
      title: title,
      description: description,
    );
  }

  @override
  Future<void> updateSeatDescriptionTrainingModuleSummary({
    required String moduleId,
    required String description,
    required bool isPubliclyAvailable,
  }) {
    return _remoteDataSource.updateSeatDescriptionTrainingModuleSummary(
      moduleId: moduleId,
      description: description,
      isPubliclyAvailable: isPubliclyAvailable,
    );
  }

  @override
  Future<void> updateSeatDescriptionTrainingModuleVisibility({
    required String moduleId,
    required bool isPubliclyAvailable,
  }) {
    return _remoteDataSource.updateSeatDescriptionTrainingModuleVisibility(
      moduleId: moduleId,
      isPubliclyAvailable: isPubliclyAvailable,
    );
  }

  @override
  Future<void> updateSeatDescriptionTrainingModuleDocument({
    required String moduleId,
    required String documentId,
    required String text,
  }) {
    return _remoteDataSource.updateSeatDescriptionTrainingModuleDocument(
      moduleId: moduleId,
      documentId: documentId,
      text: text,
    );
  }

  @override
  Future<void> updateSeatDescriptionTrainingModuleAssignment({
    required String moduleId,
    String? assignmentId,
    String? title,
    required String instructions,
  }) {
    return _remoteDataSource.updateSeatDescriptionTrainingModuleAssignment(
      moduleId: moduleId,
      assignmentId: assignmentId,
      title: title,
      instructions: instructions,
    );
  }

  @override
  Future<String> generateSeatDescriptionTrainingModuleVideoUploadUrl({
    required String fileName,
  }) {
    return _remoteDataSource
        .generateSeatDescriptionTrainingModuleVideoUploadUrl(
          fileName: fileName,
        );
  }

  @override
  Future<void> uploadSeatDescriptionTrainingModuleVideoFile({
    required String uploadUrl,
    required String fileName,
    required List<int> fileBytes,
    required String contentType,
  }) {
    return _remoteDataSource.uploadSeatDescriptionTrainingModuleVideoFile(
      uploadUrl: uploadUrl,
      fileName: fileName,
      fileBytes: fileBytes,
      contentType: contentType,
    );
  }

  @override
  Future<SeatDescriptionTrainingVideo> addSeatDescriptionTrainingModuleVideo({
    required String moduleId,
    required String videoUuid,
    required String title,
    required String videoUrl,
    required int duration,
  }) {
    return _remoteDataSource.addSeatDescriptionTrainingModuleVideo(
      moduleId: moduleId,
      videoUuid: videoUuid,
      title: title,
      videoUrl: videoUrl,
      duration: duration,
    );
  }

  @override
  Future<void> deleteSeatDescriptionTrainingModuleVideo({
    required String videoId,
  }) {
    return _remoteDataSource.deleteSeatDescriptionTrainingModuleVideo(
      videoId: videoId,
    );
  }

  @override
  Future<void> updateSeatDescriptionTrainingModuleThumbnail({
    required String moduleId,
    required String thumbnailUrl,
  }) {
    return _remoteDataSource.updateSeatDescriptionTrainingModuleThumbnail(
      moduleId: moduleId,
      thumbnailUrl: thumbnailUrl,
    );
  }

  @override
  Future<void> deleteSeatDescriptionTrainingModule({required String moduleId}) {
    return _remoteDataSource.deleteSeatDescriptionTrainingModule(
      moduleId: moduleId,
    );
  }

  @override
  Future<SeatDescriptionTrainingQuestion>
  updateSeatDescriptionTrainingQuestion({
    required String questionId,
    required String questionText,
    required List<SeatDescriptionTrainingQuestionOption> options,
    String? correctOptionUuid,
  }) {
    return _remoteDataSource.updateSeatDescriptionTrainingQuestion(
      questionId: questionId,
      questionText: questionText,
      options: options,
      correctOptionUuid: correctOptionUuid,
    );
  }

  @override
  Future<void> deleteSeatDescriptionTrainingQuestion({
    required String questionId,
  }) {
    return _remoteDataSource.deleteSeatDescriptionTrainingQuestion(
      questionId: questionId,
    );
  }

  @override
  Future<QuarterlyAudit> getQuarterlyAudit({
    required String quarterlyAuditId,
    required String date,
  }) {
    return _remoteDataSource.getQuarterlyAudit(
      quarterlyAuditId: quarterlyAuditId,
      date: date,
    );
  }

  @override
  Future<AuditDescriptionAudit> getAuditDescriptionAudit({
    required String quarterlyAuditId,
    required String descriptionId,
    required String date,
  }) {
    return _remoteDataSource.getAuditDescriptionAudit(
      quarterlyAuditId: quarterlyAuditId,
      descriptionId: descriptionId,
      date: date,
    );
  }

  @override
  Future<AuditDescriptionAudit> submitDescriptionAudit({
    required String descriptionId,
    required Map<String, int> audit,
  }) {
    return _remoteDataSource.submitDescriptionAudit(
      descriptionId: descriptionId,
      audit: audit,
    );
  }

  @override
  Future<String> generateAuditDescriptionMediaUploadUrl({
    required String fileName,
  }) {
    return _remoteDataSource.generateAuditDescriptionMediaUploadUrl(
      fileName: fileName,
    );
  }

  @override
  Future<void> uploadAuditDescriptionMediaFile({
    required String uploadUrl,
    required String fileName,
    required List<int> fileBytes,
    required String contentType,
  }) {
    return _remoteDataSource.uploadAuditDescriptionMediaFile(
      uploadUrl: uploadUrl,
      fileName: fileName,
      fileBytes: fileBytes,
      contentType: contentType,
    );
  }

  @override
  Future<void> createAuditDescriptionMedia({
    required String descriptionId,
    required String comment,
    String? mediaUrl,
    String? mediaType,
  }) {
    return _remoteDataSource.createAuditDescriptionMedia(
      descriptionId: descriptionId,
      comment: comment,
      mediaUrl: mediaUrl,
      mediaType: mediaType,
    );
  }

  @override
  Future<void> updateAuditMedia({
    required String auditMediaId,
    required String mediaUrl,
    required String mediaType,
  }) {
    return _remoteDataSource.updateAuditMedia(
      auditMediaId: auditMediaId,
      mediaUrl: mediaUrl,
      mediaType: mediaType,
    );
  }

  @override
  Future<void> createAuditDescriptionComment({
    required String descriptionId,
    required String comment,
  }) {
    return _remoteDataSource.createAuditDescriptionComment(
      descriptionId: descriptionId,
      comment: comment,
    );
  }

  @override
  Future<String> uploadPerformanceReportSignatureImage({
    required String fileName,
    required List<int> fileBytes,
    required String contentType,
  }) {
    return _remoteDataSource.uploadPerformanceReportSignatureImage(
      fileName: fileName,
      fileBytes: fileBytes,
      contentType: contentType,
    );
  }

  @override
  Future<void> markFavoriteSubordinate({required String profileJobId}) {
    return _remoteDataSource.markFavoriteSubordinate(
      profileJobId: profileJobId,
    );
  }

  @override
  Future<void> markUnfavoriteSubordinate({required String profileJobId}) {
    return _remoteDataSource.markUnfavoriteSubordinate(
      profileJobId: profileJobId,
    );
  }
}
