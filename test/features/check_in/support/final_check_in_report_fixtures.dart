import 'package:flutter_test/flutter_test.dart';
import 'package:sparrowkaizen/features/check_in/domain/entities/seat_description_audit_report_comments.dart';
import 'package:sparrowkaizen/features/check_in/domain/entities/seat_description_final_audit_report.dart';
import 'package:sparrowkaizen/features/check_in/domain/repositories/audit_repository.dart';
import 'package:sparrowkaizen/features/check_in/domain/usecases/get_audit_overview_usecase.dart';
import 'package:sparrowkaizen/features/check_in/presentation/providers/check_in_controller.dart';
import 'package:sparrowkaizen/features/training/domain/entities/seat_description_training_route.dart';

SeatDescriptionFinalAuditReport finalCheckInReport({
  String title = 'Operator',
  String description = 'Keep the equipment ready',
  String specifics = 'Inspect before starting',
  String auditFactor = 'observation',
  bool isOpenSeat = false,
  List<SeatDescriptionFinalAuditTrend> trends = const [],
  SeatDescriptionTrainingRoute route = const SeatDescriptionTrainingRoute(
    job: 'seat',
    category: 'category',
    description: 'description',
    initialModuleId: 'lesson',
  ),
  SeatDescriptionFinalAuditStats stats = const SeatDescriptionFinalAuditStats(
    totalGreat: 8,
    totalNeedsImprovement: 1,
    totalAlmostThere: 1,
    totalPercentage: 85,
    confidenceLevel: 75,
  ),
}) => SeatDescriptionFinalAuditReport(
  uuid: 'report',
  trainingRoute: route,
  auditFactorType: auditFactor,
  description: description,
  jobSpecifics: specifics,
  job: SeatDescriptionFinalAuditJob(uuid: 'report-seat', title: title),
  isOpenSeat: isOpenSeat,
  summaryData: SeatDescriptionFinalAuditSummary(stats: stats, trends: trends),
  checkInComments: const [],
);

SeatDescriptionFinalAuditProfile finalReportProfile(String name) =>
    SeatDescriptionFinalAuditProfile(
      uuid: name,
      name: name,
      userUuid: 'user-$name',
      email: '',
      image: null,
      onboarded: true,
    );

SeatDescriptionFinalAuditTrend finalReportTrend({
  int week = 1,
  int? year,
  String? quarter,
  int great = 1,
  int almostThere = 0,
  int needsImprovement = 0,
  List<SeatDescriptionFinalAuditProfile> profiles = const [],
}) => SeatDescriptionFinalAuditTrend(
  week: week,
  year: year,
  quarter: quarter,
  great: great,
  almostThere: almostThere,
  needsImprovement: needsImprovement,
  confidenceLevel: 0,
  profiles: profiles,
);

SeatDescriptionAuditReportComment finalReportComment({
  String id = 'comment',
  String text = 'Clear observation',
  String? type,
  String? media,
  String? thumbnail,
}) => SeatDescriptionAuditReportComment(
  uuid: id,
  comment: text,
  media: media,
  thumbnailUrl: thumbnail,
  type: type,
  authorName: null,
  createdAt: null,
);

CheckInController finalReportCheckInController(
  FinalCheckInReportRepository repository,
) => CheckInController(
  GetAuditOverviewUseCase(repository),
  null,
  null,
  null,
  null,
  null,
  null,
  repository,
);

typedef FinalReportRequest = ({
  String endpoint,
  String flowFirstId,
  String? profileUuid,
  String descriptionId,
  int? quarter,
  int? year,
  String? timeRange,
});

class FinalCheckInReportRepository extends Fake implements AuditRepository {
  final requests = <FinalReportRequest>[];
  final pendingReports = <Future<SeatDescriptionFinalAuditReport>>[];
  final pendingComments = <Future<SeatDescriptionAuditReportComments>>[];
  final pendingProfiles = <Future<List<SeatDescriptionFinalAuditProfile>>>[];
  SeatDescriptionFinalAuditReport report = finalCheckInReport();
  List<SeatDescriptionAuditReportComment> comments = [];
  List<SeatDescriptionFinalAuditProfile> profiles = [];
  bool failReport = false;
  bool failComments = false;
  bool failProfiles = false;

  @override
  Future<SeatDescriptionFinalAuditReport> getSeatDescriptionFinalAuditReport({
    required String flowFirstId,
    String? profileUuid,
    required String descriptionId,
    int? quarter,
    int? year,
    String? timeRange,
  }) async {
    requests.add((
      endpoint: 'report',
      flowFirstId: flowFirstId,
      profileUuid: profileUuid,
      descriptionId: descriptionId,
      quarter: quarter,
      year: year,
      timeRange: timeRange,
    ));
    if (failReport) throw StateError('Report failed');
    return pendingReports.isNotEmpty ? pendingReports.removeAt(0) : report;
  }

  @override
  Future<SeatDescriptionAuditReportComments>
  getSeatDescriptionAuditReportComments({
    required String flowFirstId,
    String? profileUuid,
    required String descriptionId,
    int? quarter,
    int? year,
    String? timeRange,
  }) async {
    requests.add((
      endpoint: 'comments',
      flowFirstId: flowFirstId,
      profileUuid: profileUuid,
      descriptionId: descriptionId,
      quarter: quarter,
      year: year,
      timeRange: timeRange,
    ));
    if (failComments) throw StateError('Comments failed');
    return pendingComments.isNotEmpty
        ? pendingComments.removeAt(0)
        : SeatDescriptionAuditReportComments(items: comments);
  }

  @override
  Future<List<SeatDescriptionFinalAuditProfile>>
  getSeatDescriptionAuditReportProfiles({
    required String flowFirstId,
    String? profileUuid,
    required String descriptionId,
    int? quarter,
    int? year,
    String? timeRange,
  }) async {
    requests.add((
      endpoint: 'profiles',
      flowFirstId: flowFirstId,
      profileUuid: profileUuid,
      descriptionId: descriptionId,
      quarter: quarter,
      year: year,
      timeRange: timeRange,
    ));
    if (failProfiles) throw StateError('Profiles failed');
    return pendingProfiles.isNotEmpty ? pendingProfiles.removeAt(0) : profiles;
  }
}
