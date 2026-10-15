import 'package:flutter/foundation.dart';
import 'package:sparrowkaizen/core/preference/app_preference.dart';

import '../../../../core/network/api_endpoints.dart';
import '../../../../core/network/api_error.dart';
import '../../../../core/network/api_processor.dart';
import '../../../../core/services/file_uploader.dart';
import '../../domain/entities/compliance_certificate.dart';
import '../../domain/entities/compliance_document.dart';
import '../../domain/entities/compliance_presigned_upload.dart';
import '../../domain/entities/compliance_quiz.dart';
import '../../domain/entities/compliance_quiz_question.dart';
import '../../domain/entities/compliance_quiz_result.dart';
import '../../domain/entities/compliance_track_item_detail.dart';
import '../../domain/entities/learning_module_detail_track.dart';
import '../models/compliance_document_model.dart';
import '../models/compliance_overview_model.dart';

class ComplianceRemoteDataSource {
  ComplianceRemoteDataSource({ApiCallExecutor? apiCallExecutor})
    : _apiCallExecutor = apiCallExecutor ?? const ApiCallExecutor(),
      _fileUploader = FileUploader(apiCallExecutor: apiCallExecutor);

  final ApiCallExecutor _apiCallExecutor;
  final FileUploader _fileUploader;

  Future<ComplianceOverviewModel> getComplianceOverview({
    bool forceRefresh = false,
    bool requireSuccess = false,
    String? name,
  }) async {
    final learningTracks = await _getComplianceOverviewLearningTracks(
      forceRefresh: forceRefresh,
      requireSuccess: requireSuccess || (name?.trim().isNotEmpty ?? false),
      name: name,
    );

    return ComplianceOverviewModel(
      learningTracks: learningTracks,
      documents: const <ComplianceDocument>[],
    );
  }

  Future<List<LearningTrackModuleDetail>> _getComplianceOverviewLearningTracks({
    bool forceRefresh = false,
    bool requireSuccess = false,
    String? name,
  }) async {
    final searchName = name?.trim();
    try {
      return await _apiCallExecutor.processApi<List<LearningTrackModuleDetail>>(
        apiCallType: ApiCallType.get,
        endpoint: ApiEndPoints.myLearningTracks,
        parameters: searchName != null && searchName.isNotEmpty
            ? {'page': 1, 'name': searchName, 'page_size': 10}
            : null,
        authToken: AppPreference.getAuthToken(),
        invalidateCacheBeforeRequest: forceRefresh,
        decoder: (json) {
          return _extractTrackList(json)
              .map((item) => LearningTrackModuleDetail.fromJson(item))
              .toList(growable: false);
        },
      );
    } catch (error) {
      if (requireSuccess) {
        rethrow;
      }
      debugPrint('Compliance learning tracks failed: $error');
      return const <LearningTrackModuleDetail>[];
    }
  }

  Future<List<ComplianceDocument>> getComplianceDocuments({
    bool forceRefresh = false,
    String? name,
  }) {
    final searchName = name?.trim();
    final isSearch = searchName != null && searchName.isNotEmpty;
    return _apiCallExecutor.processApi<List<ComplianceDocument>>(
      apiCallType: ApiCallType.get,
      endpoint: isSearch
          ? ApiEndPoints.complianceDocumentTypes
          : ApiEndPoints.myDocumentCompliances,
      parameters: isSearch
          ? {'name': searchName, 'page': 1, 'page_size': 10}
          : null,
      authToken: AppPreference.getAuthToken(),
      invalidateCacheBeforeRequest: forceRefresh,
      decoder: (json) {
        return _extractResultList(json)
            .map((item) {
              if (isSearch &&
                  !item.containsKey('has_expiry') &&
                  !item.containsKey('latest_document')) {
                return ComplianceDocumentModel.fromApiJson(item);
              }
              return ComplianceDocumentModal.fromApiJson(item);
            })
            .toList(growable: false);
      },
    );
  }

