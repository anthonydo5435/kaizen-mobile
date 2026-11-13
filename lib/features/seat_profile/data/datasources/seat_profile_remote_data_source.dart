import '../../../../core/network/api_endpoints.dart';
import '../../../../core/network/api_error.dart';
import '../../../../core/network/api_processor.dart';
import '../../domain/entities/department.dart';
import '../../domain/entities/seat_profile_category_draft.dart';
import '../models/department_model.dart';
import '../models/seat_profile_creation_result_model.dart';
import '../models/seat_profile_detail_model.dart';
import '../models/seat_profile_page_model.dart';

class SeatProfileRemoteDataSource {
  SeatProfileRemoteDataSource({ApiCallExecutor? apiCallExecutor})
    : _apiCallExecutor = apiCallExecutor ?? const ApiCallExecutor();

  final ApiCallExecutor _apiCallExecutor;

  Future<String?> getSeatProfilePublicLink(String seatId) async {
    try {
      return await _apiCallExecutor.processApi<String?>(
        apiCallType: ApiCallType.get,
        endpoint: ApiEndPoints.seatProfilePublicLink(seatId),
        invalidateCacheBeforeRequest: true,
        decoder: _decodePublicLink,
      );
    } on ApiError catch (error) {
      if (error.statusCode == 404) return null;
      rethrow;
    }
  }

  Future<String> createSeatProfilePublicLink(String seatId) {
    return _apiCallExecutor.processApi<String>(
      apiCallType: ApiCallType.post,
      endpoint: ApiEndPoints.seatProfilePublicLink(seatId),
      decoder: (json) =>
          _decodePublicLink(json) ?? (throw const ApiError.invalidResponse()),
    );
  }

  Future<void> deleteSeatProfilePublicLink(String seatId) {
    return _apiCallExecutor.processApi<void>(
      apiCallType: ApiCallType.delete,
      endpoint: ApiEndPoints.seatProfilePublicLink(seatId),
      decoder: (_) {},
    );
  }

  String? _decodePublicLink(dynamic json) {
    if (json is! Map<String, dynamic>) {
      throw const ApiError.invalidResponse();
    }
    if (json['active'] == false) return null;
    final path = json['public_path'];
    final uri = path is String ? Uri.tryParse(path.trim()) : null;
    if (json['active'] != true ||
        json['view_type'] != 'seat_profile' ||
        uri == null ||
        uri.hasScheme ||
        uri.hasAuthority ||
        !uri.path.startsWith('/shared/seat-profile/') ||
        uri.pathSegments.last.isEmpty) {
      throw const ApiError.invalidResponse();
    }
    return Uri.parse(ApiEndPoints.publicWebBaseUrl).resolveUri(uri).toString();
  }

  Future<SeatProfilePageModel> getSeatProfiles({
    required int page,
    int pageSize = 10,
    String? departmentId,
    String title = '',
    bool forceRefresh = false,
  }) {
    return _apiCallExecutor.processApi<SeatProfilePageModel>(
      apiCallType: ApiCallType.get,
      endpoint: ApiEndPoints.jobs,
      invalidateCacheBeforeRequest: forceRefresh,
      parameters: {
        if (title.trim().isNotEmpty) 'title': title.trim(),
        'page': page,
        'page_size': pageSize,
        if (departmentId != null && departmentId.trim().isNotEmpty)
          'department': departmentId,
      },
      decoder: (json) {
        if (json is! Map<String, dynamic>) {
          throw const ApiError.invalidResponse();
        }

        return SeatProfilePageModel.fromApiJson(json, pageSize: pageSize);
      },
    );
  }

  Future<List<DepartmentModel>> getDepartments() {
    return _apiCallExecutor.processApi<List<DepartmentModel>>(
      apiCallType: ApiCallType.get,
      endpoint: ApiEndPoints.departments(),
      decoder: _decodeDepartments,
    );
  }

