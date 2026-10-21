import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../../../core/network/api_endpoints.dart';
import '../../../../core/network/api_error.dart';
import '../../../../core/network/api_processor.dart';
import '../../../../core/preference/app_preference.dart';
import '../../../../core/services/file_uploader.dart';
import '../../domain/entities/lms_public_link.dart';
import '../../domain/entities/seat_description_training.dart';
import '../models/seat_description_training_model.dart';
import '../models/training_library_page_model.dart';

class TrainingLibraryRemoteDataSource {
  TrainingLibraryRemoteDataSource({
    ApiCallExecutor? apiCallExecutor,
    FileUploader? fileUploader,
  }) : _apiCallExecutor = apiCallExecutor ?? const ApiCallExecutor(),
       _fileUploader = fileUploader ?? const FileUploader();

  final ApiCallExecutor _apiCallExecutor;
  final FileUploader _fileUploader;

  Future<LmsPublicLink?> getLmsPublicLink(String descriptionId) async {
    try {
      return await _apiCallExecutor.processApi<LmsPublicLink?>(
        apiCallType: ApiCallType.get,
        endpoint: ApiEndPoints.lmsPublicLink(descriptionId),
        invalidateCacheBeforeRequest: true,
        decoder: _decodePublicLink,
      );
    } on ApiError catch (error) {
      if (error.statusCode == 404) return null;
      rethrow;
    }
  }

  Future<LmsPublicLink> createLmsPublicLink({
    required String descriptionId,
    required List<String> trainingModuleUuids,
  }) {
    return _apiCallExecutor.processApi<LmsPublicLink>(
      apiCallType: ApiCallType.post,
      endpoint: ApiEndPoints.lmsPublicLink(descriptionId),
      parameters: <String, dynamic>{
        'view_type': 'lms',
        'public_path': '',
        'training_module_uuids': trainingModuleUuids,
      },
      decoder: (json) =>
          _decodePublicLink(json) ?? (throw const ApiError.invalidResponse()),
    );
  }

  Future<void> deleteLmsPublicLink(String descriptionId) {
    return _apiCallExecutor.processApi<void>(
      apiCallType: ApiCallType.delete,
      endpoint: ApiEndPoints.lmsPublicLink(descriptionId),
      decoder: (_) {},
    );
  }

  LmsPublicLink? _decodePublicLink(dynamic json) {
    if (json is! Map<String, dynamic>) {
      throw const ApiError.invalidResponse();
    }
    if (json['active'] == false) return null;
    final path = json['public_path'];
    final uri = path is String ? Uri.tryParse(path.trim()) : null;
    final moduleUuids = json['training_module_uuids'];
    if (json['active'] != true ||
        json['view_type'] != 'lms' ||
        uri == null ||
        uri.hasScheme ||
        uri.hasAuthority ||
        !uri.path.startsWith('/shared/lms/') ||
        uri.pathSegments.last.isEmpty ||
        moduleUuids is! List ||
        moduleUuids.isEmpty ||
        moduleUuids.any((id) => id is! String || id.trim().isEmpty)) {
      throw const ApiError.invalidResponse();
    }
    return LmsPublicLink(
      url: Uri.parse(ApiEndPoints.publicWebBaseUrl).resolveUri(uri).toString(),
      trainingModuleUuids: moduleUuids.cast<String>(),
    );
  }

