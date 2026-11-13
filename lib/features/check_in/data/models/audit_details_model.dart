import '../../domain/entities/audit_details.dart';

class AuditDetailsModel extends AuditDetails {
  const AuditDetailsModel({
    required super.uuid,
    required super.lastAuditDate,
    required super.isFavorite,
    required super.overallScore,
    required super.confidenceLevel,
    required super.profiles,
    required super.profileJob,
    required super.profileUuid,
    required super.profileName,
    required super.profileEmail,
    required super.profileImage,
    required super.profileOnboarded,
    required super.jobUuid,
    required super.jobTitle,
    required super.audits,
  });

  factory AuditDetailsModel.fromApiJson(Map<String, dynamic> json) {
    final profile = _readMap(json['profile']);
    final job = _readMap(json['job']);
    final auditsJson = json['audits'];

    return AuditDetailsModel(
      uuid: _readString(json['uuid']) ?? '',
      lastAuditDate: _readString(json['last_audit_date']) ?? 'N/A',
      isFavorite: _readBool(json['is_favorite']) ?? false,
      overallScore: _readDouble(json['overall_score']) ?? 0,
      confidenceLevel: _readDouble(json['confidence_level']) ?? 0,
      profiles: _readProfiles(json['profiles']),
      profileJob: _readString(json['profile_job']) ?? '',
      profileUuid: _readString(profile?['uuid']) ?? '',
      profileName: _readString(profile?['name']) ?? '',
      profileEmail: _readString(profile?['email']) ?? '',
      profileImage: _readString(profile?['image']),
      profileOnboarded: _readBool(profile?['onboarded']) ?? true,
      jobUuid: _readString(job?['uuid']) ?? '',
      jobTitle: _readString(job?['title']) ?? '',
      audits: auditsJson is List
          ? auditsJson
                .map(_readMap)
                .whereType<Map<String, dynamic>>()
                .map(AuditDetailItemModel.fromApiJson)
                .toList(growable: false)
          : const <AuditDetailItem>[],
    );
  }

  static Map<String, dynamic>? _readMap(dynamic value) {
    return value is Map ? Map<String, dynamic>.from(value) : null;
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

  static double? _readDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value?.toString() ?? '');
  }

  static List<AuditDetailsProfile> _readProfiles(dynamic value) {
    if (value is! List) {
      return const <AuditDetailsProfile>[];
    }

    return value
        .map(_readMap)
        .whereType<Map<String, dynamic>>()
        .map(AuditDetailsProfileModel.fromApiJson)
        .toList(growable: false);
  }
}

class AuditDetailsProfileModel extends AuditDetailsProfile {
  const AuditDetailsProfileModel({
    required super.uuid,
    required super.name,
    required super.email,
    required super.image,
    required super.onboarded,
  });

  factory AuditDetailsProfileModel.fromApiJson(Map<String, dynamic> json) {
    return AuditDetailsProfileModel(
      uuid: _readString(json['uuid']) ?? '',
      name: _readString(json['name']) ?? '',
      email: _readString(json['email']) ?? '',
      image: _readString(json['image']),
      onboarded: _readBool(json['onboarded']) ?? true,
    );
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

class AuditDetailItemModel extends AuditDetailItem {
  const AuditDetailItemModel({
    super.quarterlyAuditUuid,
    required super.date,
    required super.great,
    required super.needsImprovement,
    required super.almostThere,
  });

  factory AuditDetailItemModel.fromApiJson(Map<String, dynamic> json) {
    final details = json['audit_details'];
    final auditDetails = details is Map
        ? Map<String, dynamic>.from(details)
        : null;

    return AuditDetailItemModel(
      quarterlyAuditUuid:
          _readString(json['quarterly_audit_uuid']) ??
          _readString(json['quarterlyAuditUuid']) ??
          '',
      date: _readString(json['date']) ?? '',
      great: _readInt(auditDetails?['great']) ?? 0,
      needsImprovement: _readInt(auditDetails?['needs_improvement']) ?? 0,
      almostThere: _readInt(auditDetails?['almost_there']) ?? 0,
    );
  }

  static String? _readString(dynamic value) {
    final resolved = value?.toString().trim();
    if (resolved == null || resolved.isEmpty) {
      return null;
    }

    return resolved;
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
}
