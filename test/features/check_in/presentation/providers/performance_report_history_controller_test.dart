import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sparrowkaizen/core/constants/app_strings.dart';
import 'package:sparrowkaizen/features/check_in/domain/entities/performance_report.dart';
import 'package:sparrowkaizen/features/check_in/presentation/providers/performance_report_history_controller.dart';

void main() {
  const original = CertifiedReportOption(
    uuid: 'original',
    displayName: 'Original report',
  );
  const filtered = CertifiedReportOption(
    uuid: 'filtered',
    displayName: 'Filtered report',
  );
  final firstRange = DateTimeRange(
    start: DateTime(2026, 1, 1),
    end: DateTime(2026, 1, 31),
  );
  final secondRange = DateTimeRange(
    start: DateTime(2026, 2, 1),
    end: DateTime(2026, 2, 28),
  );

  test(
    'filter errors preserve the last successful results and date label',
    () async {
      var fail = false;
      final controller = PerformanceReportHistoryController(
        initialOptions: const [original],
        loadReports: (_) async {
          if (fail) throw StateError('Unavailable');
          return const [filtered];
        },
      );
      addTearDown(controller.dispose);
      expect(controller.dateRangeLabel, AppStrings.performanceReportAllReports);
      await controller.applyDateRange(firstRange);
      expect(controller.options, [filtered]);
      expect(controller.dateRangeLabel, '01 Jan 2026 - 31 Jan 2026');
      fail = true;
      await controller.applyDateRange(secondRange);
      expect(controller.options, [filtered]);
      expect(controller.dateRange, firstRange);
      expect(controller.error, AppStrings.performanceReportHistoryLoadFailed);
      expect(controller.isLoading, isFalse);
    },
  );

  test('a delayed response cannot overwrite a newer filtered list', () async {
    final first = Completer<List<CertifiedReportOption>>();
    final second = Completer<List<CertifiedReportOption>>();
    final controller = PerformanceReportHistoryController(
      initialOptions: const [original],
      loadReports: (range) =>
          range == firstRange ? first.future : second.future,
    );
    addTearDown(controller.dispose);
    final older = controller.applyDateRange(firstRange);
    final newer = controller.applyDateRange(secondRange);
    second.complete(const [filtered]);
    await newer;
    first.complete(const [original]);
    await older;
    expect(controller.options, [filtered]);
    expect(controller.dateRange, secondRange);
    expect(controller.isLoading, isFalse);
  });

  test('closing the sheet discards its pending response', () async {
    final pending = Completer<List<CertifiedReportOption>>();
    final controller = PerformanceReportHistoryController(
      initialOptions: const [original],
      loadReports: (_) => pending.future,
    );
    var notifications = 0;
    controller.addListener(() => notifications++);
    final loading = controller.applyDateRange(firstRange);
    expect(notifications, 1);
    controller.dispose();
    pending.complete(const [filtered]);
    await loading;
    expect(notifications, 1);
    expect(controller.options, [original]);
  });

  test(
    'silent refresh retains visible reports and Clear Dates restores All Reports',
    () async {
      final pending = Completer<List<CertifiedReportOption>>();
      final requests = <DateTimeRange?>[];
      final controller = PerformanceReportHistoryController(
        initialOptions: const [original],
        loadReports: (range) async {
          requests.add(range);
          if (requests.length == 1) return pending.future;
          return range == null ? const [original] : const [filtered];
        },
      );
      addTearDown(controller.dispose);
      final refresh = controller.refresh();
      expect(controller.isLoading, isFalse);
      expect(controller.options, [original]);
      pending.complete(const [original]);
      await refresh;
      await controller.applyDateRange(firstRange);
      expect(controller.options, [filtered]);
      await controller.clearDates();
      expect(controller.dateRange, isNull);
      expect(controller.dateRangeLabel, AppStrings.performanceReportAllReports);
      expect(controller.options, [original]);
      expect(requests, [null, firstRange, null]);
    },
  );

  test(
    'a failed background refresh retains cached reports without error feedback',
    () async {
      final controller = PerformanceReportHistoryController(
        initialOptions: const [original],
        loadReports: (_) async => throw StateError('Unavailable'),
      );
      addTearDown(controller.dispose);
      await controller.refresh();
      expect(controller.options, [original]);
      expect(controller.isLoading, isFalse);
      expect(controller.error, isNull);
    },
  );
}