  Future<CompliancePresignedUpload> generateComplianceDocumentUploadUrl({
    required String fileName,
  }) async {
    final upload = await _fileUploader.generatePresignedUpload(
      key: 'document_compliance',
      fileName: fileName,
    );
    return CompliancePresignedUpload(
      uploadUrl: upload.uploadUrl,
      fileUrl: upload.fileUrl,
    );
  }

  Future<void> uploadComplianceDocumentFile({
    required String uploadUrl,
    required String fileName,
    required List<int> fileBytes,
    required String contentType,
    ValueChanged<double>? onProgress,
  }) async {
    await _fileUploader.uploadBinaryFile(
      uploadUrl: uploadUrl,
      fileBytes: fileBytes,
      contentType: contentType,
      onProgress: onProgress,
    );
  }

  Future<void> uploadComplianceDocumentRecord({
    required String complianceDocumentId,
    required String fileName,
    required String documentUrl,
    String? expiryDate,
  }) {
    final trimmedExpiryDate = expiryDate?.trim();

    return _apiCallExecutor.processApi<void>(
      apiCallType: ApiCallType.put,
      endpoint: ApiEndPoints.uploadComplianceDocument(complianceDocumentId),
      authToken: AppPreference.getAuthToken(),
      parameters: {
        'name': fileName,
        'doc_url': documentUrl,
        if (trimmedExpiryDate != null && trimmedExpiryDate.isNotEmpty)
          'expiry_date': trimmedExpiryDate,
      },
      decoder: (_) {},
    );
  }

  Future<List<LearningTrackModuleDetail>> getComplianceTracks({
    required String trackAssignmentUuid,
  }) {
    return _apiCallExecutor.processApi<List<LearningTrackModuleDetail>>(
      apiCallType: ApiCallType.get,
      endpoint: ApiEndPoints.learningTrackAssignmentDetail(trackAssignmentUuid),
      authToken: AppPreference.getAuthToken(),
      decoder: (json) {
        if (json is! Map<String, dynamic>) {
          throw const ApiError.invalidResponse();
        }

        final items = json['items'];
        if (items is! List) {
          throw const ApiError.invalidResponse();
        }

        final parentDeadline = _readString(json['deadline']);
        final parentJobTitle = _readString(_readMap(json['job'])?['title']);
        final parentName = _readString(json['name']);
        final passingPercentage = _readInt(json['passing_percentage']);

        return items
            .whereType<Map<String, dynamic>>()
            .map((item) {
              final trainingModule = _readMap(item['training_module']);
              final breakPoint = _readMap(item['break_point']);

              if (trainingModule == null && breakPoint == null) {
                throw const ApiError.invalidResponse();
              }

              if (breakPoint != null) {
                return LearningTrackModuleDetail(
                  trainingModuleItemId: _readString(item['uuid']),
                  breakPointTitle: _readString(breakPoint['title']),
                  breakPointSubtitle: _readString(breakPoint['subtitle']),
                  deadline: parentDeadline,
                  job: parentJobTitle,
                  schedule: parentName,
                  passingPercentage: passingPercentage,
                );
              }

              final resolvedTrainingModule = trainingModule!;

              return LearningTrackModuleDetail(
                trainingModuleItemId: _readString(item['uuid']),
                uuid: _readString(resolvedTrainingModule['uuid']),
                name: _readString(resolvedTrainingModule['title']),
                job: parentJobTitle,
                status: _readString(resolvedTrainingModule['status']),
                deadline: parentDeadline,
                schedule: parentName,
                thumbnailLink: _readString(
                  resolvedTrainingModule['thumbnail_link'],
                ),
                completionPercentage: _readInt(
                  resolvedTrainingModule['completion_percentage'],
                ),
                passingPercentage: passingPercentage,
              );
            })
            .toList(growable: false);
      },
    );
  }

