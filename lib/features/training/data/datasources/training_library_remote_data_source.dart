import '../../../../core/network/api_endpoints.dart';
import '../../../../core/network/api_error.dart';
import '../../../../core/network/api_processor.dart';
import '../../domain/entities/lms_public_link.dart';
import '../models/training_library_page_model.dart';

class TrainingLibraryRemoteDataSource {
  TrainingLibraryRemoteDataSource({ApiCallExecutor? apiCallExecutor})
    : _apiCallExecutor = apiCallExecutor ?? const ApiCallExecutor();

  final ApiCallExecutor _apiCallExecutor;

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
}

TrainingLibraryRemoteDataSource createTrainingLibraryRemoteDataSource() {
  return TrainingLibraryRemoteDataSource();
}