  Future<TrainingLibraryPageModel> getTrainingLibraryModules({
    required String view,
    required int page,
    int pageSize = 10,
    String searchType = 'category',
    String searchText = '',
    String? departmentId,
    String? jobId,
    String? jobCategoryId,
    String? jobCategoryDescriptionId,
    bool forceRefresh = false,
  }) {
    return _apiCallExecutor.processApi<TrainingLibraryPageModel>(
      apiCallType: ApiCallType.get,
      endpoint: ApiEndPoints.trainingModulesAll,
      invalidateCacheBeforeRequest: forceRefresh,
      parameters: <String, dynamic>{
        if (jobId?.trim().isNotEmpty ?? false) 'job': jobId!.trim(),
        if (jobCategoryId?.trim().isNotEmpty ?? false)
          'job_category': jobCategoryId!.trim(),
        if (jobCategoryDescriptionId?.trim().isNotEmpty ?? false)
          'job_category_description': jobCategoryDescriptionId!.trim(),
        'page': page,
        'page_size': pageSize,
        'view': view,
        'searchType': searchType,
        if (departmentId?.trim().isNotEmpty ?? false)
          'department': departmentId!.trim(),
        if (searchText.trim().isNotEmpty) 'search': searchText.trim(),
      },
      decoder: (json) {
        if (json is Map<String, dynamic>) {
          return TrainingLibraryPageModel.fromApiJson(json, pageSize: pageSize);
        }

        if (json is List) {
          return TrainingLibraryPageModel.fromLegacyList(
            json.whereType<Map<String, dynamic>>().toList(growable: false),
            pageSize: pageSize,
          );
        }

        if (json == null) {
          throw const ApiError.invalidResponse();
        }
        throw const ApiError.invalidResponse();
      },
    );
  }

  Future<List<SeatDescriptionTrainingModule>>
  getSeatDescriptionTrainingModules({
    required String descriptionId,
    bool forceRefresh = false,
  }) {
    return _apiCallExecutor.processApi<List<SeatDescriptionTrainingModule>>(
      apiCallType: ApiCallType.get,
      endpoint: ApiEndPoints.seatDescriptionTrainingModules(descriptionId),
      authToken: AppPreference.getAuthToken(),
      invalidateCacheBeforeRequest: forceRefresh,
      decoder: (json) {
        if (json is! List) {
          throw const ApiError.invalidResponse();
        }

        return json
            .whereType<Map>()
            .map(
              (item) => SeatDescriptionTrainingModuleModel.fromApiJson(
                Map<String, dynamic>.from(item),
              ),
            )
            .toList(growable: false);
      },
    );
  }

  Future<SeatDescriptionTrainingModule> createSeatDescriptionTrainingModule({
    required String jobId,
    required String descriptionId,
    required String title,
  }) {
    return _apiCallExecutor.processApi<SeatDescriptionTrainingModule>(
      apiCallType: ApiCallType.post,
      endpoint: ApiEndPoints.trainingModules,
      authToken: AppPreference.getAuthToken(),
      parameters: {
        'job': jobId,
        'job_category_description': descriptionId,
        'title': title,
      },
      decoder: (json) {
        if (json is! Map<String, dynamic>) {
          throw const ApiError.invalidResponse();
        }

        return SeatDescriptionTrainingModuleModel.fromApiJson(json);
      },
    );
  }

  Future<SeatDescriptionTrainingModuleDetail>
  getSeatDescriptionTrainingModuleDetail({
    required String moduleId,
    bool forceRefresh = false,
  }) {
    return _apiCallExecutor.processApi<SeatDescriptionTrainingModuleDetail>(
      apiCallType: ApiCallType.get,
      endpoint: ApiEndPoints.trainingModuleDetail(moduleId),
      authToken: AppPreference.getAuthToken(),
      invalidateCacheBeforeRequest: forceRefresh,
      decoder: (json) {
        if (json is! Map<String, dynamic>) {
          throw const ApiError.invalidResponse();
        }

        return SeatDescriptionTrainingModuleDetailModel.fromApiJson(json);
      },
    );
  }

  Future<SeatDescriptionTrainingDocument>
  getSeatDescriptionTrainingModuleDocument({required String moduleId}) {
    return _apiCallExecutor.processApi<SeatDescriptionTrainingDocument>(
      apiCallType: ApiCallType.get,
      endpoint: ApiEndPoints.trainingModuleDocument(moduleId),
      authToken: AppPreference.getAuthToken(),
      decoder: (json) {
        if (json == null) {
          return const SeatDescriptionTrainingDocumentModel(
            uuid: '',
            text: null,
          );
        }

        if (json is Map<String, dynamic>) {
          return SeatDescriptionTrainingDocumentModel.fromApiJson(json);
        }

        if (json is Map) {
          return SeatDescriptionTrainingDocumentModel.fromApiJson(
            Map<String, dynamic>.from(json),
          );
        }

        if (json is List && json.isEmpty) {
          return const SeatDescriptionTrainingDocumentModel(
            uuid: '',
            text: null,
          );
        }

        throw const ApiError.invalidResponse();
      },
    );
  }