  Future<ComplianceTrackItemDetail> getComplianceTrackItemDetail({
    required String trackAssignmentUuid,
    required String itemUuid,
  }) {
    return _apiCallExecutor.processApi<ComplianceTrackItemDetail>(
      apiCallType: ApiCallType.get,
      endpoint:
          '${ApiEndPoints.learningTrackAssignmentDetail(trackAssignmentUuid)}items/$itemUuid',
      authToken: AppPreference.getAuthToken(),
      decoder: (json) {
        if (json is! Map<String, dynamic>) {
          throw const ApiError.invalidResponse();
        }

        final trainingModule = _readMap(json['training_module']);
        final trainingVideo = _readMap(trainingModule?['training_video']);

        if (trainingModule == null) {
          throw const ApiError.invalidResponse();
        }

        return ComplianceTrackItemDetail(
          uuid: _readString(json['uuid']) ?? '',
          position: _readInt(json['position']) ?? 0,
          trainingModuleUuid: _readString(trainingModule['uuid']) ?? '',
          title: _readString(trainingModule['title']) ?? '',
          quizStatus: _readString(trainingModule['quiz_status']) ?? '',
          videoUrl: _readString(trainingVideo?['url']),
          videoDuration: _readInt(trainingVideo?['duration']) ?? 0,
          videoTranscript: _readString(trainingVideo?['transcript']),
          videoThumbnailLink: _readString(trainingVideo?['thumbnail_link']),
          trainingDocument: _readString(trainingModule['training_document']),
          quizCompletionPercentage:
              _readInt(trainingModule['quiz_completion_percentage']) ?? 0,
        );
      },
    );
  }

  Future<ComplianceCertificate> getCertificate({
    required String trackAssignmentUuid,
  }) {
    return _apiCallExecutor.processApi<ComplianceCertificate>(
      apiCallType: ApiCallType.get,
      endpoint: ApiEndPoints.complianceCertificate(trackAssignmentUuid),
      authToken: AppPreference.getAuthToken(),
      decoder: (json) {
        final certificateJson = _readResultMap(json);
        if (certificateJson == null) {
          throw const ApiError.invalidResponse();
        }

        return ComplianceCertificate(
          percentage: _readInt(certificateJson['percentage']) ?? 0,
          certificate: _readString(certificateJson['certificate']) ?? '',
          trackName: _readString(certificateJson['track_name']) ?? '',
        );
      },
    );
  }

  Future<ComplianceQuiz> getComplianceQuiz({
    required String trackAssignmentUuid,
    required String trainingModuleUuid,
  }) {
    return _apiCallExecutor.processApi<ComplianceQuiz>(
      apiCallType: ApiCallType.get,
      endpoint: ApiEndPoints.complianceQuizQuestions(
        trackAssignmentUuid: trackAssignmentUuid,
        trainingModuleUuid: trainingModuleUuid,
      ),
      authToken: AppPreference.getAuthToken(),
      decoder: (json) {
        if (json is! Map<String, dynamic>) {
          throw const ApiError.invalidResponse();
        }

        final questionList = json['questions'];
        if (questionList is! List) {
          throw const ApiError.invalidResponse();
        }

        final temporaryAnswers = <String, String>{};
        for (final answersJson in [
          json['temporary_answers'],
          json['current_answers'],
        ]) {
          if (answersJson is Map) {
            for (final entry in answersJson.entries) {
              final key = entry.key?.toString().trim();
              final value = entry.value?.toString().trim();
              if (key != null &&
                  key.isNotEmpty &&
                  value != null &&
                  value.isNotEmpty) {
                temporaryAnswers[key] = value;
              }
            }
          }
        }

        final questions = questionList
            .whereType<Map<String, dynamic>>()
            .map((item) {
              final questionUuid = _readString(item['uuid']) ?? '';
              final selectedOptionUuid = _readString(item['selected_option']);
              if (questionUuid.isNotEmpty &&
                  selectedOptionUuid != null &&
                  selectedOptionUuid.isNotEmpty) {
                temporaryAnswers.putIfAbsent(
                  questionUuid,
                  () => selectedOptionUuid,
                );
              }

              final optionsJson = item['options'];
              if (optionsJson is! List) {
                throw const ApiError.invalidResponse();
              }

              return ComplianceQuizQuestion(
                uuid: questionUuid,
                question: _readString(item['question']) ?? '',
                imageUrl: _readString(item['image_url']),
                options: optionsJson
                    .whereType<Map<String, dynamic>>()
                    .map((option) {
                      return ComplianceQuizOption(
                        uuid: _readString(option['uuid']) ?? '',
                        text: _readString(option['text']) ?? '',
                      );
                    })
                    .toList(growable: false),
              );
            })
            .toList(growable: false);

        return ComplianceQuiz(
          timeSpent: _readInt(json['time_spent']),
          quizAttemptUuid: _readQuizAttemptUuid(json),
          questions: questions,
          temporaryAnswers: temporaryAnswers,
        );
      },
    );
  }

