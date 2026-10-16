import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sparrowkaizen/core/constants/app_strings.dart';
import 'package:sparrowkaizen/core/utils/custom_functions.dart';
import 'package:sparrowkaizen/features/check_in/domain/entities/audit_description_audit.dart';
import 'package:sparrowkaizen/features/check_in/domain/entities/quarterly_audit.dart';
import 'package:sparrowkaizen/features/check_in/domain/repositories/audit_repository.dart';
import 'package:sparrowkaizen/features/check_in/domain/usecases/get_audit_overview_usecase.dart';
import 'package:sparrowkaizen/features/check_in/presentation/providers/check_in_controller.dart';
import 'package:sparrowkaizen/features/check_in/presentation/providers/check_in_description_card_controller.dart';
import 'package:sparrowkaizen/features/training/domain/entities/seat_description_training_route.dart';

void main() {
  late _Repository repository;
  late CheckInController checkInController;
  late String today;

  setUp(() {
    repository = _Repository();
    today = _date();
    checkInController = CheckInController(
      GetAuditOverviewUseCase(repository),
      null,
      null,
      null,
      null,
      null,
      null,
      repository,
    );
    addTearDown(checkInController.dispose);
  });

  CheckInDescriptionCardController buildCard({
    QuarterlyAuditDescription? description,
  }) {
    final card = CheckInDescriptionCardController(
      checkInController: checkInController,
      audit: _audit(),
      description: description ?? _description('first'),
      date: today,
      isOwner: true,
      isSelfAudit: false,
    );
    addTearDown(card.dispose);
    return card;
  }

  testWidgets(
    'rapid edits debounce and retain accepted counts when PATCH omits ratings',
    (tester) async {
      final card = buildCard();
      card.incrementRating(AuditRating.great);
      card.incrementRating(AuditRating.great);
      card.incrementRating(AuditRating.almostThere);
      expect(repository.saves, isEmpty);

      await tester.pump(const Duration(milliseconds: 200));
      expect(repository.saves, hasLength(1));
      expect(repository.saves.single.counts, {
        'great': 3,
        'almost_there': 1,
        'needs_improvement': 0,
      });
      repository.saves.single.complete();
      await tester.pump();
      expect(card.countFor(AuditRating.great), 3);
      expect(card.countFor(AuditRating.almostThere), 1);
      expect((await card.prepareForDetails())!['great'], 3);
      expect(repository.saves, hasLength(1));
    },
  );

  testWidgets(
    'opening details resolves the audit UUID and finishes the pending draft first',
    (tester) async {
      final lookup = Completer<AuditDescriptionAudit>();
      repository.lookupResponse = lookup.future;
      final card = buildCard(description: _description('first', auditUuid: ''));
      card.incrementRating(AuditRating.great);
      var didPrepare = false;
      final prepared = card.prepareForDetails()..then((_) => didPrepare = true);
      await tester.pump();

      expect(card.isOpeningDetails, isTrue);
      expect(await card.prepareForDetails(), isNull);
      expect(repository.lookups, 1);
      expect(repository.saves, isEmpty);
      expect(didPrepare, isFalse);

      lookup.complete(_saved('resolved-audit'));
      await tester.pump();
      expect(repository.saves.single.id, 'resolved-audit');
      expect(didPrepare, isFalse);
      repository.saves.single.complete();
      await tester.pump();
      expect((await prepared)!['great'], 2);
      expect(card.isOpeningDetails, isFalse);
      await tester.pump(const Duration(milliseconds: 200));
      expect(repository.saves, hasLength(1));
    },
  );

  testWidgets('older responses and list summaries preserve a newer draft', (
    tester,
  ) async {
    final card = buildCard();
    card.incrementRating(AuditRating.great);
    await tester.pump(const Duration(milliseconds: 200));
    card.incrementRating(AuditRating.great);
    card.update(
      audit: _audit(),
      description: _description('first'),
      date: today,
      isOwner: true,
      isSelfAudit: false,
    );
    await tester.pump(const Duration(milliseconds: 200));
    expect(card.countFor(AuditRating.great), 3);
    expect(repository.saves, hasLength(1));

    repository.saves.first.complete();
    await tester.pump();
    expect(repository.saves, hasLength(2));
    expect(repository.saves.last.counts['great'], 3);
    expect(card.countFor(AuditRating.great), 3);
    repository.saves.last.complete();
    await tester.pump();

    // A subsequent detail edit can legitimately restore the earlier count.
    card.update(
      audit: _audit(),
      description: _description('first', great: 2),
      date: today,
      isOwner: true,
      isSelfAudit: false,
    );
    expect(card.countFor(AuditRating.great), 2);
  });

  testWidgets(
    'failed saves restore the last accepted counts and expose an error',
    (tester) async {
      final card = buildCard();
      card.incrementRating(AuditRating.great);
      await tester.pump(const Duration(milliseconds: 200));
      repository.saves.single.complete();
      await tester.pump();
      card.decrementRating(AuditRating.great);
      await tester.pump(const Duration(milliseconds: 200));
      repository.saves.last.result.completeError(StateError('Save failed'));
      await tester.pump();

      expect(card.countFor(AuditRating.great), 2);
      expect(card.takeErrorMessage(), AppStrings.auditUnableToUpdateRating);
      expect(card.takeErrorMessage(), isNull);
    },
  );

  testWidgets('an old request cannot overwrite a newly selected description', (
    tester,
  ) async {
    final card = buildCard();
    card.incrementRating(AuditRating.great);
    final prepared = card.prepareForDetails();
    await tester.pump();
    card.update(
      audit: _audit(),
      description: _description('second', great: 5),
      date: today,
      isOwner: true,
      isSelfAudit: false,
    );
    repository.saves.single.complete();
    await tester.pump();

    expect(await prepared, isNull);
    expect(card.countFor(AuditRating.great), 5);
    expect(card.isOpeningDetails, isFalse);
  });

  test(
    'Comment Only retries failed UUID loading and uses the resolved audit ID',
    () async {
      final card = buildCard(description: _description('first', auditUuid: ''));
      repository.failLookup = true;
      await expectLater(card.resolveAuditUuid(), throwsStateError);
      repository.failLookup = false;

      await card.saveTextComment('Observation without an attachment');
      await card.saveTextComment('Another observation');
      expect(repository.lookups, 2);
      expect(repository.comments, [
        (id: 'resolved-audit', comment: 'Observation without an attachment'),
        (id: 'resolved-audit', comment: 'Another observation'),
      ]);
      expect(repository.saves, isEmpty);
    },
  );

  test('a rating at its limit does not prevent editing another rating', () {
    final card = buildCard(description: _description('first', great: 99));
    card.incrementRating(AuditRating.great);
    card.incrementRating(AuditRating.almostThere);
    card.decrementRating(AuditRating.needsImprovement);
    expect(card.countFor(AuditRating.great), 99);
    expect(card.countFor(AuditRating.almostThere), 1);
    expect(card.countFor(AuditRating.needsImprovement), 0);
  });

  test('date and mismatch filters keep only eligible descriptions', () {
    final audit = _audit();
    expect(
      checkInController.filteredDescriptions(audit, date: today),
      hasLength(2),
    );
    expect(
      checkInController.filteredDescriptions(audit, date: _date(daysAgo: 6)),
      hasLength(2),
    );
    expect(
      checkInController
          .filteredDescriptions(audit, date: _date(daysAgo: 7))
          .map((item) => item.uuid),
      ['first'],
    );
    expect(
      checkInController
          .filteredDescriptions(_audit(mismatch: true), date: today)
          .map((item) => item.uuid),
      ['first'],
    );
  });

  test(
    'category, milestone, timing, type and search filters compose and clear',
    () {
      final audit = _audit();
      checkInController.toggleDescriptionFilterOptions();
      checkInController.toggleDescriptionCategory('Responsibilities');
      checkInController.toggleDescriptionMilestone('30 Days');
      checkInController.toggleDescriptionAuditTiming('Inprogress');
      checkInController.toggleDescriptionAuditType('Observation');
      checkInController.toggleShowAuditedDescriptionsOnly();
      checkInController.updateDescriptionSearchQuery('  FIRST  ');
      expect(
        checkInController
            .filteredDescriptions(audit, date: today)
            .map((item) => item.uuid),
        ['first'],
      );
      expect(checkInController.descriptionCategoryOptions(audit, date: today), [
        'Responsibilities',
        'Skills',
      ]);
      expect(
        checkInController.descriptionMilestoneOptions(audit, date: today),
        ['30 Days', '60 Days'],
      );
      expect(
        checkInController.descriptionAuditTimingOptions(audit, date: today),
        ['Available', 'Inprogress'],
      );
      expect(
        checkInController.descriptionAuditTypeOptions(audit, date: today),
        ['Examination', 'Observation'],
      );

      checkInController.updateDescriptionSearchQuery('second');
      expect(
        checkInController.filteredDescriptions(audit, date: today),
        isEmpty,
      );
      checkInController.clearDescriptionFilters();
      expect(checkInController.descriptionFilters.hasActiveFilters, isFalse);
      expect(
        checkInController.descriptionFilters.isFilterOptionsVisible,
        isFalse,
      );
      expect(checkInController.descriptionSearchQuery, 'second');
      expect(
        checkInController.filteredDescriptions(audit, date: today).single.uuid,
        'second',
      );
    },
  );
}

