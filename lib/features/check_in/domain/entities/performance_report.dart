import 'audit_profile.dart';

class PerformanceReport {
  const PerformanceReport({
    required this.profile,
    this.createdAt,
    this.personalityAvatarImagePath,
    this.hasPersonalityData = false,
    this.isCertified = false,
    this.certifiedAt,
    this.employeeSignatureName,
    this.selectedProfileSignatureUuid,
    this.selectedProfileSignatureUrl,
    this.facilitatorSignatureUrl,
    this.facilitatorName,
    required this.reportSnapshot,
    required this.rawPersonalityDescription,
    required this.overallPerformanceScore,
    required this.confidenceLevel,
    required this.archetypeTitle,
    required this.archetypeSubtitle,
    required this.archetypeSummary,
    required this.guidanceParagraphs,
    required this.categoryTabs,
    required this.selectedCategoryIndex,
    required this.ratingRows,
    required this.paygradePipeline,
    required this.currentPaygrade,
    required this.paygradeUnit,
    this.coreValues = const <PerformanceReportCoreValue>[],
    this.remarkVersion = 0,
  });

  final AuditProfile profile;
  final String? createdAt;
  final String? personalityAvatarImagePath;
  final bool hasPersonalityData;
  final bool isCertified;
  final String? certifiedAt;
  final String? employeeSignatureName;
  final String? selectedProfileSignatureUuid;
  final String? selectedProfileSignatureUrl;
  final String? facilitatorSignatureUrl;
  final String? facilitatorName;
  final Map<String, dynamic> reportSnapshot;
  final String rawPersonalityDescription;
  final double overallPerformanceScore;
  final double confidenceLevel;
  final String archetypeTitle;
  final String archetypeSubtitle;
  final String archetypeSummary;
  final List<String> guidanceParagraphs;
  final List<PerformanceReportCategoryTab> categoryTabs;
  final int selectedCategoryIndex;
  final List<PerformanceReportRatingRow> ratingRows;
  final List<PerformanceReportPaygradeStep> paygradePipeline;
  final String currentPaygrade;
  final String paygradeUnit;
  final List<PerformanceReportCoreValue> coreValues;
  final int remarkVersion;
}

class PerformanceReportCategoryTab {
  const PerformanceReportCategoryTab({
    required this.label,
    required this.score,
    required this.rows,
  });

  final String label;
  final double score;
  final List<PerformanceReportRatingRow> rows;
}

class PerformanceReportRatingRow {
  const PerformanceReportRatingRow({
    required this.descriptionUuid,
    required this.title,
    required this.passCount,
    required this.partialCount,
    required this.failCount,
    required this.ratingPercent,
    this.remarks,
  });

  final String descriptionUuid;
  final String title;
  final int passCount;
  final int partialCount;
  final int failCount;
  final int ratingPercent;
  final String? remarks;
}

class PerformanceReportPaygradeStep {
  const PerformanceReportPaygradeStep({
    required this.label,
    required this.caption,
    required this.title,
    required this.payRateAmount,
    required this.payRateDisplay,
    required this.promotionRequirement,
    this.isCurrent = false,
  });

  final String label;
  final String caption;
  final String title;
  final double payRateAmount;
  final String payRateDisplay;
  final String promotionRequirement;
  final bool isCurrent;
}

class PerformanceReportCoreValue {
  const PerformanceReportCoreValue({
    required this.title,
    this.description,
    this.iconKey,
    this.colorHex,
    this.details = const <PerformanceReportCoreValueDetail>[],
    this.rawData = const <String, dynamic>{},
  });

  final String title;
  final String? description;
  final String? iconKey;
  final String? colorHex;
  final List<PerformanceReportCoreValueDetail> details;
  final Map<String, dynamic> rawData;
}

class PerformanceReportCoreValueDetail {
  const PerformanceReportCoreValueDetail({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;
}

class CertifiedReportOption {
  const CertifiedReportOption({
    required this.uuid,
    required this.displayName,
    this.createdAt,
  });

  final String uuid;
  final String displayName;
  final String? createdAt;
}

class CertifiedReportDetail {
  const CertifiedReportDetail({
    required this.report,
    required this.commitmentComment,
  });

  final PerformanceReport report;
  final String commitmentComment;
}