  Future<String?> startComplianceQuiz({
    required String trackAssignmentUuid,
    required String trainingModuleUuid,
  }) {
    return _apiCallExecutor.processApi<String?>(
      apiCallType: ApiCallType.put,
      endpoint: ApiEndPoints.startComplianceQuiz(
        trackAssignmentUuid: trackAssignmentUuid,
        trainingModuleUuid: trainingModuleUuid,
      ),
      authToken: AppPreference.getAuthToken(),
      decoder: (json) => _readQuizAttemptUuid(json),
    );
  }

  Future<ComplianceQuizResult> getComplianceQuizResult({
    required String trackAssignmentUuid,
    required String trainingModuleUuid,
  }) {
    return _apiCallExecutor.processApi<ComplianceQuizResult>(
      apiCallType: ApiCallType.get,
      endpoint: ApiEndPoints.complianceQuizResult(
        trackAssignmentUuid: trackAssignmentUuid,
        trainingModuleUuid: trainingModuleUuid,
      ),
      authToken: AppPreference.getAuthToken(),
      decoder: (json) {
        final resultJson = _readResultMap(json);
        if (resultJson == null) {
          throw const ApiError.invalidResponse();
        }

        final isPassed = _readBool(resultJson['is_passed']) ?? false;
        final questionResponsesJson = resultJson['question_responses'];

        return ComplianceQuizResult(
          uuid: _readString(resultJson['uuid']) ?? '',
          completionPercentage:
              _readDouble(resultJson['completion_percentage']) ?? 0,
          totalAttempts: _readInt(resultJson['total_attempts']) ?? 0,
          correctAnswers: _readInt(resultJson['correct_answers']) ?? 0,
          totalQuestions: _readInt(resultJson['total_questions']) ?? 0,
          totalTimeSpent: _readInt(resultJson['total_time_spent']) ?? 0,
          isPassed: isPassed,
          questionResponses: questionResponsesJson is List
              ? questionResponsesJson
                    .whereType<Map<String, dynamic>>()
                    .map(_parseQuizQuestionResponse)
                    .toList(growable: false)
              : const [],
        );
      },
    );
  }

  Future<void> pauseComplianceQuiz({
    required String trackAssignmentUuid,
    required String quizAttemptUuid,
    required Map<String, String> currentAnswers,
    required int timeSpent,
  }) {
    return _apiCallExecutor.processApi<void>(
      apiCallType: ApiCallType.put,
      endpoint: ApiEndPoints.pauseComplianceQuiz(
        trackAssignmentUuid: trackAssignmentUuid,
        quizAttemptUuid: quizAttemptUuid,
      ),
      authToken: AppPreference.getAuthToken(),
      parameters: {'time_spent': timeSpent, 'current_answers': currentAnswers},
      decoder: (_) {},
    );
  }

  Future<void> submitComplianceQuiz({
    required String trackAssignmentUuid,
    required String quizAttemptUuid,
    required Map<String, String> currentAnswers,
    required int timeSpent,
  }) {
    return _apiCallExecutor.processApi<void>(
      apiCallType: ApiCallType.put,
      endpoint: ApiEndPoints.submitComplianceQuiz(
        trackAssignmentUuid: trackAssignmentUuid,
        quizAttemptUuid: quizAttemptUuid,
      ),
      authToken: AppPreference.getAuthToken(),
      parameters: {'time_spent': timeSpent, 'current_answers': currentAnswers},
      decoder: (_) {},
    );
  }

  List<dynamic> _extractTrackPayload(dynamic json) {
    return _extractResultPayload(json);
  }

