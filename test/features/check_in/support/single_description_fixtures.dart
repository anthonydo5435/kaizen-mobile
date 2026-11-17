import 'package:flutter_test/flutter_test.dart';
import 'package:sparrowkaizen/core/utils/custom_functions.dart';
import 'package:sparrowkaizen/features/check_in/domain/entities/audit_description_audit.dart';
import 'package:sparrowkaizen/features/check_in/domain/entities/quarterly_audit.dart';
import 'package:sparrowkaizen/features/check_in/domain/entities/seat_audit.dart';
import 'package:sparrowkaizen/features/check_in/domain/entities/subordinate_profile_job.dart';
import 'package:sparrowkaizen/features/check_in/domain/repositories/audit_repository.dart';
import 'package:sparrowkaizen/features/check_in/domain/usecases/get_audit_overview_usecase.dart';
import 'package:sparrowkaizen/features/check_in/presentation/providers/check_in_controller.dart';
import 'package:sparrowkaizen/features/training/domain/entities/seat_description_training_route.dart';

String singleDescriptionDate({int daysAgo = 0}) =>
    CustomFunctions.apiDateString(
      date: DateTime.now().subtract(Duration(days: daysAgo)),
    );

QuarterlyAuditDescription singleDescription(
  String id, {
  int great = 1,
  bool isMirror = false,
}) => QuarterlyAuditDescription(
  uuid: id,
  category: 'category',
  isMirror: isMirror,
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
  bool isMirror = false,
  List<String>? assignments,
}) => AuditDescriptionAudit(
  uuid: id,
  audit: ratings,
  isGeneral: false,
  isMirror: isMirror,
  auditMedia: media,
  weightedScore: 0,
  assignments: assignments,
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
  final assignments = <({String id, List<String> profileJobIds})>[];
  final memberRequests = <String>[];
  final writes = <String>[];
  bool failAssignment = false;
  bool failMembers = false;
  Future<void>? pendingAssignment;
  Future<List<SubordinateProfileJob>>? pendingMembers;
  List<SubordinateProfileJob> members = [
    singleDescriptionAssignee('one'),
    singleDescriptionAssignee('two'),
  ];
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
    writes.add('rating');
    if (failSave) throw StateError('Rating save failed');
    return pendingSave ??
        singleDescriptionAudit(id: descriptionId, ratings: const []);
  }

  @override
  Future<List<SubordinateProfileJob>> getSubordinateProfileJobs({
    required String seatId,
    bool forceRefresh = false,
  }) async {
    memberRequests.add(seatId);
    if (failMembers) throw StateError('Members unavailable');
    return pendingMembers ?? members;
  }

  @override
  Future<void> assignDescriptionAudit({
    required String descriptionId,
    required List<String> profileJobIds,
  }) async {
    assignments.add((id: descriptionId, profileJobIds: List.of(profileJobIds)));
    writes.add('assignment');
    if (failAssignment) throw StateError('Assignment failed');
    await pendingAssignment;
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

SubordinateProfileJob singleDescriptionAssignee(String id) =>
    SubordinateProfileJob(
      uuid: 'profile-job-$id',
      title: 'Operator',
      isPrimary: true,
      createdAt: '',
      profile: SeatAuditProfile(
        uuid: 'profile-$id',
        name: 'Member $id',
        userUuid: 'user-$id',
        email: '$id@example.com',
        image: null,
        onboarded: true,
      ),
    );
