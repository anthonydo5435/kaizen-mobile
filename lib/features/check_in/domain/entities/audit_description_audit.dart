enum AuditRating {
  great,
  almostThere,
  needsImprovement;

  static const int maxCount = 99;

  static bool canIncrementCount(int count) => count < maxCount;

  static bool isLockedByGeneralSeat({
    required bool isMirror,
    required bool isGeneralSeatAudit,
  }) => isMirror && !isGeneralSeatAudit;
}

extension AuditRatingApiValue on AuditRating {
  String get apiValue => switch (this) {
    AuditRating.great => 'great',
    AuditRating.almostThere => 'almost_there',
    AuditRating.needsImprovement => 'needs_improvement',
  };
}

class AuditDescriptionAudit {
  const AuditDescriptionAudit({
    required this.uuid,
    required this.audit,
    required this.isGeneral,
    required this.isMirror,
    required this.auditMedia,
    required this.weightedScore,
    this.assignments,
    Map<String, int>? ratingCounts,
  }) : _ratingCounts = ratingCounts;

  final String uuid;
  final List<AuditRating> audit;
  final bool isGeneral;
  final bool isMirror;
  final List<AuditDescriptionMedia> auditMedia;
  final double weightedScore;

  /// Null means the response omitted assignments; an empty list clears them.
  final List<String>? assignments;
  final Map<String, int>? _ratingCounts;

  /// Null means the response supplied no usable ratings; retain summary counts.
  Map<String, int>? get ratingCounts {
    if (_ratingCounts != null) return _ratingCounts;
    if (audit.isEmpty) return null;
    return {
      for (final rating in AuditRating.values)
        rating.apiValue: audit.where((value) => value == rating).length,
    };
  }
}

class AuditDescriptionMedia {
  const AuditDescriptionMedia({
    required this.uuid,
    required this.media,
    required this.type,
    required this.comment,
    required this.unreadCount,
  });

  final String uuid;
  final String media;
  final String type;
  final String? comment;
  final int unreadCount;
}
