import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sparrowkaizen/core/constants/app_strings.dart';
import 'package:sparrowkaizen/core/utils/custom_functions.dart';
import 'package:sparrowkaizen/features/check_in/domain/entities/seat_audit.dart';
import 'package:sparrowkaizen/features/check_in/domain/repositories/audit_repository.dart';
import 'package:sparrowkaizen/features/check_in/presentation/providers/general_seats_controller.dart';

void main() {
  late _Repository repository;
  late GeneralSeatsController controller;
  setUp(() {
    repository = _Repository();
    controller = GeneralSeatsController(repository);
  });
  tearDown(() => controller.dispose());

  test(
    'initializes once with the current quarter and 12 seats per page',
    () async {
      await controller.initialize();
      await controller.initialize();
      final period = CustomFunctions.currentYearQuarter();
      expect(repository.requests, hasLength(1));
      final request = repository.requests.single;
      expect(
        (request.page, request.pageSize, request.year, request.quarter),
        (1, 12, period.year, period.quarter),
      );
      expect(controller.isLoading, isFalse);
    },
  );

  test('pagination is guarded and merges without repeating seats', () async {
    await controller.initialize();
    final pending = Completer<SeatAuditPage>();
    repository.respond = (_) => pending.future;
    final loading = controller.loadNextPage();
    await controller.loadNextPage();
    expect(repository.requests, hasLength(2));
    pending.complete(_page(2, ids: ['seat-1', 'seat-2'], next: false));
    await loading;
    expect(controller.seats.map((seat) => seat.uuid), ['seat-1', 'seat-2']);
    await controller.loadNextPage();
    expect(repository.requests, hasLength(2));
  });

  test('changing quarter discards an older pagination response', () async {
    await controller.initialize();
    final pending = Completer<SeatAuditPage>();
    repository.respond = (request) => request.page == 2
        ? pending.future
        : Future.value(_page(1, ids: ['new-quarter']));
    final loading = controller.loadNextPage();
    await controller.applyYearQuarter('2025 - Q2');
    expect(
      (repository.requests.last.year, repository.requests.last.quarter),
      (2025, 2),
    );
    expect(repository.requests.last.page, 1);
    pending.complete(_page(2, ids: ['old-quarter']));
    await loading;
    expect(controller.seats.single.uuid, 'new-quarter');
    expect(controller.isLoadingMore, isFalse);
  });

  test(
    'refresh bypasses cache; failures preserve seats and can be retried',
    () async {
      await controller.initialize();
      repository.respond = (_) => Future.error(StateError('offline'));
      await controller.refresh();
      expect(repository.requests.last.forceRefresh, isTrue);
      expect(controller.error, AppStrings.auditGeneralSeatsLoadError);
      expect(controller.seats, hasLength(1));
      await controller.loadNextPage();
      expect(controller.paginationError, AppStrings.auditGeneralSeatsPageError);
      repository.respond = (_) => Future.value(_page(2, next: false));
      await controller.loadNextPage();
      expect(controller.paginationError, isNull);
      expect(controller.seats, hasLength(2));
    },
  );

  test(
    'reselecting the quarter keeps the loaded page without another request',
    () async {
      await controller.initialize();
      await controller.loadNextPage();
      final requestCount = repository.requests.length;
      await controller.applyYearQuarter(controller.yearQuarterLabel);
      expect(repository.requests, hasLength(requestCount));
      expect(controller.seats, hasLength(2));
    },
  );

  test('zero is unavailable only when the seat has never been audited', () {
    expect(controller.scoreLabel(_seat('new')), '-');
    expect(controller.scoreLabel(_seat('audited', date: 'Oct 16, 2026')), '0');
    expect(controller.scoreLabel(_seat('scored', score: 3)), '3');
    expect(controller.scoreLabel(_seat('decimal', score: 3.5)), '3.5');
  });

  test('seat switching uses 10-item pages without period filters', () async {
    final switcher = GeneralSeatsController(
      repository,
      pageSize: 10,
      filterByPeriod: false,
    );
    addTearDown(switcher.dispose);
    await switcher.initialize();
    await switcher.loadNextPage();
    expect(repository.requests.map((request) => request.page), [1, 2]);
    for (final request in repository.requests) {
      expect(request.pageSize, 10);
      expect(request.year, isNull);
      expect(request.quarter, isNull);
    }
  });

  test('a response after disposal does not notify listeners', () async {
    final pending = Completer<SeatAuditPage>();
    repository.respond = (_) => pending.future;
    final disposable = GeneralSeatsController(repository);
    var notifications = 0;
    disposable.addListener(() => notifications++);
    final loading = disposable.initialize();
    disposable.dispose();
    pending.complete(_page(1));
    await loading;
    expect(notifications, 1);
  });
}

SeatAudit _seat(String id, {double score = 0, String? date}) => SeatAudit(
  uuid: id,
  job: const SeatAuditJob(uuid: 'job', title: 'Developer'),
  overallScore: score,
  lastAuditDate: date,
  profiles: const [],
);

SeatAuditPage _page(int page, {List<String>? ids, bool next = true}) =>
    SeatAuditPage(
      count: 2,
      next: next ? '?page=2' : null,
      previous: page == 1 ? null : '?page=1',
      current: page,
      results: (ids ?? ['seat-$page']).map(_seat).toList(),
    );

typedef _Request = ({
  int page,
  int pageSize,
  int? year,
  int? quarter,
  bool forceRefresh,
});

class _Repository extends Fake implements AuditRepository {
  final requests = <_Request>[];
  Future<SeatAuditPage> Function(_Request)? respond;

  @override
  Future<SeatAuditPage> getSeatAudits({
    required int page,
    required int pageSize,
    int? year,
    int? quarter,
    bool forceRefresh = false,
  }) {
    final request = (
      page: page,
      pageSize: pageSize,
      year: year,
      quarter: quarter,
      forceRefresh: forceRefresh,
    );
    requests.add(request);
    return respond?.call(request) ?? Future.value(_page(page));
  }
}