  Future<SeatDescriptionTrainingAssignment>
  getSeatDescriptionTrainingModuleAssignment({required String moduleId}) {
    return _apiCallExecutor.processApi<SeatDescriptionTrainingAssignment>(
      apiCallType: ApiCallType.get,
      endpoint: ApiEndPoints.trainingModuleAssignment(moduleId),
      authToken: AppPreference.getAuthToken(),
      decoder: (json) {
        if (json == null) {
          return const SeatDescriptionTrainingAssignmentModel(
            uuid: '',
            title: null,
            instructions: null,
          );
        }

        if (json is Map<String, dynamic>) {
          return SeatDescriptionTrainingAssignmentModel.fromApiJson(json);
        }

        if (json is Map) {
          return SeatDescriptionTrainingAssignmentModel.fromApiJson(
            Map<String, dynamic>.from(json),
          );
        }

        if (json is List && json.isEmpty) {
          return const SeatDescriptionTrainingAssignmentModel(
            uuid: '',
            title: null,
            instructions: null,
          );
        }

        throw const ApiError.invalidResponse();
      },
    );
  }

  Future<List<SeatDescriptionTrainingQuestion>>
  getSeatDescriptionTrainingModuleQuestions({required String moduleId}) {
    return _apiCallExecutor.processApi<List<SeatDescriptionTrainingQuestion>>(
      apiCallType: ApiCallType.get,
      endpoint: ApiEndPoints.trainingModuleQuestions(moduleId),
      authToken: AppPreference.getAuthToken(),
      decoder: (json) {
        final questionsJson = switch (json) {
          List<dynamic> list => list,
          Map<String, dynamic> map => map['questions'],
          Map map => Map<String, dynamic>.from(map)['questions'],
          _ => null,
        };
        if (questionsJson is! List) {
          throw const ApiError.invalidResponse();
        }

        return questionsJson
            .whereType<Map>()
            .map(
              (item) => SeatDescriptionTrainingQuestionModel.fromApiJson(
                Map<String, dynamic>.from(item),
              ),
            )
            .toList(growable: false);
      },
    );
  }

  Future<SeatDescriptionTrainingQuestion> addSeatDescriptionTrainingQuestion({
    required String moduleId,
    required String questionText,
    required List<SeatDescriptionTrainingQuestionOption> options,
    required String correctOptionUuid,
    String? imageId,
  }) {
    return _apiCallExecutor.processApi<SeatDescriptionTrainingQuestion>(
      apiCallType: ApiCallType.put,
      endpoint: ApiEndPoints.addTrainingModuleQuestion(moduleId),
      authToken: AppPreference.getAuthToken(),
      parameters: {
        'uuid': '',
        'question': questionText,
        if (imageId != null && imageId.trim().isNotEmpty)
          'image': imageId.trim(),
        'correct_option': correctOptionUuid,
        'options': options
            .map((option) => {'uuid': option.uuid, 'text': option.text})
            .toList(growable: false),
      },
      decoder: (json) {
        if (json is! Map<String, dynamic>) {
          throw const ApiError.invalidResponse();
        }

        return SeatDescriptionTrainingQuestionModel.fromApiJson(json);
      },
    );
  }

  Future<String> uploadTrainingQuestionImage({
    required String fileName,
    required List<int> fileBytes,
    required String contentType,
  }) async {
    final uploadedImage = await _fileUploader.uploadOnboardingImage(
      fileName: fileName,
      fileBytes: fileBytes,
      contentType: contentType,
    );
    return uploadedImage.uuid;
  }

