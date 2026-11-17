// ignore_for_file: depend_on_referenced_packages

import 'package:sparrowkaizen/features/check_in/domain/entities/quarterly_audit.dart';
import 'package:sparrowkaizen/features/training/domain/entities/seat_description_training_route.dart';
import 'package:test/test.dart';

void main() {
  late QuarterlyAudit original;

  setUp(() {
    original = QuarterlyAudit(
      uuid: 'quarterly-audit',
      jobUuid: 'job',
      jobTitle: 'Seat',
      isMismatch: false,
      profileUuid: 'profile',
      profileName: 'Member',
      profileEmail: 'member@example.com',
      profileImage: null,
      profileOnboarded: true,
      profileJob: 'profile-job',
      categories: const [],
      descriptions: [_description('first'), _description('second')],
    );
  });

  test('updates only the matching description using saved counts', () {
    final updated = original.withDescriptionRatingCounts(
      descriptionId: 'second',
      auditId: 'second-audit',
      counts: {'great': 5, 'almost_there': 3, 'needs_improvement': 1},
    );

    expect(updated.descriptions.first, same(original.descriptions.first));
    final changed = updated.descriptions.last;
    expect(
      [changed.great, changed.almostThere, changed.needsImprovement],
      [5, 3, 1],
    );
    expect(changed.auditUuid, 'second-audit');
    expect(changed.hasAudit, isTrue);
    expect(changed.description, original.descriptions.last.description);
    expect(changed.trainingRoute, original.descriptions.last.trainingRoute);
    expect(updated.uuid, original.uuid);
    expect(updated.profileUuid, original.profileUuid);
    expect(original.descriptions.last.great, 4);
  });

  test('a detail edit can return to the counts from before a list edit', () {
    final listEdit = original.withDescriptionRatingCounts(
      descriptionId: 'first',
      auditId: 'first-audit',
      counts: {'great': 5},
    );
    final detailEdit = listEdit.withDescriptionRatingCounts(
      descriptionId: 'first',
      auditId: 'first-audit',
      counts: {'great': 4},
    );

    expect(detailEdit.descriptions.first.great, 4);
    expect(listEdit.descriptions.first.great, 5);
  });

  test('accepts zero counts after decrementing the last rating', () {
    final updated = original.withDescriptionRatingCounts(
      descriptionId: 'first',
      auditId: 'first-audit',
      counts: {'great': 0, 'almost_there': 0, 'needs_improvement': 0},
    );

    expect(updated.descriptions.first.totalRatings, 0);
    expect(updated.descriptions.first.hasAudit, isTrue);
  });

  test('does not apply an update to another description', () {
    final updated = original.withDescriptionRatingCounts(
      descriptionId: 'absent',
      auditId: 'unrelated-audit',
      counts: {'great': 9},
    );

    expect(updated, same(original));
  });

  test('mirror updates preserve counts and unrelated description metadata', () {
    final updated = original.withDescriptionRatingCounts(
      descriptionId: 'first',
      auditId: 'first-audit',
      counts: const {},
      hasAudit: false,
      isMirror: true,
    );
    expect(updated.descriptions.first.isMirror, isTrue);
    expect(updated.descriptions.first.great, original.descriptions.first.great);
    expect(updated.descriptions.first.hasAudit, isFalse);
    expect(updated.descriptions.last, same(original.descriptions.last));
    final saved = updated.withDescriptionRatingCounts(
      descriptionId: 'first',
      auditId: 'first-audit',
      counts: {'great': 5},
    );
    expect(saved.descriptions.first.isMirror, isTrue);
  });
}

QuarterlyAuditDescription _description(String id) {
  return QuarterlyAuditDescription(
    uuid: id,
    category: 'category',
    isMirror: false,
    description: 'Description $id',
    jobSpecifics: 'Specifics $id',
    trainingRoute: SeatDescriptionTrainingRoute(
      job: 'job',
      category: 'category',
      description: id,
    ),
    great: 4,
    needsImprovement: 0,
    almostThere: 0,
    pass: 0,
    noPass: 0,
    hasAudit: false,
    auditUuid: '',
    milestoneDay: '',
    lastAuditDate: null,
    confidenceLevel: 0,
    auditFactorType: 'general',
  );
}
