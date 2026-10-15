import '../preference/app_preference.dart';

class ApiEndPoints {
  ApiEndPoints._();
  // static const String baseUrl = 'https://dev-api.kaizenteams.ai';

  static const String publicWebBaseUrl = baseUrl == 'https://dev-api.kaizenteams.ai'
      ? 'https://dev.kaizenteams.ai'
      : 'https://app.kaizenteams.ai';

  static const String baseUrl = 'https://api.kaizenteams.ai';
  static const String version = '/api/v1/';
  static const String parentPrefix = 'parent_';
  static const String login = 'accounts/login/';
  static const String googleLogin = 'accounts/google/login/';
  static const String passwordReset = 'password_reset/';
  static const String passwordConfirm = 'password_confirm/';
  static const String setActiveOrganization = 'accounts/set_active_organization/';
  static const String refreshToken = 'accounts/token/refresh/';
  static const String userDetail = 'accounts/user_detail/';
  static const String companyDetail = 'company_detail/';
  static const String myLearningTracks = 'learning_compliance/track_assignments/my_tracks/';
  static const String complianceDocumentTypes = 'compliance/document_type/';
  static const String myDocumentCompliances =
      'compliance/document_compliance_assignments/my_document_compliances/';
  static const String jobs = 'job/';
  static const String payGrade = 'pay_grade/';
  static const String organizations = 'organizations/';
  static const String images = 'image/';
  static const String allDepartments = 'department/all_departments/';
  static const String organizationHierarchy = 'department/organization_hierarchy/';
  static const String parentDepartments = '${parentPrefix}department/';
  static const String generatePreSignedUrl = 'generate_pre_signed_url/';
  static const String quarterlyAudit = 'quarterly_audit/';
  static const String quarterlyAuditMyAudits = 'quarterly_audit/my_audits/';
  static const String quarterlyAuditPerformanceSnapshot = 'quarterly_audit/performance_snapshot/';
  static const String quarterlyAuditMyPerformanceSnapshot =
      'quarterly_audit/my_performance_snapshot/';
  static const String subordinateJobs = 'job/subordinate_jobs/';
  static const String favoriteSubordinate = 'profiles/favorite_subordinate/';
  static const String unfavoriteSubordinate = 'profiles/unfavorite_subordinate/';

  static String quarterlyAuditDetails(String profileJobId) {
    return 'quarterly_audit/profile_job/$profileJobId/audits/';
  }

  static String userById(String userId) {
    return 'users/$userId/';
  }

  static String changePassword(String userId) {
    return 'users/$userId/change_password/';
  }

  static String verifyToken(String token) {
    return 'accounts/verify_token/$token/';
  }

  static String quarterlyAuditEvaluationChart(String profileJobId) {
    return 'quarterly_audit/profile_job/$profileJobId/evaluation-chart/';
  }

  static String auditReport(String profileJobId) {
    return 'audit_report/profile_job/$profileJobId/report/';
  }

  static String auditReportOverview(String profileJobId) {
    return 'audit_report/profile_job/$profileJobId/report_overview/';
  }

  static String auditReportRemarks(String profileJobId) {
    return 'audit_report/profile_job/$profileJobId/remarks/';
  }

  static String auditReportCertifiedReports(String profileJobId) {
    return 'audit_report/profile_job/$profileJobId/certified_reports/';
  }

  static String auditReportCertifiedReportDetail(String certifiedReportUuid) {
    return 'audit_report/certified_report/$certifiedReportUuid/';
  }

  static String auditReportCertifiedReportDownloadPdf(String certifiedReportUuid) {
    return 'audit_report/certified_report/$certifiedReportUuid/download_pdf/';
  }

  static String auditReportCertify(String profileJobId) {
    return 'audit_report/profile_job/$profileJobId/certify/';
  }

  static String auditReportJobCategory(String categoryId) {
    return 'audit_report/job_categories/$categoryId/report/';
  }

  static String auditReportSeatDescription({
    required String flowFirstId,
    required String descriptionId,
  }) {
    return 'audit_report/profile_job/$flowFirstId/description/$descriptionId/audit_report/';
  }

