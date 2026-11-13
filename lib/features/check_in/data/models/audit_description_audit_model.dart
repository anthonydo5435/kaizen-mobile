import '../../domain/entities/audit_description_audit.dart';

class AuditDescriptionAuditModel extends AuditDescriptionAudit {
  const AuditDescriptionAuditModel({
    required super.uuid,
    required super.audit,
    required super.isGeneral,
    required super.isMirror,
    required super.auditMedia,
    required super.weightedScore,
    super.ratingCounts,
  });

  factory AuditDescriptionAuditModel.fromApiJson(Map<String, dynamic> json) {
    final auditMediaJson = json['audit_media'];

    return AuditDescriptionAuditModel(
      uuid: _readString(json['uuid']) ?? '',
      audit: _readAuditRatings(json['audit']),
      ratingCounts: _readRatingCounts(json['audit']),
      isGeneral: _readBool(json['is_general']) ?? false,
      isMirror: _readBool(json['is_mirror']) ?? false,
      auditMedia: auditMediaJson is List
          ? auditMediaJson
                .map(_readMap)
                .whereType<Map<String, dynamic>>()
                .map(AuditDescriptionMediaModel.fromApiJson)
                .toList(growable: false)
          : const <AuditDescriptionMedia>[],
      weightedScore: _readDouble(json['weighted_score']) ?? 0,
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

  static Map<String, int>? _readRatingCounts(dynamic value) {
    if (value is! Map) return null;

    final counts = <String, int>{};
    for (final rating in AuditRating.values) {
      final rawCount = value[rating.apiValue];
      final count = rawCount is num
          ? rawCount.toInt()
          : int.tryParse(rawCount?.toString().trim() ?? '');
      if (count != null && count >= 0) counts[rating.apiValue] = count;
    }
    return counts.isEmpty ? null : Map<String, int>.unmodifiable(counts);
  }

  static List<AuditRating> _readAuditRatings(dynamic value) {
    if (value is! List) {
      return const <AuditRating>[];
    }

    return value
        .map(_readAuditRating)
        .whereType<AuditRating>()
        .toList(growable: false);
  }

  static AuditRating? _readAuditRating(dynamic value) {
    if (value is bool) {
      return value ? AuditRating.great : AuditRating.needsImprovement;
    }

    final normalized = value?.toString().trim().toLowerCase();
    return switch (normalized) {
      'great' => AuditRating.great,
      'almost_there' => AuditRating.almostThere,
      'almost there' => AuditRating.almostThere,
      'needs_improvement' => AuditRating.needsImprovement,
      'needs improvement' => AuditRating.needsImprovement,
      _ => null,
    };
  }

  static double? _readDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value?.toString() ?? '');
  }
}

class AuditDescriptionMediaModel extends AuditDescriptionMedia {
  const AuditDescriptionMediaModel({
    required super.uuid,
    required super.media,
    required super.type,
    required super.comment,
    required super.unreadCount,
  });

  factory AuditDescriptionMediaModel.fromApiJson(Map<String, dynamic> json) {
    return AuditDescriptionMediaModel(
      uuid: _readString(json['uuid']) ?? '',
      media: _readString(json['media']) ?? '',
      type: _readString(json['type']) ?? '',
      comment: _readString(json['comment']),
      unreadCount: _readInt(json['unread_count']) ?? 0,
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
