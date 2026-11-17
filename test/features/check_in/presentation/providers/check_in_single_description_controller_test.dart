import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sparrowkaizen/core/constants/app_strings.dart';
import 'package:sparrowkaizen/features/check_in/data/models/audit_description_audit_model.dart';
import 'package:sparrowkaizen/features/check_in/domain/entities/audit_description_audit.dart';
import 'package:sparrowkaizen/features/check_in/domain/entities/subordinate_profile_job.dart';
import 'package:sparrowkaizen/features/check_in/presentation/providers/check_in_controller.dart';
import 'package:sparrowkaizen/features/check_in/presentation/providers/check_in_media_upload_controller.dart';
import 'package:sparrowkaizen/features/check_in/presentation/providers/check_in_single_description_controller.dart';

import '../../support/single_description_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SingleDescriptionRepository repository;
  late CheckInController checkIn;
  late _Uploads uploads;

  setUp(() {
    repository = SingleDescriptionRepository();
    checkIn = singleDescriptionCheckInController(repository);
    uploads = _Uploads();
  });
  tearDown(() {
    checkIn.dispose();
    uploads.dispose();
  });

  CheckInSingleDescriptionController create({
    Map<String, int>? initialCounts,
    bool isOwner = true,
    bool isViewOnly = false,
    bool isSelfAudit = false,
    bool isGeneralSeatAudit = false,
    bool descriptionIsMirror = false,
    int daysAgo = 0,
  }) => CheckInSingleDescriptionController(
    checkInController: checkIn,
    audit: singleDescriptionQuarterlyAudit(),
    description: singleDescription('first', isMirror: descriptionIsMirror),
    date: singleDescriptionDate(daysAgo: daysAgo),
    isOwner: isOwner,
    isViewOnly: isViewOnly,
    isSelfAudit: isSelfAudit,
    isGeneralSeatAudit: isGeneralSeatAudit,
    initialRatingCounts: initialCounts,
    mediaUploadController: uploads,
  );

  test('mirrored ratings lock only outside the General Seat entry', () async {
    repository.response = singleDescriptionAudit(isMirror: true);
    final member = create();
    final general = create(isGeneralSeatAudit: true);
    addTearDown(member.dispose);
    addTearDown(general.dispose);
    await Future.wait([member.ready, general.ready]);
    expect(member.showGeneralSeatRatingLock, isTrue);
    expect(member.canEditRatings, isFalse);
    expect(member.canManageComments, isTrue);
    expect(general.showGeneralSeatRatingLock, isFalse);
    expect(general.canEditRatings, isTrue);
    member.incrementRating(AuditRating.great);
    member.decrementRating(AuditRating.great);
    expect(member.countFor(AuditRating.great), 1);
    expect(repository.saves, isEmpty);
  });

  test(
    'a mirrored summary keeps details locked when the audit response has no mirror flag',
    () async {
      final controller = create(descriptionIsMirror: true);
      addTearDown(controller.dispose);
      await controller.ready;
      expect(controller.showGeneralSeatRatingLock, isTrue);
      expect(controller.canEditRatings, isFalse);
      controller.incrementRating(AuditRating.great);
      controller.decrementRating(AuditRating.great);
      expect(controller.countFor(AuditRating.great), 1);
      expect(repository.saves, isEmpty);
    },
  );

  testWidgets('assignment flushes ratings and sends multiple profile-job IDs', (
    tester,
  ) async {
    final controller = create(isGeneralSeatAudit: true);
    addTearDown(controller.dispose);
    await controller.ready;
    expect(controller.isAssignedToGeneral, isTrue);
    expect(repository.memberRequests, isEmpty);
    controller.beginAssignmentSelection();
    await tester.pump();
    expect(repository.memberRequests, ['seat']);
    controller.updateAssignmentSearch('TWO@EXAMPLE');
    expect(controller.visibleAssignmentMembers.single.uuid, 'profile-job-two');
    controller.toggleDraftAssignee(repository.members.first);
    controller.toggleDraftAssignee(repository.members.last);
    controller.incrementRating(AuditRating.great);
    final pending = Completer<void>();
    repository.pendingAssignment = pending.future;
    final save = controller.confirmAssignment();
    await tester.pump();
    expect(controller.isAssigning, isTrue);
    expect(controller.isAssignedToGeneral, isTrue);
    expect(repository.writes, ['rating', 'assignment']);
    expect(repository.saves.single.counts['great'], 2);
    expect(repository.assignments.single.id, 'resolved-audit');
    expect(repository.assignments.single.profileJobIds, [
      'profile-job-one',
      'profile-job-two',
    ]);
    controller.incrementRating(AuditRating.great);
    expect(controller.countFor(AuditRating.great), 2);
    expect(await controller.confirmAssignment(), isFalse);
    pending.complete();
    expect(await save, isTrue);
    expect(controller.isAssignedToGeneral, isFalse);
    expect(controller.assignedTeamMemberCount, 2);
    expect(controller.assignmentSummary, 'Assigned To: 2 Team Members');
    await tester.pump(const Duration(milliseconds: 200));
    expect(repository.saves, hasLength(1));
    await controller.assignToGeneral();
    expect(repository.assignments.last.profileJobIds, isEmpty);
    expect(controller.isAssignedToGeneral, isTrue);
  });

  test('assignment drafts discard on close and failures allow retry', () async {
    final controller = create(isGeneralSeatAudit: true);
    addTearDown(controller.dispose);
    await controller.ready;
    repository.failMembers = true;
    await controller.loadAssignmentMembers();
    expect(controller.assignmentMembersError, isNotNull);
    repository.failMembers = false;
    await controller.loadAssignmentMembers();
    expect(controller.assignmentMembersError, isNull);
    controller.toggleDraftAssignee(repository.members.first);
    controller.beginAssignmentSelection();
    expect(controller.isDraftAssigneeSelected('profile-job-one'), isFalse);
    expect(repository.assignments, isEmpty);
    controller.toggleDraftAssignee(repository.members.first);
    repository.failAssignment = true;
    expect(await controller.confirmAssignment(), isFalse);
    expect(controller.isAssignedToGeneral, isTrue);
    expect(controller.isAssigning, isFalse);
    expect(
      controller.assignmentSaveError,
      AppStrings.auditAssignmentSaveFailed,
    );
    repository.failAssignment = false;
    expect(await controller.confirmAssignment(), isTrue);
    expect(controller.assignmentSaveError, isNull);
    repository.failAssignment = true;
    await controller.assignToGeneral();
    expect(controller.isAssignedToGeneral, isFalse);
    expect(controller.takeErrorMessage(), AppStrings.auditAssignmentSaveFailed);
  });

  testWidgets(
    'API assignments restore before people load and retain unavailable IDs on save',
    (tester) async {
      repository.response = singleDescriptionAudit(
        assignments: ['profile-job-two', 'unavailable-profile-job'],
      );
      final people = Completer<List<SubordinateProfileJob>>();
      repository.pendingMembers = people.future;
      final controller = create(isGeneralSeatAudit: true);
      addTearDown(controller.dispose);
      await controller.ready;
      expect(controller.isAssignedToGeneral, isFalse);
      expect(controller.assignedTeamMemberCount, 2);
      controller.beginAssignmentSelection();
      expect(controller.isDraftAssigneeSelected('profile-job-two'), isTrue);
      people.complete(repository.members);
      await tester.pump();
      expect(
        controller.isDraftAssigneeSelected(repository.members.first.uuid),
        isFalse,
      );
      expect(
        controller.isDraftAssigneeSelected(repository.members.last.uuid),
        isTrue,
      );
      expect(repository.assignments, isEmpty);
      controller.toggleDraftAssignee(repository.members.first);
      expect(await controller.confirmAssignment(), isTrue);
      expect(repository.assignments.single.profileJobIds, [
        'profile-job-two',
        'unavailable-profile-job',
        'profile-job-one',
      ]);
      expect(controller.assignedTeamMemberCount, 3);
      await controller.assignToGeneral();
      expect(
        controller.assignmentSummary,
        AppStrings.auditAssignToTeamMemberHint,
      );
    },
  );

  test(
    'stale refreshes and omitted assignments preserve the saved selection',
    () async {
      repository.response = singleDescriptionAudit(
        assignments: ['profile-job-one'],
      );
      final controller = create(isGeneralSeatAudit: true);
      addTearDown(controller.dispose);
      await controller.ready;
      await controller.loadAssignmentMembers();
      controller.beginAssignmentSelection();
      controller.toggleDraftAssignee(repository.members.first);
      controller.toggleDraftAssignee(repository.members.last);
      final oldResponse = Completer<AuditDescriptionAudit>();
      repository.pendingLoads.add(oldResponse.future);
      final refresh = controller.refreshComments();
      expect(await controller.confirmAssignment(), isTrue);
      oldResponse.complete(repository.response);
      await refresh;
      controller.beginAssignmentSelection();
      expect(controller.isDraftAssigneeSelected('profile-job-one'), isFalse);
      expect(controller.isDraftAssigneeSelected('profile-job-two'), isTrue);
      repository.response = singleDescriptionAudit();
      await controller.refreshComments();
      expect(controller.assignedTeamMemberCount, 1);
      controller.beginAssignmentSelection();
      expect(controller.isDraftAssigneeSelected('profile-job-two'), isTrue);
      repository.response = singleDescriptionAudit(assignments: []);
      await controller.refreshComments();
      expect(controller.isAssignedToGeneral, isTrue);
    },
  );

  test(
    'restricted General Seat audits can open the picker without assignment access',
    () async {
      final controllers = [
        create(),
        create(isGeneralSeatAudit: true, isOwner: false),
        create(isGeneralSeatAudit: true, isSelfAudit: true),
        create(isGeneralSeatAudit: true, isViewOnly: true),
      ];
      for (final controller in controllers) {
        await controller.ready;
        expect(
          controller.canOpenAssignmentSelection,
          controller.isGeneralSeatAudit,
        );
        controller.beginAssignmentSelection();
        expect(await controller.confirmAssignment(), isFalse);
        controller.dispose();
      }
      expect(repository.memberRequests, hasLength(3));
      expect(repository.assignments, isEmpty);
    },
  );

  test(
    'older General Seat check-ins can be assigned without editing ratings or comments',
    () async {
      final controller = create(isGeneralSeatAudit: true, daysAgo: 30);
      addTearDown(controller.dispose);
      await controller.ready;
      expect(controller.canAssignCheckIn, isTrue);
      expect(controller.canEditRatings, isFalse);
      expect(controller.canCreateComments, isFalse);
      controller.incrementRating(AuditRating.great);
      controller.decrementRating(AuditRating.great);
      await controller.loadAssignmentMembers();
      controller.beginAssignmentSelection();
      controller.toggleDraftAssignee(repository.members.first);
      expect(await controller.confirmAssignment(), isTrue);
      expect(repository.assignments.single.profileJobIds, ['profile-job-one']);
      expect(repository.saves, isEmpty);
      expect(controller.countFor(AuditRating.great), 1);
      await controller.assignToGeneral();
      expect(repository.assignments.last.profileJobIds, isEmpty);
      expect(repository.saves, isEmpty);
    },
  );

  test('late people responses are ignored after disposal', () async {
    final pending = Completer<List<SubordinateProfileJob>>();
    repository.pendingMembers = pending.future;
    final controller = create(isGeneralSeatAudit: true);
    await controller.ready;
    final load = controller.loadAssignmentMembers();
    controller.dispose();
    pending.complete(repository.members);
    await load;
    expect(controller.visibleAssignmentMembers, isEmpty);
  });

  testWidgets(
    'assignment waits for pending ratings and retries failed rating saves',
    (tester) async {
      final controller = create(isGeneralSeatAudit: true);
      addTearDown(controller.dispose);
      await controller.ready;
      await controller.loadAssignmentMembers();
      controller.toggleDraftAssignee(repository.members.first);
      controller.incrementRating(AuditRating.great);
      repository.failSave = true;
      expect(await controller.confirmAssignment(), isFalse);
      expect(repository.assignments, isEmpty);
      expect(controller.isAssignedToGeneral, isTrue);
      repository.failSave = false;
      final pending = Completer<AuditDescriptionAudit>();
      repository.pendingSave = pending.future;
      final assignment = controller.confirmAssignment();
      await tester.pump();
      expect(repository.assignments, isEmpty);
      pending.complete(singleDescriptionAudit());
      expect(await assignment, isTrue);
      expect(repository.assignments.single.id, 'resolved-audit');
    },
  );

  testWidgets(
    'list drafts and local edits survive loading and comment refreshes',
    (tester) async {
      final lookup = Completer<AuditDescriptionAudit>();
      repository.pendingLoads.add(lookup.future);
      final controller = create(initialCounts: {'great': 7});
      addTearDown(controller.dispose);
      expect(controller.isLoading, isTrue);
      controller.incrementRating(AuditRating.great);
      lookup.complete(singleDescriptionAudit());
      await tester.pump();
      expect(controller.isLoading, isFalse);
      expect(controller.countFor(AuditRating.great), 8);
      await controller.refreshComments();
      expect(controller.countFor(AuditRating.great), 8);
      await tester.pump(const Duration(milliseconds: 180));
      expect(repository.saves.single.id, 'resolved-audit');
      expect(repository.saves.single.counts['great'], 8);
    },
  );

  test(
    'count objects load into details and accept explicit zero refreshes',
    () async {
      repository.response = AuditDescriptionAuditModel.fromApiJson({
        'uuid': 'resolved-audit',
        'audit': {'great': 7, 'almost_there': 3, 'needs_improvement': 2},
      });
      final controller = create();
      addTearDown(controller.dispose);
      await controller.ready;
      expect(controller.countFor(AuditRating.great), 7);
      expect(controller.countFor(AuditRating.almostThere), 3);
      expect(controller.countFor(AuditRating.needsImprovement), 2);

      repository.response = AuditDescriptionAuditModel.fromApiJson({
        'uuid': 'resolved-audit',
        'audit': {'great': 0, 'almost_there': 0, 'needs_improvement': 0},
      });
      await controller.refreshComments();
      expect(controller.countFor(AuditRating.great), 0);
      expect(controller.countFor(AuditRating.almostThere), 0);
      expect(controller.countFor(AuditRating.needsImprovement), 0);
    },
  );

  testWidgets(
    'rapid saves stay ordered and an older response retains the newest draft',
    (tester) async {
      final firstSave = Completer<AuditDescriptionAudit>();
      repository.pendingSave = firstSave.future;
      final controller = create();
      addTearDown(controller.dispose);
      await controller.ready;
      controller.incrementRating(AuditRating.great);
      await tester.pump(const Duration(milliseconds: 180));
      controller.incrementRating(AuditRating.great);
      controller.incrementRating(AuditRating.almostThere);
      await tester.pump(const Duration(milliseconds: 180));
      expect(repository.saves, hasLength(1));
      expect(controller.countFor(AuditRating.great), 3);
      repository.pendingSave = null;
      firstSave.complete(singleDescriptionAudit(ratings: const []));
      await tester.pump();
      expect(repository.saves, hasLength(2));
      expect(repository.saves.last.counts, {
        'great': 3,
        'almost_there': 1,
        'needs_improvement': 0,
      });
      expect(controller.countFor(AuditRating.great), 3);
    },
  );

  testWidgets(
    'closing before the debounce fires flushes exactly the final draft',
    (tester) async {
      final controller = create();
      await controller.ready;
      controller.incrementRating(AuditRating.great);
      controller.decrementRating(AuditRating.great);
      controller.incrementRating(AuditRating.needsImprovement);
      controller.dispose();
      expect(uploads.isObserved, isFalse);
      await tester.pump(const Duration(milliseconds: 200));
      expect(repository.saves, hasLength(1));
      expect(repository.saves.single.counts, {
        'great': 1,
        'almost_there': 0,
        'needs_improvement': 1,
      });
    },
  );

  testWidgets(
    'the rating limit is independent for each counter and failures retain feedback',
    (tester) async {
      final controller = create(initialCounts: {'great': 99});
      addTearDown(controller.dispose);
      await controller.ready;
      repository.failSave = true;
      controller.incrementRating(AuditRating.great);
      controller.decrementRating(AuditRating.needsImprovement);
      controller.incrementRating(AuditRating.almostThere);
      await tester.pump(const Duration(milliseconds: 180));
      expect(repository.saves.single.counts['great'], 99);
      expect(repository.saves.single.counts['almost_there'], 1);
      expect(
        controller.takeErrorMessage(),
        AppStrings.auditUnableToUpdateRating,
      );
      expect(controller.takeErrorMessage(), isNull);
    },
  );

  test(
    'comment saves resolve the audit UUID and refresh without attachments',
    () async {
      final controller = create();
      addTearDown(controller.dispose);
      await controller.ready;
      await controller.saveTextComment('  Observation  ');
      await controller.saveTextComment('  ');
      await controller.saveMediaComment(
        'Attachment observation',
        null,
        'image',
      );
      expect(repository.comments, [
        (id: 'resolved-audit', comment: 'Observation'),
      ]);
      expect(repository.mediaComments, [
        (id: 'resolved-audit', comment: 'Attachment observation', type: null),
      ]);
      expect(repository.loads, hasLength(3));
    },
  );

  test('only the latest comment refresh is applied', () async {
    final controller = create();
    addTearDown(controller.dispose);
    await controller.ready;
    final older = Completer<AuditDescriptionAudit>();
    final newer = Completer<AuditDescriptionAudit>();
    repository.pendingLoads.addAll([older.future, newer.future]);
    final first = controller.refreshComments();
    final second = controller.refreshComments();
    newer.complete(singleDescriptionAudit(ratings: [AuditRating.almostThere]));
    await second;
    older.complete(
      singleDescriptionAudit(ratings: [AuditRating.needsImprovement]),
    );
    await first;
    expect(controller.countFor(AuditRating.almostThere), 1);
    expect(controller.countFor(AuditRating.needsImprovement), 0);
  });

  testWidgets(
    'upload completion uses the resolved audit ID and ignores other descriptions',
    (tester) async {
      final controller = create();
      addTearDown(controller.dispose);
      await controller.ready;
      uploads.emit('another-description');
      await tester.pump();
      expect(repository.loads, hasLength(1));
      uploads.emit('resolved-audit');
      await tester.pump();
      expect(repository.loads, hasLength(2));
      uploads.notifyListeners();
      await tester.pump();
      expect(repository.loads, hasLength(2));
    },
  );

  test(
    'a failed initial load clears progress and a later refresh recovers',
    () async {
      final lookup = Completer<AuditDescriptionAudit>();
      repository.pendingLoads.add(lookup.future);
      final controller = create();
      addTearDown(controller.dispose);
      lookup.completeError(StateError('Load failed'));
      await controller.ready;
      expect(controller.isLoading, isFalse);
      expect(controller.hasLoadError, isTrue);
      expect(controller.hasLoadedAudit, isFalse);
      await controller.refreshComments();
      expect(controller.hasLoadError, isFalse);
      expect(controller.hasLoadedAudit, isTrue);
    },
  );

  testWidgets(
    'closing during UUID loading still saves the pending draft safely',
    (tester) async {
      final lookup = Completer<AuditDescriptionAudit>();
      repository.pendingLoads.add(lookup.future);
      final controller = create();
      controller.incrementRating(AuditRating.great);
      controller.dispose();
      lookup.complete(singleDescriptionAudit());
      await tester.pump();
      expect(repository.saves.single.id, 'resolved-audit');
      expect(repository.saves.single.counts['great'], 2);
      expect(controller.hasLoadedAudit, isFalse);
      expect(uploads.isObserved, isFalse);
    },
  );

  for (final scenario in [
    (owner: true, viewOnly: true, self: false, days: 0, comments: false),
    (owner: false, viewOnly: false, self: false, days: 0, comments: true),
    (owner: true, viewOnly: false, self: true, days: 0, comments: true),
    (owner: true, viewOnly: false, self: false, days: 7, comments: false),
  ]) {
    test(
      'access guards preserve rating and comment behavior for $scenario',
      () async {
        final controller = create(
          isOwner: scenario.owner,
          isViewOnly: scenario.viewOnly,
          isSelfAudit: scenario.self,
          daysAgo: scenario.days,
        );
        addTearDown(controller.dispose);
        await controller.ready;
        expect(controller.canEditRatings, isFalse);
        expect(controller.canCreateComments, scenario.comments);
        controller.incrementRating(AuditRating.great);
        expect(controller.countFor(AuditRating.great), 1);
        expect(repository.saves, isEmpty);
      },
    );
  }
}

class _Uploads extends ChangeNotifier implements CheckInMediaUploadController {
  final tasks = <CheckInMediaUploadTask>[];
  bool get isObserved => hasListeners;

  void emit(String descriptionId) {
    tasks.add(_UploadTask(descriptionId, tasks.length + 1));
    notifyListeners();
  }

  @override
  int get latestTerminalEventSequence => tasks.length;

  @override
  List<CheckInMediaUploadTask> terminalTasksSince(int eventSequence) => tasks
      .where((task) => task.terminalEventSequence > eventSequence)
      .toList();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _UploadTask extends Fake implements CheckInMediaUploadTask {
  _UploadTask(this.descriptionId, this.terminalEventSequence);

  @override
  final String descriptionId;
  @override
  final int terminalEventSequence;
  @override
  CheckInMediaUploadFlow get flow => CheckInMediaUploadFlow.descriptionComment;
  @override
  bool get isCompleted => true;
}