  Future<void> generateSeatDescriptionTrainingModuleQuiz({
    required String moduleId,
    required int numQuestions,
    required int optionsPerQuestion,
    required String difficultyLevel,
    required bool replaceExistingQuestions,
  }) {
    return _apiCallExecutor.processApi<void>(
      apiCallType: ApiCallType.put,
      endpoint: ApiEndPoints.generateTrainingModuleQuiz(moduleId),
      authToken: AppPreference.getAuthToken(),
      parameters: {
        'num_questions': numQuestions,
        'difficulty_level': difficultyLevel,
        'replace_existing_questions': replaceExistingQuestions,
        'options_per_question': optionsPerQuestion,
      },
      decoder: (_) {},
    );
  }

  Future<void> generateSeatDescriptionTrainingModuleSop({
    required String moduleId,
  }) {
    return _apiCallExecutor.processApi<void>(
      apiCallType: ApiCallType.put,
      endpoint: ApiEndPoints.generateTrainingModuleSop(moduleId),
      authToken: AppPreference.getAuthToken(),
      decoder: (_) {},
    );
  }

  Future<void> generateSeatDescriptionTrainingModuleAssignment({
    required String moduleId,
  }) {
    return _apiCallExecutor.processApi<void>(
      apiCallType: ApiCallType.put,
      endpoint: ApiEndPoints.generateTrainingModuleAssignment(moduleId),
      authToken: AppPreference.getAuthToken(),
      decoder: (_) {},
    );
  }

  Future<String?> generateSeatDescriptionTrainingModuleSummary({
    required String moduleId,
  }) {
    return _apiCallExecutor.processApi<String?>(
      apiCallType: ApiCallType.put,
      endpoint: ApiEndPoints.generateTrainingModuleSummary(moduleId),
      authToken: AppPreference.getAuthToken(),
      decoder: (json) {
        if (json is Map<String, dynamic>) {
          return _readFirstString(json, const ['description']);
        }

        if (json is Map) {
          return _readFirstString(Map<String, dynamic>.from(json), const [
            'description',
          ]);
        }

        if (json == null) {
          return null;
        }

        throw const ApiError.invalidResponse();
      },
    );
  }

  Future<void> updateSeatDescriptionTrainingModule({
    required String moduleId,
    String? title,
    String? description,
  }) {
    final parameters = <String, dynamic>{};
    if (title != null) {
      parameters['title'] = title.trim();
    }
    if (description != null) {
      parameters['description'] = description.trim();
    }
    if (parameters.isEmpty) {
      return Future<void>.value();
    }

    return _apiCallExecutor.processApi<void>(
      apiCallType: ApiCallType.patch,
      endpoint: ApiEndPoints.trainingModuleDetail(moduleId),
      authToken: AppPreference.getAuthToken(),
      parameters: parameters,
      decoder: (_) {},
    );
  }

  Future<void> updateSeatDescriptionTrainingModuleSummary({
    required String moduleId,
    required String description,
    required bool isPubliclyAvailable,
  }) {
    return _apiCallExecutor.processApi<void>(
      apiCallType: ApiCallType.patch,
      endpoint: ApiEndPoints.trainingModuleDetail(moduleId),
      authToken: AppPreference.getAuthToken(),
      parameters: {
        'description': description.trim(),
        'is_publicly_available': isPubliclyAvailable,
      },
      decoder: (_) {},
    );
  }

  Future<void> updateSeatDescriptionTrainingModuleVisibility({
    required String moduleId,
    required bool isPubliclyAvailable,
  }) {
    return _apiCallExecutor.processApi<void>(
      apiCallType: ApiCallType.patch,
      endpoint: ApiEndPoints.trainingModuleDetail(moduleId),
      authToken: AppPreference.getAuthToken(),
      parameters: {'is_publicly_available': isPubliclyAvailable},
      decoder: (_) {},
    );
  }