  List<dynamic> _extractResultPayload(dynamic json) {
    final payload = _tryExtractResultPayload(json);
    if (payload != null) {
      return payload;
    }

    throw const ApiError.invalidResponse();
  }

  List<dynamic>? _tryExtractResultPayload(dynamic json) {
    if (json is List) {
      return json;
    }

    if (json is! Map<String, dynamic>) {
      return null;
    }

    for (final key in const [
      'results',
      'result',
      'data',
      'items',
      'track_assignments',
      'document_types',
    ]) {
      final payload = _tryExtractResultPayload(json[key]);
      if (payload != null) {
        return payload;
      }
    }

    return null;
  }

  List<Map<String, dynamic>> _extractTrackList(dynamic json) {
    final payload = _extractTrackPayload(json);

    return payload.whereType<Map<String, dynamic>>().toList();
  }

  List<Map<String, dynamic>> _extractResultList(dynamic json) {
    final payload = _extractResultPayload(json);

    return payload.whereType<Map<String, dynamic>>().toList();
  }

  String? _readString(dynamic value) {
    final resolved = value?.toString().trim();
    if (resolved == null || resolved.isEmpty) {
      return null;
    }

    return resolved;
  }

  int? _readInt(dynamic value) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value?.toString() ?? '');
  }

  double? _readDouble(dynamic value) {
    if (value is double) {
      return value;
    }

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value?.toString() ?? '');
  }

  bool? _readBool(dynamic value) {
    if (value is bool) {
      return value;
    }

    final normalized = value?.toString().trim().toLowerCase();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }

    if (normalized == 'true' || normalized == '1' || normalized == 'yes') {
      return true;
    }

    if (normalized == 'false' || normalized == '0' || normalized == 'no') {
      return false;
    }

    return null;
  }

  Map<String, dynamic>? _readMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }

    return null;
  }

  Map<String, dynamic>? _readResultMap(dynamic value) {
    final root = _readMap(value);
    if (root == null) {
      return null;
    }

    return _readMap(root['result']) ?? _readMap(root['data']) ?? root;
  }

  ComplianceQuizQuestionResponse _parseQuizQuestionResponse(
    Map<String, dynamic> json,
  ) {
    final optionsJson = json['options'];

    return ComplianceQuizQuestionResponse(
      uuid: _readString(json['uuid']) ?? '',
      isCorrect: _readBool(json['is_correct']) ?? false,
      selectedOption: _readString(json['selected_option']),
      question: _readString(json['question']) ?? '',
      options: optionsJson is List
          ? optionsJson
                .whereType<Map<String, dynamic>>()
                .map(
                  (option) => ComplianceQuizResultOption(
                    uuid: _readString(option['uuid']) ?? '',
                    text: _readString(option['text']) ?? '',
                  ),
                )
                .toList(growable: false)
          : const [],
      imageUrl: _readString(json['image_url']),
    );
  }

  String? _readQuizAttemptUuid(dynamic value) {
    return _readFirstString(value, const [
      'uuid',
      'quiz_attempt_uuid',
      'quiz_attempt_id',
      'quizAttemptUuid',
      'attempt_uuid',
      'attempt_id',
    ]);
  }

  String? _readFirstString(dynamic value, List<String> keys) {
    if (value == null) {
      return null;
    }

    if (value is String) {
      return value.trim().isEmpty ? null : value.trim();
    }

    if (value is! Map<String, dynamic>) {
      return null;
    }

    for (final key in keys) {
      final directValue = _readString(value[key]);
      if (directValue != null) {
        return directValue;
      }
    }

    for (final nestedKey in const ['result', 'data']) {
      final nestedValue = _readFirstString(value[nestedKey], keys);
      if (nestedValue != null) {
        return nestedValue;
      }
    }

    for (final nestedKey in const [
      'quiz_attempt',
      'latest_quiz_attempt',
      'current_quiz_attempt',
      'attempt',
    ]) {
      final nestedValue = _readFirstString(value[nestedKey], keys);
      if (nestedValue != null) {
        return nestedValue;
      }
    }

    return null;
  }
}
