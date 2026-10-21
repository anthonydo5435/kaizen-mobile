import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sparrowkaizen/core/constants/app_strings.dart';
import 'package:sparrowkaizen/features/check_in/domain/entities/audit_member.dart';
import 'package:sparrowkaizen/features/check_in/domain/entities/audit_member_status.dart';
import 'package:sparrowkaizen/features/check_in/domain/entities/audit_profile.dart';
import 'package:sparrowkaizen/features/check_in/domain/entities/performance_report.dart';
import 'package:sparrowkaizen/features/check_in/domain/entities/seat_description_final_audit_report.dart';
import 'package:sparrowkaizen/features/check_in/domain/entities/seat_description_audit_report_comments.dart';
import 'package:sparrowkaizen/features/check_in/domain/repositories/audit_repository.dart';
import 'package:sparrowkaizen/features/check_in/domain/usecases/get_audit_overview_usecase.dart';
import 'package:sparrowkaizen/features/check_in/presentation/providers/check_in_controller.dart';

const reportProfiles = [
  AuditMemberProfile(
    uuid: 'employee',
    name: 'Employee One',
    email: 'one@example.com',
    imageUrl: null,
    onboarded: true,
  ),
  AuditMemberProfile(
    uuid: 'second',
    name: 'Employee Two',
    email: '',
    imageUrl: null,
    onboarded: true,
  ),
];

const reportProfile = AuditProfile(
  uuid: 'employee',
  profileJob: 'profile-job',
  profileUuid: 'employee',
  email: 'one@example.com',
  imageUrl: null,
  isFavorite: true,
  lastAuditDates: ['2025-01-01'],
  roleTitle: 'Engineer',
  name: 'Employee One',
  lastAuditLabel: '2025-01-01',
  yearQuarter: '2026-Q4',
  seatProfile: 'Engineering',
  overallScore: 80,
  confidenceLevel: 90,
  status: AuditMemberStatus.active,
  reviewerInitials: ['TL'],
  avatarLabel: 'E',
  profiles: reportProfiles,
);

const reportRows = [
  PerformanceReportRatingRow(
    descriptionUuid: 'description',
    title: 'Daily delivery',
    passCount: 3,
    partialCount: 1,
    failCount: 0,
    ratingPercent: 88,
    remarks: 'Keep going',
  ),
  PerformanceReportRatingRow(
    descriptionUuid: 'second-description',
    title: 'Team support',
    passCount: 0,
    partialCount: 0,
    failCount: 0,
    ratingPercent: 0,
  ),
];

PerformanceReport reportFixture({
  AuditProfile profile = reportProfile,
  String? createdAt = '2025-01-01',
  Map<String, dynamic>? snapshot,
  bool isCertified = false,
  bool hasPersonality = false,
  int remarkVersion = 0,
}) => PerformanceReport(
  profile: profile,
  createdAt: createdAt,
  reportSnapshot:
      snapshot ??
      {
        'selected_profile': {'uuid': profile.profileUuid},
        'categories': [
          {'uuid': 'category'},
        ],
      },
  rawPersonalityDescription: '',
  overallPerformanceScore: 80,
  confidenceLevel: 90,
  archetypeTitle: 'Builder',
  archetypeSubtitle: 'Practical_builder',
  archetypeSummary: 'Build steadily',
  guidanceParagraphs: ['Keep improving'],
  categoryTabs: [
    PerformanceReportCategoryTab(
      label: 'Responsibilities',
      score: 88,
      rows: [reportRows[0]],
    ),
    PerformanceReportCategoryTab(
      label: 'Collaboration',
      score: 0,
      rows: [reportRows[1]],
    ),
  ],
  selectedCategoryIndex: 0,
  ratingRows: reportRows,
  paygradePipeline: const [],
  currentPaygrade: 'Level 1',
  paygradeUnit: 'month',
  coreValues: const [
    PerformanceReportCoreValue(
      title: 'Ownership',
      description: 'Follow through',
    ),
  ],
  isCertified: isCertified,
  certifiedAt: isCertified ? '1767225600000' : null,
  selectedProfileSignatureUuid: 'existing-signature',
  hasPersonalityData: hasPersonality,
  personalityAvatarImagePath: hasPersonality
      ? AppStrings.dummyProfileImagePath
      : null,
  remarkVersion: remarkVersion,
);

