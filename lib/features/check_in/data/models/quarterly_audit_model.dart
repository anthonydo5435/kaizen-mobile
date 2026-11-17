import '../../domain/entities/quarterly_audit.dart';
import '../../../training/domain/entities/seat_description_training_route.dart';

class QuarterlyAuditModel extends QuarterlyAudit {
  const QuarterlyAuditModel({
    required super.uuid,
    required super.jobUuid,
    required super.jobTitle,
    required super.isMismatch,
    required super.profileUuid,
    required super.profileName,
    required super.profileEmail,
    required super.profileImage,
    required super.profileOnboarded,
    required super.profileJob,
    required super.categories,
    required super.descriptions,
  });

  factory QuarterlyAuditModel.fromApiJson(Map<String, dynamic> json) {
    final job = _readMap(json['job']);
    final profile = _readMap(json['profile']);
    final categoriesJson = json['categories'];
    final descriptionsJson = json['descriptions'];

    return QuarterlyAuditModel(
      uuid: _readString(json['uuid']) ?? '',
      jobUuid: _readString(job?['uuid']) ?? '',
      jobTitle: _readString(job?['title']) ?? '',
      isMismatch:
          _readBool(json['mismatch']) ??
          _readBool(json['is_mismatch']) ??
          false,
      profileUuid: _readString(profile?['uuid']) ?? '',
      profileName: _readString(profile?['name']) ?? '',
      profileEmail: _readString(profile?['email']) ?? '',
      profileImage: _readString(profile?['image']),
      profileOnboarded: _readBool(profile?['onboarded']) ?? true,
      profileJob: _readString(json['profile_job']) ?? '',
      categories: categoriesJson is List
          ? categoriesJson
                .whereType<Map<String, dynamic>>()
                .map(QuarterlyAuditCategoryModel.fromApiJson)
                .toList(growable: false)
          : const <QuarterlyAuditCategory>[],
      descriptions: descriptionsJson is List
          ? descriptionsJson
                .whereType<Map<String, dynamic>>()
                .map(QuarterlyAuditDescriptionModel.fromApiJson)
                .toList(growable: false)
          : const <QuarterlyAuditDescription>[],
    );
  }

  static Map<String, dynamic>? _readMap(dynamic value) {
    return value is Map<String, dynamic> ? value : null;
  }

  static String? _readString(dynamic value) {
    final resolved = value?.toString().trim();
    if (resolved == null || resolved.isEmpty) {
      return null;
    }

    return resolved;
  }

  static bool? _readBool(dynamic value) {
    if (value is bool) {
      return value;
    }

    final normalized = value?.toString().trim().toLowerCase();
    if (normalized == 'true') {
      return true;
    }
    if (normalized == 'false') {
      return false;
    }

    return null;
  }
}

class QuarterlyAuditCategoryModel extends QuarterlyAuditCategory {
  const QuarterlyAuditCategoryModel({
    required super.uuid,
    required super.categoryTitle,
  });

  factory QuarterlyAuditCategoryModel.fromApiJson(Map<String, dynamic> json) {
    return QuarterlyAuditCategoryModel(
      uuid: _readString(json['uuid']) ?? '',
      categoryTitle: _readString(json['category_title']) ?? '',
    );
  }

  static String? _readString(dynamic value) {
    final resolved = value?.toString().trim();
    if (resolved == null || resolved.isEmpty) {
      return null;
    }

    return resolved;
  }
}

class QuarterlyAuditDescriptionModel extends QuarterlyAuditDescription {
  const QuarterlyAuditDescriptionModel({
    required super.uuid,
    required super.category,
    required super.isMirror,
    required super.description,
    required super.jobSpecifics,
    required super.trainingRoute,
    required super.great,
    required super.needsImprovement,
    required super.almostThere,
    required super.pass,
    required super.noPass,
    required super.hasAudit,
    required super.auditUuid,
    required super.milestoneDay,
    required super.lastAuditDate,
    required super.confidenceLevel,
    required super.auditFactorType,
  });

  factory QuarterlyAuditDescriptionModel.fromApiJson(
    Map<String, dynamic> json,
  ) {
    final auditDetails = _readMap(json['audit_details']);
    final trainingRoute = _readMap(json['training_route']);

    return QuarterlyAuditDescriptionModel(
      uuid: _readString(json['uuid']) ?? '',
      category: _readString(json['category']) ?? '',
      isMirror: _readBool(json['is_mirror'] ?? json['isMirror']) ?? false,
      description: _readString(json['description']) ?? '',
      jobSpecifics: _readString(json['job_specifics']) ?? '',
      trainingRoute: SeatDescriptionTrainingRoute(
        job: _readString(trainingRoute?['job']) ?? '',
        category: _readString(trainingRoute?['category']) ?? '',
        description: _readString(trainingRoute?['description']) ?? '',
      ),
      great: _readInt(auditDetails?['great']) ?? 0,
      needsImprovement: _readInt(auditDetails?['needs_improvement']) ?? 0,
      almostThere: _readInt(auditDetails?['almost_there']) ?? 0,
      pass: _readInt(auditDetails?['pass']) ?? 0,
      noPass: _readInt(auditDetails?['no_pass']) ?? 0,
      hasAudit: _readBool(auditDetails?['has_audit']) ?? false,
      auditUuid: _readString(auditDetails?['audit_uuid']) ?? '',
      milestoneDay: _readString(json['milestone_day']) ?? '',
      lastAuditDate: _readString(json['last_audit_date']),
      confidenceLevel: _readDouble(json['confidence_level']) ?? 0,
      auditFactorType: _readString(json['audit_factor_type']) ?? '',
    );
  }

  static Map<String, dynamic>? _readMap(dynamic value) {
    return value is Map<String, dynamic> ? value : null;
  }

  static String? _readString(dynamic value) {
    final resolved = value?.toString().trim();
    if (resolved == null || resolved.isEmpty) {
      return null;
    }

    return resolved;
  }

  static bool? _readBool(dynamic value) {
    if (value is bool) {
      return value;
    }

    final normalized = value?.toString().trim().toLowerCase();
    if (normalized == 'true') {
      return true;
    }
    if (normalized == 'false') {
      return false;
    }

    return null;
  }

  static int? _readInt(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value?.toString() ?? '');
  }

  static double? _readDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value?.toString() ?? '');
  }
}