String _date({int daysAgo = 0}) => CustomFunctions.apiDateString(
  date: DateTime.now().subtract(Duration(days: daysAgo)),
);

QuarterlyAudit _audit({bool mismatch = false}) => QuarterlyAudit(
  uuid: 'quarterly-audit',
  jobUuid: 'job',
  jobTitle: 'Seat',
  isMismatch: mismatch,
  profileUuid: 'profile',
  profileName: 'Member',
  profileEmail: '',
  profileImage: null,
  profileOnboarded: true,
  profileJob: 'profile-job',
  categories: const [
    QuarterlyAuditCategory(
      uuid: 'category-a',
      categoryTitle: 'Responsibilities',
    ),
    QuarterlyAuditCategory(uuid: 'category-b', categoryTitle: 'Skills'),
  ],
  descriptions: [_description('first'), _description('second', great: 0)],
);

QuarterlyAuditDescription _description(
  String id, {
  int great = 1,
  String? auditUuid,
}) => QuarterlyAuditDescription(
  uuid: id,
  category: id == 'first' ? 'category-a' : 'category-b',
  isMirror: false,
  description: 'Description $id',
  jobSpecifics: '',
  trainingRoute: SeatDescriptionTrainingRoute(
    job: 'job',
    category: 'category',
    description: id,
  ),
  great: great,
  needsImprovement: 0,
  almostThere: 0,
  pass: 0,
  noPass: 0,
  hasAudit: great > 0,
  auditUuid: auditUuid ?? '$id-audit',
  milestoneDay: id == 'first' ? '30' : '60',
  lastAuditDate: null,
  confidenceLevel: 0,
  auditFactorType: id == 'first' ? 'observation' : 'examination',
);

