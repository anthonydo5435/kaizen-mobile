import '../../../training/domain/entities/seat_description_training_route.dart';

class QuarterlyAudit {
  const QuarterlyAudit({
    required this.uuid,
    required this.jobUuid,
    required this.jobTitle,
    required this.isMismatch,
    required this.profileUuid,
    required this.profileName,
    required this.profileEmail,
    required this.profileImage,
    required this.profileOnboarded,
    required this.profileJob,
    required this.categories,
    required this.descriptions,
  });

  final String uuid;
  final String jobUuid;
  final String jobTitle;
  final bool isMismatch;
  final String profileUuid;
  final String profileName;
  final String profileEmail;
  final String? profileImage;
  final bool profileOnboarded;
  final String profileJob;
  final List<QuarterlyAuditCategory> categories;
  final List<QuarterlyAuditDescription> descriptions;

  QuarterlyAudit withDescriptionRatingCounts({
    required String descriptionId,
    required String auditId,
    required Map<String, int> counts,
    bool hasAudit = true,
  }) {
    if (!descriptions.any((description) => description.uuid == descriptionId)) {
      return this;
    }

    return QuarterlyAudit(
      uuid: uuid,
      jobUuid: jobUuid,
      jobTitle: jobTitle,
      isMismatch: isMismatch,
      profileUuid: profileUuid,
      profileName: profileName,
      profileEmail: profileEmail,
      profileImage: profileImage,
      profileOnboarded: profileOnboarded,
      profileJob: profileJob,
      categories: categories,
      descriptions: descriptions
          .map(
            (description) => description.uuid == descriptionId
                ? description.withRatingCounts(
                    auditId: auditId,
                    counts: counts,
                    hasAudit: hasAudit,
                  )
                : description,
          )
          .toList(growable: false),
    );
  }
}

class QuarterlyAuditCategory {
  const QuarterlyAuditCategory({
    required this.uuid,
    required this.categoryTitle,
  });

  final String uuid;
  final String categoryTitle;
}

class QuarterlyAuditDescription {
  const QuarterlyAuditDescription({
    required this.uuid,
    required this.category,
    required this.isMirror,
    required this.description,
    required this.jobSpecifics,
    required this.trainingRoute,
    required this.great,
    required this.needsImprovement,
    required this.almostThere,
    required this.pass,
    required this.noPass,
    required this.hasAudit,
    required this.auditUuid,
    required this.milestoneDay,
    required this.lastAuditDate,
    required this.confidenceLevel,
    required this.auditFactorType,
  });

  final String uuid;
  final String category;
  final bool isMirror;
  final String description;
  final String jobSpecifics;
  final SeatDescriptionTrainingRoute trainingRoute;
  final int great;
  final int needsImprovement;
  final int almostThere;
  final int pass;
  final int noPass;
  final bool hasAudit;
  final String auditUuid;
  final String milestoneDay;
  final String? lastAuditDate;
  final double confidenceLevel;
  final String auditFactorType;

  int get totalRatings => great + needsImprovement + almostThere;

  QuarterlyAuditDescription withRatingCounts({
    required String auditId,
    required Map<String, int> counts,
    bool hasAudit = true,
  }) {
    return QuarterlyAuditDescription(
      uuid: uuid,
      category: category,
      isMirror: isMirror,
      description: description,
      jobSpecifics: jobSpecifics,
      trainingRoute: trainingRoute,
      great: counts['great'] ?? great,
      needsImprovement: counts['needs_improvement'] ?? needsImprovement,
      almostThere: counts['almost_there'] ?? almostThere,
      pass: pass,
      noPass: noPass,
      hasAudit: hasAudit,
      auditUuid: auditId,
      milestoneDay: milestoneDay,
      lastAuditDate: lastAuditDate,
      confidenceLevel: confidenceLevel,
      auditFactorType: auditFactorType,
    );
  }
}