  Future<String> getTrainingDocumentPdfUrl({required String documentId}) {
    return _apiCallExecutor.processApi<String>(
      apiCallType: ApiCallType.put,
      endpoint: ApiEndPoints.trainingDocumentPdf(documentId.trim()),
      decoder: (json) {
        final pdf = json is Map<String, dynamic> ? json['pdf'] : null;
        final uri = pdf is String ? Uri.tryParse(pdf.trim()) : null;
        if (uri == null ||
            !const ['http', 'https'].contains(uri.scheme) ||
            uri.host.isEmpty) {
          throw const ApiError.invalidResponse();
        }
        return uri.toString();
      },
    );
  }

  Future<void> updateSeatDescriptionTrainingModuleDocument({
    required String moduleId,
    required String documentId,
    required String text,
  }) {
    final resolvedDocumentId = documentId.trim();
    return _apiCallExecutor.processApi<void>(
      apiCallType: ApiCallType.patch,
      endpoint: ApiEndPoints.trainingDocument(resolvedDocumentId),
      authToken: AppPreference.getAuthToken(),
      parameters: {'uuid': resolvedDocumentId, 'text': text.trim()},
      decoder: (_) {},
    );
  }

  Future<void> updateSeatDescriptionTrainingModuleAssignment({
    required String moduleId,
    String? assignmentId,
    String? title,
    required String instructions,
  }) {
    final resolvedAssignmentId = assignmentId?.trim() ?? '';
    return _apiCallExecutor.processApi<void>(
      apiCallType: resolvedAssignmentId.isNotEmpty
          ? ApiCallType.patch
          : ApiCallType.put,
      endpoint: resolvedAssignmentId.isNotEmpty
          ? ApiEndPoints.trainingAssignment(resolvedAssignmentId)
          : ApiEndPoints.addTrainingModuleAssignment(moduleId),
      authToken: AppPreference.getAuthToken(),
      parameters: {
        if (title != null) 'title': title.trim(),
        'instructions': instructions.trim(),
      },
      decoder: (_) {},
    );
  }

  Future<String> generateSeatDescriptionTrainingModuleVideoUploadUrl({
    required String fileName,
  }) {
    return _apiCallExecutor.processApi<String>(
      apiCallType: ApiCallType.post,
      endpoint: ApiEndPoints.generatePreSignedUrl,
      authToken: AppPreference.getAuthToken(),
      parameters: {'key': 'lms', 'file_name': fileName},
      decoder: (json) {
        final uploadUrl = _readFirstString(json, const ['signedUrl']);
        if (uploadUrl == null || uploadUrl.isEmpty) {
          throw const ApiError.invalidResponse();
        }

        return uploadUrl;
      },
    );
  }

  Future<void> uploadSeatDescriptionTrainingModuleVideoFile({
    required String uploadUrl,
    required String fileName,
    required List<int> fileBytes,
    required String contentType,
    ValueChanged<double>? onProgress,
  }) async {
    final uri = Uri.tryParse(uploadUrl);
    if (uri == null) {
      throw const ApiError.invalidUrl();
    }

    final request = _ProgressByteRequest(
      'PUT',
      uri,
      fileBytes: fileBytes,
      contentType: contentType,
      onProgress: onProgress,
    );

    final client = http.Client();
    late final http.Response response;
    try {
      final streamedResponse = await client.send(request);
      response = await http.Response.fromStream(streamedResponse);
    } finally {
      client.close();
    }

    if (response.statusCode < 200 || response.statusCode > 299) {
      throw ApiError.requestFailed(response.statusCode);
    }
  }

  Future<SeatDescriptionTrainingVideo> addSeatDescriptionTrainingModuleVideo({
    required String moduleId,
    required String videoUuid,
    required String title,
    required String videoUrl,
    required int duration,
  }) {
    return _apiCallExecutor.processApi<SeatDescriptionTrainingVideo>(
      apiCallType: ApiCallType.put,
      endpoint: ApiEndPoints.addTrainingModuleVideo(moduleId),
      authToken: AppPreference.getAuthToken(),
      parameters: {
        'uuid': videoUuid,
        'title': title,
        'url': videoUrl,
        'duration': duration,
      },
      decoder: (json) {
        if (json is! Map<String, dynamic>) {
          throw const ApiError.invalidResponse();
        }

        return SeatDescriptionTrainingVideoModel.fromApiJson(json);
      },
    );
  }