AuditDescriptionAudit _saved(String id) => AuditDescriptionAudit(
  uuid: id,
  audit: const [],
  isGeneral: false,
  isMirror: false,
  auditMedia: const [],
  weightedScore: 0,
);

class _Repository implements AuditRepository {
  final saves = <_Save>[];
  final comments = <({String id, String comment})>[];
  var lookups = 0;
  var failLookup = false;
  Future<AuditDescriptionAudit>? lookupResponse;

  @override
  Future<AuditDescriptionAudit> getAuditDescriptionAudit({
    required String quarterlyAuditId,
    required String descriptionId,
    required String date,
  }) async {
    lookups += 1;
    if (failLookup) throw StateError('Load failed');
    return lookupResponse ?? _saved('resolved-audit');
  }

  @override
  Future<AuditDescriptionAudit> submitDescriptionAudit({
    required String descriptionId,
    required Map<String, int> audit,
  }) {
    final save = _Save(descriptionId, audit);
    saves.add(save);
    return save.result.future;
  }

  @override
  Future<void> createAuditDescriptionComment({
    required String descriptionId,
    required String comment,
  }) async {
    comments.add((id: descriptionId, comment: comment));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _Save {
  _Save(this.id, this.counts);
  final String id;
  final Map<String, int> counts;
  final result = Completer<AuditDescriptionAudit>();

  void complete() => result.complete(_saved(id));
}
