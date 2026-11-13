import '../../../../core/network/api_endpoints.dart';
import '../../../../core/network/api_error.dart';
import '../../../../core/network/api_processor.dart';
import '../../../seat_profile/data/models/department_model.dart';
import '../models/paygrade_detail_model.dart';
import '../models/paygrade_page_model.dart';
import '../models/shared_paygrades_content_model.dart';

class PaygradeRemoteDataSource {
  PaygradeRemoteDataSource({ApiCallExecutor? apiCallExecutor})
    : _apiCallExecutor = apiCallExecutor ?? const ApiCallExecutor();

  final ApiCallExecutor _apiCallExecutor;

  Future<String?> getPaygradesPublicLink(String jobId) async {
    try {
      return await _apiCallExecutor.processApi<String?>(
        apiCallType: ApiCallType.get,
        endpoint: ApiEndPoints.paygradesPublicLink(jobId),
        invalidateCacheBeforeRequest: true,
        decoder: _decodePublicLink,
      );
    } on ApiError catch (error) {
      if (error.statusCode == 404) return null;
      rethrow;
    }
  }

  Future<String> createPaygradesPublicLink(String jobId) {
    return _apiCallExecutor.processApi<String>(
      apiCallType: ApiCallType.post,
      endpoint: ApiEndPoints.paygradesPublicLink(jobId),
      decoder: (json) =>
          _decodePublicLink(json) ?? (throw const ApiError.invalidResponse()),
    );
  }

  Future<void> deletePaygradesPublicLink(String jobId) {
    return _apiCallExecutor.processApi<void>(
      apiCallType: ApiCallType.delete,
      endpoint: ApiEndPoints.paygradesPublicLink(jobId),
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
        json['view_type'] != 'paygrades' ||
        uri == null ||
        uri.hasScheme ||
        uri.hasAuthority ||
        !uri.path.startsWith('/shared/paygrades/') ||
        uri.pathSegments.last.isEmpty) {
      throw const ApiError.invalidResponse();
    }
    return Uri.parse(ApiEndPoints.publicWebBaseUrl).resolveUri(uri).toString();
  }

  Future<PaygradePageModel> getPaygrades({
    required int page,
    int pageSize = 10,
    String? departmentId,
    String name = '',
    String? title,
    bool forceRefresh = false,
  }) {
    return _apiCallExecutor.processApi<PaygradePageModel>(
      apiCallType: ApiCallType.get,
      endpoint: ApiEndPoints.payGrade,
      invalidateCacheBeforeRequest: forceRefresh,
      parameters: {
        if (title != null) 'department': departmentId?.trim() ?? '',
        if (title != null) 'title': title.trim(),
        if (title == null && (departmentId ?? '').trim().isNotEmpty)
          'department': departmentId!.trim(),
        if (title == null && name.trim().isNotEmpty) 'name': name.trim(),
        'page': page,
        'page_size': pageSize,
      },
      decoder: (json) {
        if (json is! Map<String, dynamic>) {
          throw const ApiError.invalidResponse();
        }

        return PaygradePageModel.fromApiJson(json, pageSize: pageSize);
      },
    );
  }

  Future<List<DepartmentModel>> getDepartments() {
    return getDepartmentsByAccess(isOwner: true);
  }

  Future<List<DepartmentModel>> getDepartmentsByAccess({
    required bool isOwner,
  }) {
    return _apiCallExecutor.processApi<List<DepartmentModel>>(
      apiCallType: ApiCallType.get,
      endpoint: ApiEndPoints.departments(),
      decoder: (json) => _decodeDepartments(json, isOwner: isOwner),
    );
  }

  Future<PaygradeDetailModel> getPaygradeDetail({
    required String paygradeId,
    required String type,
  }) {
    return _apiCallExecutor.processApi<PaygradeDetailModel>(
      apiCallType: ApiCallType.get,
      endpoint: ApiEndPoints.payGradeDetail(paygradeId),
      parameters: {'type': type},
      decoder: (json) {
        if (json is! Map<String, dynamic>) {
          throw const ApiError.invalidResponse();
        }

        return PaygradeDetailModel.fromApiJson(json);
      },
    );
  }

  Future<SharedPaygradesContentModel> getSharedPaygrades(String publicId) {
    return _apiCallExecutor.processApi<SharedPaygradesContentModel>(
      apiCallType: ApiCallType.get,
      endpoint: ApiEndPoints.sharedContent(publicId),
      authToken: '',
      allowAutoRefresh: false,
      decoder: (json) {
        if (json is! Map<String, dynamic>) {
          throw const ApiError.invalidResponse();
        }
        return SharedPaygradesContentModel.fromApiJson(json);
      },
    );
  }

