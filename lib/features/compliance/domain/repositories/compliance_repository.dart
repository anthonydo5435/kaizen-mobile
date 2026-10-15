import 'package:flutter/foundation.dart';

import '../entities/compliance_certificate.dart';
import '../entities/compliance_document.dart';
import '../entities/compliance_overview.dart';
import '../entities/compliance_presigned_upload.dart';
import '../entities/compliance_quiz.dart';
import '../entities/compliance_quiz_result.dart';
import '../entities/compliance_track_item_detail.dart';
import '../entities/learning_module_detail_track.dart';

abstract class ComplianceRepository {
  Future<ComplianceOverview> getComplianceOverview({bool forceRefresh = false, String? name});
  Future<List<ComplianceDocument>> getComplianceDocuments({
    bool forceRefresh = false,
    String? name,
  });
  Future<List<LearningTrackModuleDetail>> getComplianceTracks({
    required String trackAssignmentUuid,
  });
  Future<ComplianceTrackItemDetail> getComplianceTrackItemDetail({
    required String trackAssignmentUuid,
    required String itemUuid,
  });
  Future<ComplianceCertificate> getCertificate({required String trackAssignmentUuid});
  Future<ComplianceQuiz> getComplianceQuiz({
    required String trackAssignmentUuid,
    required String trainingModuleUuid,
  });
  Future<String?> startComplianceQuiz({
    required String trackAssignmentUuid,
    required String trainingModuleUuid,
  });
  Future<ComplianceQuizResult> getComplianceQuizResult({
    required String trackAssignmentUuid,
    required String trainingModuleUuid,
  });
  Future<void> pauseComplianceQuiz({
    required String trackAssignmentUuid,
    required String quizAttemptUuid,
    required Map<String, String> currentAnswers,
    required int timeSpent,
  });
  Future<void> submitComplianceQuiz({
    required String trackAssignmentUuid,
    required String quizAttemptUuid,
    required Map<String, String> currentAnswers,
    required int timeSpent,
  });
  Future<CompliancePresignedUpload> generateComplianceDocumentUploadUrl({required String fileName});
  Future<void> uploadComplianceDocumentFile({
    required String uploadUrl,
    required String fileName,
    required List<int> fileBytes,
    required String contentType,
    ValueChanged<double>? onProgress,
  });
  Future<void> uploadComplianceDocumentRecord({
    required String complianceDocumentId,
    required String fileName,
    required String documentUrl,
    String? expiryDate,
  });
}
