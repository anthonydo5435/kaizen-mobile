import 'package:flutter/foundation.dart';

import '../../domain/entities/compliance_certificate.dart';
import '../../domain/entities/compliance_document.dart';
import '../../domain/entities/compliance_overview.dart';
import '../../domain/entities/compliance_presigned_upload.dart';
import '../../domain/entities/compliance_quiz.dart';
import '../../domain/entities/compliance_quiz_result.dart';
import '../../domain/entities/compliance_track_item_detail.dart';
import '../../domain/entities/learning_module_detail_track.dart';
import '../../domain/repositories/compliance_repository.dart';
import '../datasources/compliance_remote_data_source.dart';

class ComplianceRepositoryImpl implements ComplianceRepository {
  const ComplianceRepositoryImpl(this._remoteDataSource);

  final ComplianceRemoteDataSource _remoteDataSource;

  @override
  Future<ComplianceOverview> getComplianceOverview({bool forceRefresh = false, String? name}) {
    return _remoteDataSource.getComplianceOverview(forceRefresh: forceRefresh, name: name);
  }

  @override
  Future<List<ComplianceDocument>> getComplianceDocuments({
    bool forceRefresh = false,
    String? name,
  }) {
    return _remoteDataSource.getComplianceDocuments(forceRefresh: forceRefresh, name: name);
  }

  @override
  Future<List<LearningTrackModuleDetail>> getComplianceTracks({
    required String trackAssignmentUuid,
  }) {
    return _remoteDataSource.getComplianceTracks(trackAssignmentUuid: trackAssignmentUuid);
  }

  @override
  Future<ComplianceTrackItemDetail> getComplianceTrackItemDetail({
    required String trackAssignmentUuid,
    required String itemUuid,
  }) {
    return _remoteDataSource.getComplianceTrackItemDetail(
      trackAssignmentUuid: trackAssignmentUuid,
      itemUuid: itemUuid,
    );
  }

  @override
  Future<ComplianceCertificate> getCertificate({required String trackAssignmentUuid}) {
    return _remoteDataSource.getCertificate(trackAssignmentUuid: trackAssignmentUuid);
  }

  @override
  Future<ComplianceQuiz> getComplianceQuiz({
    required String trackAssignmentUuid,
    required String trainingModuleUuid,
  }) {
    return _remoteDataSource.getComplianceQuiz(
      trackAssignmentUuid: trackAssignmentUuid,
      trainingModuleUuid: trainingModuleUuid,
    );
  }

  @override
  Future<String?> startComplianceQuiz({
    required String trackAssignmentUuid,
    required String trainingModuleUuid,
  }) {
    return _remoteDataSource.startComplianceQuiz(
      trackAssignmentUuid: trackAssignmentUuid,
      trainingModuleUuid: trainingModuleUuid,
    );
  }

  @override
  Future<ComplianceQuizResult> getComplianceQuizResult({
    required String trackAssignmentUuid,
    required String trainingModuleUuid,
  }) {
    return _remoteDataSource.getComplianceQuizResult(
      trackAssignmentUuid: trackAssignmentUuid,
      trainingModuleUuid: trainingModuleUuid,
    );
  }

  @override
  Future<void> pauseComplianceQuiz({
    required String trackAssignmentUuid,
    required String quizAttemptUuid,
    required Map<String, String> currentAnswers,
    required int timeSpent,
  }) {
    return _remoteDataSource.pauseComplianceQuiz(
      trackAssignmentUuid: trackAssignmentUuid,
      quizAttemptUuid: quizAttemptUuid,
      currentAnswers: currentAnswers,
      timeSpent: timeSpent,
    );
  }

  @override
  Future<void> submitComplianceQuiz({
    required String trackAssignmentUuid,
    required String quizAttemptUuid,
    required Map<String, String> currentAnswers,
    required int timeSpent,
  }) {
    return _remoteDataSource.submitComplianceQuiz(
      trackAssignmentUuid: trackAssignmentUuid,
      quizAttemptUuid: quizAttemptUuid,
      currentAnswers: currentAnswers,
      timeSpent: timeSpent,
    );
  }

  @override
  Future<CompliancePresignedUpload> generateComplianceDocumentUploadUrl({
    required String fileName,
  }) {
    return _remoteDataSource.generateComplianceDocumentUploadUrl(fileName: fileName);
  }

  @override
  Future<void> uploadComplianceDocumentFile({
    required String uploadUrl,
    required String fileName,
    required List<int> fileBytes,
    required String contentType,
    ValueChanged<double>? onProgress,
  }) {
    return _remoteDataSource.uploadComplianceDocumentFile(
      uploadUrl: uploadUrl,
      fileName: fileName,
      fileBytes: fileBytes,
      contentType: contentType,
      onProgress: onProgress,
    );
  }

  @override
  Future<void> uploadComplianceDocumentRecord({
    required String complianceDocumentId,
    required String fileName,
    required String documentUrl,
    String? expiryDate,
  }) {
    return _remoteDataSource.uploadComplianceDocumentRecord(
      complianceDocumentId: complianceDocumentId,
      fileName: fileName,
      documentUrl: documentUrl,
      expiryDate: expiryDate,
    );
  }
}
