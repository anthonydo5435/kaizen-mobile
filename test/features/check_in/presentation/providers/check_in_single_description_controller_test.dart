import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sparrowkaizen/core/constants/app_strings.dart';
import 'package:sparrowkaizen/features/check_in/domain/entities/audit_description_audit.dart';
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
    int daysAgo = 0,
  }) => CheckInSingleDescriptionController(
    checkInController: checkIn,
    audit: singleDescriptionQuarterlyAudit(),
    description: singleDescription('first'),
    date: singleDescriptionDate(daysAgo: daysAgo),
    isOwner: isOwner,
    isViewOnly: isViewOnly,
    isSelfAudit: isSelfAudit,
    initialRatingCounts: initialCounts,
    mediaUploadController: uploads,
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