  Future<void> generatePaygrades({
    required String actualId,
    required int numPaygrades,
  }) {
    return _apiCallExecutor.processApi<void>(
      apiCallType: ApiCallType.put,
      endpoint: ApiEndPoints.generatePayGrades(actualId),
      parameters: <String, dynamic>{'num_paygrades': numPaygrades},
      decoder: (_) {},
    );
  }

  Future<PaygradeEntryModel> createPaygrade({
    required String jobId,
    required String type,
    required String level,
    required String title,
    required String description,
    required String promotionRequirement,
    required int position,
    required bool fromSandbox,
    String? payRate,
  }) {
    final rate = payRate?.trim();
    return _apiCallExecutor.processApi<PaygradeEntryModel>(
      apiCallType: ApiCallType.post,
      endpoint: ApiEndPoints.payGrade,
      parameters: <String, dynamic>{
        'uuid': '',
        'level': level,
        'type': type,
        'title': title,
        'description': description,
        'promotion_requirement': promotionRequirement,
        'position': position,
        'from_sandbox': fromSandbox,
        'job': jobId,
        if (rate != null && rate.isNotEmpty) 'pay_rate': rate,
      },
      decoder: (json) {
        return PaygradeEntryModel.fromApiJson(_decodePaygradeEntryJson(json));
      },
    );
  }

  Future<void> updatePaygrade({
    required String paygradeId,
    required String title,
    required String description,
    required String promotionRequirement,
    String? payRate,
  }) {
    return _apiCallExecutor.processApi<void>(
      apiCallType: ApiCallType.patch,
      endpoint: ApiEndPoints.payGradeItem(paygradeId),
      parameters: <String, dynamic>{
        'uuid': paygradeId,
        'title': title,
        'description': description,
        'promotion_requirement': promotionRequirement,
        if (payRate != null) 'pay_rate': payRate,
      },
      decoder: (_) {},
    );
  }

  Future<void> updatePayRate({
    required String paygradeId,
    required String payRate,
  }) {
    return _apiCallExecutor.processApi<void>(
      apiCallType: ApiCallType.patch,
      endpoint: ApiEndPoints.payGradeItem(paygradeId),
      parameters: <String, dynamic>{'uuid': paygradeId, 'pay_rate': payRate},
      decoder: (_) {},
    );
  }

  Future<void> deletePaygrade(String paygradeId) {
    return _apiCallExecutor.processApi<void>(
      apiCallType: ApiCallType.delete,
      endpoint: ApiEndPoints.payGradeItem(paygradeId),
      decoder: (_) {},
    );
  }
}

List<DepartmentModel> _decodeDepartments(
  dynamic json, {
  required bool isOwner,
}) {
  if (json is List) {
    return json
        .whereType<Map<String, dynamic>>()
        .map(DepartmentModel.fromApiJson)
        .toList(growable: false);
  }

  if (json is! Map<String, dynamic>) {
    throw const ApiError.invalidResponse();
  }

  final items = isOwner
      ? (json['all'] ?? json['subordinate_departments'])
      : (json['subordinate_departments'] ?? json['all']);
  if (items is! List) {
    throw const ApiError.invalidResponse();
  }

  return items
      .whereType<Map<String, dynamic>>()
      .map(DepartmentModel.fromApiJson)
      .toList(growable: false);
}

Map<String, dynamic> _decodePaygradeEntryJson(dynamic json) {
  if (json is Map<String, dynamic>) {
    if (_looksLikePaygradeEntry(json)) {
      return json;
    }

    for (final key in const <String>[
      'data',
      'result',
      'pay_grade',
      'paygrade',
    ]) {
      final nestedValue = json[key];
      if (nestedValue is Map<String, dynamic> &&
          _looksLikePaygradeEntry(nestedValue)) {
        return nestedValue;
      }
    }
  }

  throw const ApiError.invalidResponse();
}

bool _looksLikePaygradeEntry(Map<String, dynamic> json) {
  return json.containsKey('uuid') ||
      json.containsKey('title') ||
      json.containsKey('description') ||
      json.containsKey('promotion_requirement');
}

PaygradeRemoteDataSource createPaygradeRemoteDataSource() {
  return PaygradeRemoteDataSource();
}
