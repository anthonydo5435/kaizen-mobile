import 'package:flutter_test/flutter_test.dart';
import 'package:sparrowkaizen/features/check_in/data/models/audit_details_model.dart';
import 'package:sparrowkaizen/features/check_in/data/models/seat_audit_model.dart';

void main() {
  test(
    'seat response preserves pagination, nested job and all profile fields',
    () {
      final page = SeatAuditPageModel.fromJson({
        'count': 5,
        'next': '?page=2',
        'previous': null,
        'current': 1,
        'results': [_seat],
      });
      expect(
        (page.count, page.next, page.previous, page.current),
        (5, '?page=2', null, 1),
      );
      final seat = page.results.single;
      expect(
        (seat.uuid, seat.job.uuid, seat.job.title),
        ('audit', 'job', 'Developer'),
      );
      expect(seat.overallScore, 3);
      expect(seat.lastAuditDate, 'Oct 16, 2026');
      final profile = seat.profiles.single;
      expect(
        (
          profile.uuid,
          profile.name,
          profile.userUuid,
          profile.email,
          profile.image,
          profile.onboarded,
        ),
        (
          'profile',
          'Member',
          'user',
          'member@example.com',
          'https://example.com/avatar.png',
          true,
        ),
      );
    },
  );

  test('nullable seat fields and empty results are handled', () {
    final seat = SeatAuditModel.fromJson({
      ..._seat,
      'overall_score': 0.0,
      'last_audit_date': null,
      'profiles': [
        {..._profile, 'image': null, 'onboarded': false},
      ],
    });
    expect(seat.lastAuditDate, isNull);
    expect(seat.profiles.single.image, isNull);
    expect(seat.profiles.single.onboarded, isFalse);
    expect(SeatAuditPageModel.fromJson({'results': []}).results, isEmpty);
  });

  test(
    'seat details preserve inconsistency and each audit UUID and rating',
    () {
      final details = AuditDetailsModel.fromApiJson({
        ..._seat,
        'has_inconsistency': true,
        'audits': [
          {
            'date': '2026-10-16',
            'quarterly_audit_uuid': 'row-audit',
            'audit_details': {
              'great': 14,
              'needs_improvement': 3,
              'almost_there': 5,
            },
          },
        ],
      });
      expect(details.hasInconsistency, isTrue);
      expect(details.profiles.single.userUuid, 'user');
      expect(details.profileJob, isEmpty);
      final audit = details.audits.single;
      expect(
        (
          audit.quarterlyAuditUuid,
          audit.great,
          audit.needsImprovement,
          audit.almostThere,
        ),
        ('row-audit', 14, 3, 5),
      );
    },
  );
}

const _profile = {
  'uuid': 'profile',
  'name': 'Member',
  'user_uuid': 'user',
  'email': 'member@example.com',
  'image': 'https://example.com/avatar.png',
  'onboarded': true,
};
const _seat = {
  'uuid': 'audit',
  'job': {'uuid': 'job', 'title': 'Developer'},
  'overall_score': 3.0,
  'last_audit_date': 'Oct 16, 2026',
  'profiles': [_profile],
};
