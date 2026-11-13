class AuditDetails {
  const AuditDetails({
    required this.uuid,
    required this.lastAuditDate,
    required this.isFavorite,
    required this.overallScore,
    required this.confidenceLevel,
    required this.profiles,
    required this.profileJob,
    required this.profileUuid,
    required this.profileName,
    required this.profileEmail,
    required this.profileImage,
    required this.profileOnboarded,
    required this.jobUuid,
    required this.jobTitle,
    required this.audits,
  });

  final String uuid;
  final String lastAuditDate;
  final bool isFavorite;
  final double overallScore;
  final double confidenceLevel;
  final List<AuditDetailsProfile> profiles;
  final String profileJob;
  final String profileUuid;
  final String profileName;
  final String profileEmail;
  final String? profileImage;
  final bool profileOnboarded;
  final String jobUuid;
  final String jobTitle;
  final List<AuditDetailItem> audits;
}

class AuditDetailsProfile {
  const AuditDetailsProfile({
    required this.uuid,
    required this.name,
    required this.email,
    required this.image,
    required this.onboarded,
  });

  final String uuid;
  final String name;
  final String email;
  final String? image;
  final bool onboarded;
}

class AuditDetailItem {
  const AuditDetailItem({
    this.quarterlyAuditUuid = '',
    required this.date,
    required this.great,
    required this.needsImprovement,
    required this.almostThere,
  });

  final String quarterlyAuditUuid;
  final String date;
  final int great;
  final int needsImprovement;
  final int almostThere;

  int get totalRatings => great + needsImprovement + almostThere;
}