  static String auditMediaSeatDescription({
    required String flowFirstId,
    required String descriptionId,
  }) {
    return 'audit_report/profile_job/$flowFirstId/description/$descriptionId/audit_media/';
  }

  static String auditReportSeatDescriptionProfiles({
    required String flowFirstId,
    required String descriptionId,
  }) {
    return 'audit_report/profile_job/$flowFirstId/description/$descriptionId/profiles/';
  }

  static String seatDescriptionTrainingModules(String descriptionId) {
    return 'job_category_description/$descriptionId/training_modules/';
  }

  static const String jobCategoryDescriptions = 'job_category_description/';

  static String jobCategoryDescription(String descriptionId) {
    return 'job_category_description/$descriptionId/';
  }

  static const String seatProfileCategoryTrainings = 'job/jobs_categories_descriptions/';
  static const String trainingModules = 'training_modules/';
  static const String trainingModulesAll = 'training_modules/all/';

  static String sharedContent(String publicId) {
    return 'shared/content/${Uri.encodeComponent(publicId)}/';
  }

  static String seatProfilePublicLink(String seatId) {
    return 'job/${Uri.encodeComponent(seatId)}/public-links/seat-profile/';
  }

  static String paygradesPublicLink(String jobId) {
    return 'job/${Uri.encodeComponent(jobId)}/public-links/paygrades/';
  }

  static String lmsPublicLink(String descriptionId) {
    return 'job_category_description/${Uri.encodeComponent(descriptionId)}/public-links/lms/';
  }

  static String sharedLesson(String sharedContentId, String publicId) {
    return '${sharedContent(sharedContentId)}modules/${Uri.encodeComponent(publicId)}/';
  }

  static String trainingModuleDetail(String moduleId) {
    return 'training_modules/$moduleId/';
  }

  static String parentTrainingModuleDetail(String moduleId) {
    return 'parent_training_modules/$moduleId/';
  }

  static String trainingModuleDocument(String moduleId) {
    return 'training_modules/$moduleId/document/';
  }

  static String trainingModuleAssignment(String moduleId) {
    return 'training_modules/$moduleId/assignment/';
  }

  static String trainingDocument(String documentId) {
    return 'training_document/$documentId/';
  }

  static String trainingModuleQuestions(String moduleId) {
    return 'training_modules/$moduleId/questions/';
  }

  static String addTrainingModuleQuestion(String moduleId) {
    return 'training_modules/$moduleId/add_question/';
  }

  static String addTrainingModuleAssignment(String moduleId) {
    return 'training_modules/$moduleId/add_assignment/';
  }

  static String trainingAssignment(String assignmentId) {
    return 'training_assignment/$assignmentId/';
  }

  static String addTrainingModuleVideo(String moduleId) {
    return 'training_modules/$moduleId/add_video/';
  }

  static String trainingVideoDetail(String videoId) {
    return 'training_video/$videoId/';
  }

  static String generateTrainingModuleQuiz(String moduleId) {
    return 'training_modules/$moduleId/generate_quiz/';
  }

  static String generateTrainingModuleSop(String moduleId) {
    return 'training_modules/$moduleId/generate_sop/';
  }

  static String generateTrainingModuleAssignment(String moduleId) {
    return 'training_modules/$moduleId/generate_assignment/';
  }

  static String generateTrainingModuleSummary(String moduleId) {
    return 'training_modules/$moduleId/generate_summary/';
  }

  static String updateQuestion(String questionId) {
    return 'question/$questionId/';
  }

  static String seatProfileDetail(String seatId) {
    return 'job/$seatId/get_detail/';
  }

  static String seatProfileJob(String seatId) {
    return 'job/$seatId/';
  }

  static String bulkUpsertSeatProfileCategories(String actualId) {
    return 'job/$actualId/bulk_upsert_categories/';
  }

  static String generateSeatProfileJobContent(String actualId) {
    return '${seatProfileJob(actualId)}generate_job_content/';
  }

  static String seatProfileJobContent(String actualId) {
    return seatProfileJob(actualId);
  }

  static String payGradeDetail(String paygradeId) {
    return 'job/$paygradeId/pay_grades/';
  }

  static String generatePayGrades(String actualId) {
    return 'job/$actualId/generate_pay_grades/';
  }

  static String payGradeItem(String paygradeId) {
    return 'pay_grade/$paygradeId/';
  }

