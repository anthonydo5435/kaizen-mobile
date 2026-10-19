import 'package:flutter_test/flutter_test.dart';
import 'package:sparrowkaizen/core/utils/custom_functions.dart';
import 'package:sparrowkaizen/features/check_in/domain/entities/audit_description_audit.dart';
import 'package:sparrowkaizen/features/check_in/domain/entities/quarterly_audit.dart';
import 'package:sparrowkaizen/features/check_in/domain/repositories/audit_repository.dart';
import 'package:sparrowkaizen/features/check_in/domain/usecases/get_audit_overview_usecase.dart';
import 'package:sparrowkaizen/features/check_in/presentation/providers/check_in_controller.dart';
import 'package:sparrowkaizen/features/training/domain/entities/seat_description_training_route.dart';

String singleDescriptionDate({int daysAgo = 0}) =>
    CustomFunctions.apiDateString(
      date: DateTime.now().subtract(Duration(days: daysAgo)),
    );

QuarterlyAuditDescription singleDescription(String id, {int great = 1}) =>
    QuarterlyAuditDescription(
      uuid: id,
      category: 'category',
      isMirror: false,
      description: 'Description $id',
      jobSpecifics: 'Seat specifics $id',
      trainingRoute: SeatDescriptionTrainingRoute(
        job: 'seat',
        category: 'category',
        description: id,
      ),
      great: great,
      needsImprovement: 0,
      almostThere: 0,
      pass: 0,
      noPass: 0,
      hasAudit: true,
      auditUuid: '$id-audit',
      milestoneDay: '',
      lastAuditDate: null,
      confidenceLevel: 0,
      auditFactorType: 'Observation',
    );

QuarterlyAudit singleDescriptionQuarterlyAudit() => QuarterlyAudit(
  uuid: 'quarterly-audit',
  jobUuid: 'seat',
  jobTitle: 'Operator',
  isMismatch: false,
  profileUuid: 'employee',
  profileName: 'Employee',
  profileEmail: '',
  profileImage: null,
  profileOnboarded: true,
  profileJob: 'profile-job',
  categories: const [],
  descriptions: [
    singleDescription('first'),
    singleDescription('second', great: 5),
  ],
);

AuditDescriptionAudit singleDescriptionAudit({
  String id = 'resolved-audit',
  List<AuditRating> ratings = const [AuditRating.great],
  List<AuditDescriptionMedia> media = const [],
}) => AuditDescriptionAudit(
  uuid: id,
  audit: ratings,
  isGeneral: false,
  isMirror: false,
  auditMedia: media,
  weightedScore: 0,
);

CheckInController singleDescriptionCheckInController(
  SingleDescriptionRepository repository,
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

class SingleDescriptionRepository extends Fake implements AuditRepository {
  final loads = <String>[];
  final pendingLoads = <Future<AuditDescriptionAudit>>[];
  final saves = <({String id, Map<String, int> counts})>[];
  final comments = <({String id, String comment})>[];
  final mediaComments = <({String id, String comment, String? type})>[];
  Future<AuditDescriptionAudit>? pendingSave;
  bool failSave = false;
  AuditDescriptionAudit response = singleDescriptionAudit();

  @override
  Future<AuditDescriptionAudit> getAuditDescriptionAudit({
    required String quarterlyAuditId,
    required String descriptionId,
    required String date,
  }) async {
    loads.add(descriptionId);
    if (pendingLoads.isNotEmpty) return pendingLoads.removeAt(0);
    return response;
  }

  @override
  Future<AuditDescriptionAudit> submitDescriptionAudit({
    required String descriptionId,
    required Map<String, int> audit,
  }) async {
    saves.add((id: descriptionId, counts: Map.of(audit)));
    if (failSave) throw StateError('Rating save failed');
    return pendingSave ??
        singleDescriptionAudit(id: descriptionId, ratings: const []);
  }

  @override
  Future<void> createAuditDescriptionComment({
    required String descriptionId,
    required String comment,
  }) async {
    comments.add((id: descriptionId, comment: comment));
  }

  @override
  Future<void> createAuditDescriptionMedia({
    required String descriptionId,
    required String comment,
    String? mediaUrl,
    String? mediaType,
  }) async {
    mediaComments.add((id: descriptionId, comment: comment, type: mediaType));
  }
}
