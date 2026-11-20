import '../../../../core/network/api_error.dart';
import '../../domain/entities/department_audit_stats.dart';

class DepartmentAuditStatsModel extends DepartmentAuditStats {
  const DepartmentAuditStatsModel({
    required super.score,
    required super.confidenceLevel,
    required super.jobStats,
  });

  factory DepartmentAuditStatsModel.fromApiJson(dynamic json) {
    if (json is! Map<String, dynamic> || json['job_stats'] is! List) {
      throw const ApiError.invalidResponse();
    }

    final jobs = json['job_stats'] as List;
    return DepartmentAuditStatsModel(
      score: _readNumber(json['score']).toDouble(),
      confidenceLevel: _readNumber(json['confidence_level']).toDouble(),
      jobStats: List<DepartmentJobAuditStats>.unmodifiable(
        jobs.map(_decodeJob),
      ),
    );
  }

  static DepartmentJobAuditStats _decodeJob(dynamic json) {
    if (json is! Map<String, dynamic> ||
        json['uuid'] is! String ||
        json['name'] is! String) {
      throw const ApiError.invalidResponse();
    }

    return DepartmentJobAuditStats(
      id: json['uuid'] as String,
      name: json['name'] as String,
      totalMembers: _readNumber(json['total_members']).toInt(),
      score: _readNumber(json['score']).toDouble(),
      confidenceLevel: _readNumber(json['confidence_level']).toDouble(),
    );
  }

  static num _readNumber(Object? value) {
    if (value is num && value.isFinite) return value;
    throw const ApiError.invalidResponse();
  }
}