  Future<SeatProfileCreationResultModel> createSeatProfile({
    required Department department,
    required String title,
    required String paygradeUnit,
  }) {
    return _apiCallExecutor.processApi<SeatProfileCreationResultModel>(
      apiCallType: ApiCallType.post,
      endpoint: ApiEndPoints.jobs,
      parameters: <String, dynamic>{
        'department': <String, dynamic>{
          'uuid': department.id,
          'name': department.name,
          'color_hex': department.colorHex,
          'from_sandbox': department.fromSandbox,
          'drive_id': department.driveId,
        },
        'title': title,
        'paygrade_unit': paygradeUnit,
      },
      decoder: (json) {
        if (json is! Map<String, dynamic>) {
          throw const ApiError.invalidResponse();
        }

        return SeatProfileCreationResultModel.fromApiJson(json);
      },
    );
  }

  Future<void> updateSeatProfile({
    required String seatId,
    required Department department,
    required String title,
    required String paygradeUnit,
  }) {
    return _apiCallExecutor.processApi<void>(
      apiCallType: ApiCallType.patch,
      endpoint: ApiEndPoints.seatProfileJob(seatId),
      parameters: <String, dynamic>{
        'department': <String, dynamic>{
          'uuid': department.id,
          'name': department.name,
          'color_hex': department.colorHex,
          'from_sandbox': department.fromSandbox,
          'drive_id': department.driveId,
        },
        'title': title,
        'paygrade_unit': paygradeUnit,
      },
      decoder: (_) {},
    );
  }

  Future<void> generateSeatProfileJobContent({
    required String actualId,
    String? specificity,
    String? tone,
  }) {
    return _apiCallExecutor.processApi<void>(
      apiCallType: ApiCallType.put,
      endpoint: ApiEndPoints.generateSeatProfileJobContent(actualId),
      parameters: <String, dynamic>{
        if (specificity != null && specificity.trim().isNotEmpty)
          'specificity': specificity,
        if (tone != null && tone.trim().isNotEmpty) 'tone': tone,
      },
      decoder: (_) {},
    );
  }

  Future<void> bulkUpsertSeatProfileCategories({
    required String actualId,
    required List<SeatProfileCategoryDraft> categories,
  }) {
    return _apiCallExecutor.processApi<void>(
      apiCallType: ApiCallType.put,
      endpoint: ApiEndPoints.bulkUpsertSeatProfileCategories(actualId),
      parameters: <String, dynamic>{
        'categories': categories
            .map(
              (category) => <String, dynamic>{
                if ((category.uuid ?? '').trim().isNotEmpty)
                  'uuid': category.uuid!.trim(),
                'title': category.title,
                'weight_percent': _formatWeightPercent(category.weightPercent),
              },
            )
            .toList(growable: false),
      },
      decoder: (_) {},
    );
  }

  Future<void> createSeatProfileDescription({
    required String actualId,
    required String categoryId,
    required String descriptionName,
    required String auditSpecifics,
    required String auditFactorType,
    String? milestoneDays,
  }) {
    return _apiCallExecutor.processApi<void>(
      apiCallType: ApiCallType.post,
      endpoint: ApiEndPoints.jobCategoryDescriptions,
      parameters: <String, dynamic>{
        'id': null,
        'uuid': '',
        'description': descriptionName,
        'job_specifics': auditSpecifics,
        'milestone_day': _parseMilestoneDay(milestoneDays),
        'audit_factor_type': auditFactorType,
        'job': actualId,
        'job_category': categoryId,
      },
      decoder: (_) {},
    );
  }

  Future<void> updateSeatProfileDescription({
    required String descriptionId,
    required String descriptionName,
    required String auditSpecifics,
    required String auditFactorType,
    String? milestoneDays,
  }) {
    return _apiCallExecutor.processApi<void>(
      apiCallType: ApiCallType.patch,
      endpoint: ApiEndPoints.jobCategoryDescription(descriptionId),
      parameters: <String, dynamic>{
        'description': descriptionName,
        'job_specifics': auditSpecifics,
        'audit_factor_type': auditFactorType,
        'milestone_day': _parseMilestoneDay(milestoneDays),
      },
      decoder: (_) {},
    );
  }

