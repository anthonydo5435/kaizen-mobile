import 'package:flutter_test/flutter_test.dart';
import 'package:sparrowkaizen/features/check_in/data/models/audit_description_audit_model.dart';

void main() {
  test('decodes rating count objects without expanding them into a list', () {
    final response = AuditDescriptionAuditModel.fromApiJson({
      'uuid': 'audit-description',
      'audit': {'great': 7, 'almost_there': '3', 'needs_improvement': 2.0},
    });

    expect(response.uuid, 'audit-description');
    expect(response.ratingCounts, {
      'great': 7,
      'almost_there': 3,
      'needs_improvement': 2,
    });
    expect(response.audit, isEmpty);
  });

  test('explicit zero counts remain usable ratings', () {
    final response = AuditDescriptionAuditModel.fromApiJson({
      'audit': {'great': 0, 'almost_there': 0, 'needs_improvement': 0},
    });

    expect(response.ratingCounts, {
      'great': 0,
      'almost_there': 0,
      'needs_improvement': 0,
    });
  });

  test('partial objects omit missing or invalid counters', () {
    final response = AuditDescriptionAuditModel.fromApiJson({
      'audit': {
        'great': '4',
        'almost_there': 'invalid',
        'needs_improvement': -1,
        'unknown': 10,
      },
    });

    expect(response.ratingCounts, {'great': 4});
  });

  test('legacy rating lists retain string and boolean counts', () {
    final response = AuditDescriptionAuditModel.fromApiJson({
      'audit': [
        'great',
        true,
        'almost_there',
        'Almost There',
        false,
        'needs_improvement',
        'Needs Improvement',
        'unknown',
      ],
    });

    expect(response.ratingCounts, {
      'great': 2,
      'almost_there': 2,
      'needs_improvement': 3,
    });
  });

  test('absent or unusable ratings do not supply replacement counts', () {
    for (final json in <Map<String, dynamic>>[
      {},
      {'audit': null},
      {'audit': <String, dynamic>{}},
      {'audit': <Object>[]},
      {'audit': 'invalid'},
      {
        'audit': {'unknown': 1},
      },
    ]) {
      expect(AuditDescriptionAuditModel.fromApiJson(json).ratingCounts, isNull);
    }
  });
}