CheckInController reportAuditController(ReportRepository repository) =>
    CheckInController(
      GetAuditOverviewUseCase(repository),
      null,
      null,
      null,
      null,
      null,
      null,
      repository,
    );

class ReportRepository extends Fake implements AuditRepository {
  PerformanceReport Function(AuditProfile) buildReport = (profile) =>
      reportFixture(profile: profile);
  Future<PerformanceReport>? pendingOverview;
  Completer<String?>? certification;
  Completer<Map<String, String>>? remarks;
  String pdfUrl = 'https://example.com/report.pdf';
  final overviewProfiles = <AuditProfile>[];
  DateTime? lastStart;
  DateTime? lastEnd;
  int? lastQuarter;
  int? lastYear;
  Map<String, dynamic>? certificationPayload;
  String? certificationProfileJob;
  int signatureUploads = 0;
  int pdfRequests = 0;
  final detailRequests = <String>[];

  @override
  Future<PerformanceReport> getPerformanceReportOverview({
    required AuditProfile profile,
    int? year,
    int? quarter,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    overviewProfiles.add(profile);
    lastStart = startDate;
    lastEnd = endDate;
    lastYear = year;
    lastQuarter = quarter;
    return pendingOverview ?? buildReport(profile);
  }

  @override
  Future<List<CertifiedReportOption>> getCertifiedReports({
    required AuditProfile profile,
    int? year,
    int? quarter,
    DateTime? startDate,
    DateTime? endDate,
  }) async => const [
    CertifiedReportOption(uuid: 'certified', displayName: 'Certified Quarter'),
  ];

  @override
  Future<CertifiedReportDetail> getCertifiedReportDetail({
    required String certifiedReportUuid,
    required AuditProfile fallbackProfile,
  }) async {
    detailRequests.add(certifiedReportUuid);
    return CertifiedReportDetail(
      report: reportFixture(profile: fallbackProfile, isCertified: true),
      commitmentComment: 'Certified commitment',
    );
  }

  @override
  Future<Map<String, String>> getPerformanceReportRemarks({
    required AuditProfile profile,
    int? year,
    int? quarter,
    DateTime? startDate,
    DateTime? endDate,
  }) async =>
      remarks == null ? {'description': 'Generated guidance'} : remarks!.future;

  @override
  Future<String> uploadPerformanceReportSignatureImage({
    required String fileName,
    required List<int> fileBytes,
    required String contentType,
  }) async => 'signature-${++signatureUploads}';

  @override
  Future<String?> certifyPerformanceReport({
    required String profileJobId,
    required Map<String, dynamic> payload,
  }) async {
    certificationProfileJob = profileJobId;
    certificationPayload = payload;
    return certification == null ? 'certified' : certification!.future;
  }

  @override
  Future<String> getCertifiedReportPdfUrl({
    required String certifiedReportUuid,
  }) async {
    pdfRequests++;
    return pdfUrl;
  }

  @override
  Future<SeatDescriptionFinalAuditReport> getSeatDescriptionFinalAuditReport({
    required String flowFirstId,
    String? profileUuid,
    required String descriptionId,
    int? quarter,
    int? year,
    String? timeRange,
  }) async => throw StateError('Final report unavailable');

  @override
  Future<SeatDescriptionAuditReportComments>
  getSeatDescriptionAuditReportComments({
    required String flowFirstId,
    String? profileUuid,
    required String descriptionId,
    int? quarter,
    int? year,
    String? timeRange,
  }) async => const SeatDescriptionAuditReportComments(items: []);

  @override
  Future<List<SeatDescriptionFinalAuditProfile>>
  getSeatDescriptionAuditReportProfiles({
    required String flowFirstId,
    String? profileUuid,
    required String descriptionId,
    int? quarter,
    int? year,
    String? timeRange,
  }) async => [];
}