  Future<void> deleteSeatProfileDescription({required String descriptionId}) {
    return _apiCallExecutor.processApi<void>(
      apiCallType: ApiCallType.delete,
      endpoint: ApiEndPoints.jobCategoryDescription(descriptionId),
      decoder: (_) {},
    );
  }

  Future<SeatProfileCreationResultModel> getSeatProfileJobContent(
    String actualId,
  ) {
    return _apiCallExecutor.processApi<SeatProfileCreationResultModel>(
      apiCallType: ApiCallType.get,
      endpoint: ApiEndPoints.seatProfileJobContent(actualId),
      decoder: (json) {
        if (json is! Map<String, dynamic>) {
          throw const ApiError.invalidResponse();
        }

        return SeatProfileCreationResultModel.fromApiJson(json);
      },
    );
  }

  Future<SeatProfileDetailModel> getSeatProfileDetail(String seatId) {
    return _apiCallExecutor.processApi<SeatProfileDetailModel>(
      apiCallType: ApiCallType.get,
      endpoint: ApiEndPoints.seatProfileJob(seatId),
      decoder: (json) {
        if (json is! Map<String, dynamic>) {
          throw const ApiError.invalidResponse();
        }

        return SeatProfileDetailModel.fromApiJson(json);
      },
    );
  }

  Future<SeatProfileDetailModel> getSharedSeatProfileDetail(String publicId) {
    return _apiCallExecutor.processApi<SeatProfileDetailModel>(
      apiCallType: ApiCallType.get,
      endpoint: ApiEndPoints.sharedContent(publicId),
      authToken: '',
      allowAutoRefresh: false,
      decoder: (json) {
        if (json is! Map) {
          throw const ApiError.invalidResponse();
        }

        return SeatProfileDetailModel.fromSharedContentJson(
          Map<String, dynamic>.from(json),
        );
      },
    );
  }

  Future<List<SeatProfileDetailModel>> getSeatProfileCategoryTrainings() {
    return _apiCallExecutor.processApi<List<SeatProfileDetailModel>>(
      apiCallType: ApiCallType.get,
      endpoint: ApiEndPoints.seatProfileCategoryTrainings,
      decoder: (json) {
        if (json is! List) {
          throw const ApiError.invalidResponse();
        }

        return json
            .whereType<Map<String, dynamic>>()
            .map(SeatProfileDetailModel.fromApiJson)
            .toList(growable: false);
      },
    );
  }
}

List<DepartmentModel> _decodeDepartments(dynamic json) {
  if (json is List) {
    return json
        .whereType<Map<String, dynamic>>()
        .map(DepartmentModel.fromApiJson)
        .toList(growable: false);
  }

  if (json is! Map<String, dynamic>) {
    throw const ApiError.invalidResponse();
  }

  final items = json['all'] ?? json['subordinate_departments'];
  if (items is! List) {
    throw const ApiError.invalidResponse();
  }

  return items
      .whereType<Map<String, dynamic>>()
      .map(DepartmentModel.fromApiJson)
      .toList(growable: false);
}

SeatProfileRemoteDataSource createSeatProfileRemoteDataSource() {
  return SeatProfileRemoteDataSource();
}

String _formatWeightPercent(double value) {
  if (value == value.roundToDouble()) {
    return value.toInt().toString();
  }

  return value.toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '');
}

int? _parseMilestoneDay(String? value) {
  final digits = value?.replaceAll(RegExp(r'[^0-9]'), '') ?? '';
  if (digits == '30' || digits == '60' || digits == '90') {
    return int.tryParse(digits);
  }

  return null;
}