  Future<void> deleteSeatDescriptionTrainingModuleVideo({
    required String videoId,
  }) {
    return _apiCallExecutor.processApi<void>(
      apiCallType: ApiCallType.delete,
      endpoint: ApiEndPoints.trainingVideoDetail(videoId),
      authToken: AppPreference.getAuthToken(),
      decoder: (_) {},
    );
  }

  Future<void> updateSeatDescriptionTrainingModuleThumbnail({
    required String moduleId,
    required String thumbnailUrl,
  }) {
    return _apiCallExecutor.processApi<void>(
      apiCallType: ApiCallType.patch,
      endpoint: ApiEndPoints.trainingModuleDetail(moduleId),
      authToken: AppPreference.getAuthToken(),
      parameters: {
        'thumbnail_link': thumbnailUrl.trim(),
        'thumbnails': <String>[thumbnailUrl.trim()],
      },
      decoder: (_) {},
    );
  }

  Future<void> deleteSeatDescriptionTrainingModule({required String moduleId}) {
    return _apiCallExecutor.processApi<void>(
      apiCallType: ApiCallType.delete,
      endpoint: ApiEndPoints.trainingModuleDetail(moduleId),
      authToken: AppPreference.getAuthToken(),
      decoder: (_) {},
    );
  }

  Future<SeatDescriptionTrainingQuestion>
  updateSeatDescriptionTrainingQuestion({
    required String questionId,
    required String questionText,
    required List<SeatDescriptionTrainingQuestionOption> options,
    String? correctOptionUuid,
  }) {
    return _apiCallExecutor.processApi<SeatDescriptionTrainingQuestion>(
      apiCallType: ApiCallType.patch,
      endpoint: ApiEndPoints.updateQuestion(questionId),
      authToken: AppPreference.getAuthToken(),
      parameters: {
        'uuid': questionId,
        'question': questionText,
        'options': options
            .map((option) => {'uuid': option.uuid, 'text': option.text})
            .toList(growable: false),
        'correct_option': correctOptionUuid,
      },
      decoder: (json) {
        if (json is! Map<String, dynamic>) {
          throw const ApiError.invalidResponse();
        }

        return SeatDescriptionTrainingQuestionModel.fromApiJson(json);
      },
    );
  }

  Future<void> deleteSeatDescriptionTrainingQuestion({
    required String questionId,
  }) {
    return _apiCallExecutor.processApi<void>(
      apiCallType: ApiCallType.delete,
      endpoint: ApiEndPoints.updateQuestion(questionId),
      authToken: AppPreference.getAuthToken(),
      decoder: (_) {},
    );
  }

  String? _readFirstString(dynamic json, List<String> keys) {
    if (json is! Map) {
      return null;
    }

    for (final key in keys) {
      final value = json[key]?.toString().trim();
      if (value != null && value.isNotEmpty) {
        return value;
      }
    }

    return null;
  }
}

TrainingLibraryRemoteDataSource createTrainingLibraryRemoteDataSource() {
  return TrainingLibraryRemoteDataSource();
}

class _ProgressByteRequest extends http.BaseRequest {
  _ProgressByteRequest(
    super.method,
    super.url, {
    required this.fileBytes,
    required this.contentType,
    this.onProgress,
  }) {
    headers['Content-Type'] = contentType;
  }

  final List<int> fileBytes;
  final String contentType;
  final ValueChanged<double>? onProgress;

  @override
  http.ByteStream finalize() {
    final totalBytes = fileBytes.length;
    var sentBytes = 0;
    contentLength = totalBytes;
    super.finalize();

    final stream = Stream<List<int>>.fromIterable([fileBytes]).transform(
      StreamTransformer<List<int>, List<int>>.fromHandlers(
        handleData: (chunk, sink) {
          sentBytes += chunk.length;
          if (totalBytes > 0) {
            onProgress?.call((sentBytes / totalBytes).clamp(0, 1).toDouble());
          }
          sink.add(chunk);
        },
      ),
    );

    return http.ByteStream(stream);
  }
}
