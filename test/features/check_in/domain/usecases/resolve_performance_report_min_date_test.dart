import 'package:flutter_test/flutter_test.dart';
import 'package:sparrowkaizen/features/check_in/domain/usecases/resolve_performance_report_min_date.dart';

import '../../support/performance_report_fixtures.dart';

void main() {
  const resolve = ResolvePerformanceReportMinDate();
  final today = DateTime(2026, 10, 16, 12);

  for (final value in [
    '2025-09-03T12:00:00',
    '2025/09/03',
    '3rd September, 2025',
    'September 3, 2025',
    '03/09/2025',
  ]) {
    test('preserves the legacy creation date format $value', () {
      expect(
        resolve(reportFixture(createdAt: value), now: today),
        DateTime(2025, 9, 3),
      );
    });
  }

  test('missing years use the current year', () {
    expect(
      resolve(reportFixture(createdAt: '3rd September'), now: today),
      DateTime(2026, 9, 3),
    );
  });

  test('falls through invalid metadata in the original priority order', () {
    expect(
      resolve(
        reportFixture(
          createdAt: 'invalid',
          snapshot: {'createdAt': '31/02/2025', 'created_at': '2025/04/02'},
        ),
        now: today,
      ),
      DateTime(2025, 4, 2),
    );
    expect(
      resolve(reportFixture(createdAt: null, snapshot: {}), now: today),
      DateTime(2025, 1, 1),
    );
  });

  test('future and unavailable bounds clamp to today without a time', () {
    expect(
      resolve(reportFixture(createdAt: '2099-01-01'), now: today),
      DateTime(2026, 10, 16),
    );
    expect(resolve(null, now: today), DateTime(2026, 10, 16));
  });
}