  static String departmentDetail(String departmentId) {
    return 'department/$departmentId/';
  }

  static String quarterlyAuditDetail(String quarterlyAuditId) {
    return 'quarterly_audit/$quarterlyAuditId/details/';
  }

  static String quarterlyAuditDescriptionAudit({
    required String quarterlyAuditId,
    required String descriptionId,
  }) {
    return 'quarterly_audit/$quarterlyAuditId/descriptions/$descriptionId/audit/';
  }

  static String auditDescription(String descriptionId) {
    return 'audit/$descriptionId/';
  }

  static String createAuditDescriptionMedia(String descriptionId) {
    return 'audit/$descriptionId/create_media/';
  }

  static String auditMedia(String auditMediaId) {
    return 'audit_media/$auditMediaId/';
  }

  static String addAuditMediaComment(String auditMediaId) {
    return 'audit_media/$auditMediaId/add_comment/';
  }

  static String uploadComplianceDocument(String complianceDocumentId) {
    return 'compliance/document_compliance_assignments/$complianceDocumentId/upload_document/';
  }

  static String learningTrackAssignmentDetail(String uuid) {
    return 'learning_compliance/track_assignments/$uuid/';
  }

  static String complianceCertificate(String trackAssignmentUuid) {
    return 'learning_compliance/track_assignments/$trackAssignmentUuid/certificate/';
  }

  static String complianceQuizQuestions({
    required String trackAssignmentUuid,
    required String trainingModuleUuid,
  }) {
    return 'learning_compliance/track_assignments/$trackAssignmentUuid/'
        'training_modules/$trainingModuleUuid/questions/';
  }

  static String startComplianceQuiz({
    required String trackAssignmentUuid,
    required String trainingModuleUuid,
  }) {
    return 'learning_compliance/track_assignments/$trackAssignmentUuid/'
        'training_modules/$trainingModuleUuid/start_quiz/';
  }

  static String complianceQuizResult({
    required String trackAssignmentUuid,
    required String trainingModuleUuid,
  }) {
    return 'learning_compliance/track_assignments/$trackAssignmentUuid/'
        'training_modules/$trainingModuleUuid/quiz_result/';
  }

  static String pauseComplianceQuiz({
    required String trackAssignmentUuid,
    required String quizAttemptUuid,
  }) {
    return 'learning_compliance/track_assignments/$trackAssignmentUuid/'
        'quiz_attempts/$quizAttemptUuid/pause/';
  }

  static String submitComplianceQuiz({
    required String trackAssignmentUuid,
    required String quizAttemptUuid,
  }) {
    return 'learning_compliance/track_assignments/$trackAssignmentUuid/'
        'quiz_attempts/$quizAttemptUuid/submit/';
  }

  static String departments() {
    if (AppPreference.getUseParentApiEndpoints()) {
      return parentDepartments;
    }

    return allDepartments;
  }

  static Uri resolveUri(String endpoint, {bool allowParentPrefix = true}) {
    return Uri.parse(
      '$baseUrl$version${resolveEndpoint(endpoint, allowParentPrefix: allowParentPrefix)}',
    );
  }

  static String resolveEndpoint(String endpoint, {bool allowParentPrefix = true}) {
    final normalizedEndpoint = endpoint.trim();
    if (normalizedEndpoint.isEmpty || !allowParentPrefix) {
      return normalizedEndpoint;
    }

    if (!AppPreference.getUseParentApiEndpoints() ||
        _shouldBypassParentPrefix(normalizedEndpoint) ||
        normalizedEndpoint.startsWith(parentPrefix)) {
      return normalizedEndpoint;
    }

    return '$parentPrefix$normalizedEndpoint';
  }

  static bool _shouldBypassParentPrefix(String endpoint) {
    return endpoint == login ||
        endpoint == googleLogin ||
        endpoint == setActiveOrganization ||
        endpoint == refreshToken ||
        endpoint == userDetail ||
        endpoint == companyDetail ||
        endpoint == images ||
        endpoint == generatePreSignedUrl ||
        endpoint == organizations ||
        endpoint.startsWith('shared/content/') ||
        endpoint.startsWith('accounts/verify_token/');
  }
}
