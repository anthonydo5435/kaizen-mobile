import '../../../../core/network/api_endpoints.dart';
import '../../../../core/network/api_error.dart';
import '../../../../core/network/api_processor.dart';
import '../../../seat_profile/data/models/department_model.dart';
import '../../../seat_profile/domain/entities/department.dart';
import '../../domain/entities/department_directory.dart';
import '../models/department_audit_stats_model.dart';

class DepartmentsRemoteDataSource {
  DepartmentsRemoteDataSource({ApiCallExecutor? apiCallExecutor})
    : _apiCallExecutor = apiCallExecutor ?? const ApiCallExecutor();

  final ApiCallExecutor _apiCallExecutor;

  Future<DepartmentDirectory> getDepartments() {
    return _apiCallExecutor.processApi<DepartmentDirectory>(
      apiCallType: ApiCallType.get,
      endpoint: ApiEndPoints.departments(),
      decoder: _decodeDepartmentDirectory,
    );
  }

  Future<DepartmentAuditStatsModel> getAuditStats(String departmentId) async {
    try {
      return await _apiCallExecutor.processApi<DepartmentAuditStatsModel>(
        apiCallType: ApiCallType.get,
        endpoint: ApiEndPoints.departmentAuditStats(departmentId),
        invalidateCacheBeforeRequest: true,
        decoder: DepartmentAuditStatsModel.fromApiJson,
      );
    } on ApiError catch (error) {
      if (error.statusCode != 404) rethrow;
      // The stats endpoint can return its empty result with HTTP 404.
      final data = error.responseData;
      if (data case {'score': 0, 'confidence_level': 0, 'job_stats': []}) {
        return DepartmentAuditStatsModel.fromApiJson(data);
      }
      rethrow;
    }
  }

  Future<void> updateDepartment({
    required Department department,
    required String name,
    required String colorHex,
  }) {
    return _apiCallExecutor.processApi<void>(
      apiCallType: ApiCallType.put,
      endpoint: ApiEndPoints.departmentDetail(department.id),
      parameters: <String, dynamic>{
        'name': name,
        'color_hex': colorHex,
        if (department.fromSandbox != null)
          'from_sandbox': department.fromSandbox,
        if ((department.driveId ?? '').trim().isNotEmpty)
          'drive_id': department.driveId!.trim(),
      },
      decoder: (_) {},
    );
  }
}

DepartmentDirectory _decodeDepartmentDirectory(dynamic json) {
  if (json is List) {
    return DepartmentDirectory(departments: _decodeDepartments(json));
  }

  if (json is! Map<String, dynamic>) {
    throw const ApiError.invalidResponse();
  }

  final items = json['all'] ?? json['results'] ?? json['departments'];
  if (items is! List) {
    throw const ApiError.invalidResponse();
  }

  final scopedItems = json['subordinate_departments'];
  if (scopedItems != null && scopedItems is! List) {
    throw const ApiError.invalidResponse();
  }

  return DepartmentDirectory(
    departments: _decodeDepartments(items),
    auditStatsDepartmentIds: scopedItems is List
        ? Set<String>.unmodifiable(
            _decodeDepartments(scopedItems).map((department) => department.id),
          )
        : null,
  );
}

List<DepartmentModel> _decodeDepartments(List<dynamic> items) =>
    List<DepartmentModel>.unmodifiable(
      items.whereType<Map<String, dynamic>>().map(DepartmentModel.fromApiJson),
    );

DepartmentsRemoteDataSource createDepartmentsRemoteDataSource() {
  return DepartmentsRemoteDataSource();
}
