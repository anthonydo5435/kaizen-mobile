import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sparrowkaizen/core/preference/app_preference.dart';
import 'package:sparrowkaizen/features/check_in/domain/entities/audit_main_list.dart';
import 'package:sparrowkaizen/features/check_in/domain/entities/audit_member_status.dart';
import 'package:sparrowkaizen/features/check_in/domain/entities/audit_profile.dart';
import 'package:sparrowkaizen/features/check_in/domain/entities/audit_job_option.dart';
import 'package:sparrowkaizen/features/check_in/domain/repositories/audit_repository.dart';
import 'package:sparrowkaizen/features/check_in/domain/usecases/get_audit_overview_usecase.dart';
import 'package:sparrowkaizen/features/check_in/presentation/providers/check_in_controller.dart';
import 'package:sparrowkaizen/features/login/domain/entities/user.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await AppPreference.init();
    await AppPreference.saveUser(User(isOwner: true));
  });

  test(
    'silent refresh keeps content visible and guards duplicate loads',
    () async {
      final pending = Completer<AuditMainList>();
      var refreshing = false;
      final repository = _FakeAuditRepository();
      repository.getAuditMainListHandler =
          ({
            required page,
            required pageSize,
            required year,
            required quarter,
            search,
            jobUuid,
          }) => refreshing
          ? pending.future
          : Future.value(_buildMainList(['Original'], next: '?page=2'));
      final controller = _controller(repository);
      addTearDown(controller.dispose);
      await controller.initialize();
      refreshing = true;
      final request = controller.refresh(showLoader: false);
      expect(controller.state.isLoading, isFalse);
      expect(controller.state.mainList!.results.single.name, 'Original');
      await controller.refresh(showLoader: false);
      await controller.loadNextPage();
      expect(repository.forceRefreshes, [false, true]);
      pending.complete(_buildMainList(['Updated']));
      await request;
      expect(controller.state.mainList!.results.single.name, 'Updated');
    },
  );

  test('rapid tab switches discard older responses to the same tab', () async {
    await AppPreference.saveUser(User(roles: ['team_lead']));
    final repository = _FakeAuditRepository();
    repository.getAuditMainListHandler =
        ({
          required page,
          required pageSize,
          required year,
          required quarter,
          search,
          jobUuid,
        }) => Future.value(_buildMainList(['Team Member']));
    final controller = _controller(repository);
    addTearDown(controller.dispose);
    await controller.initialize();

    final olderMyList = Completer<AuditMainList>();
    final olderTeamList = Completer<AuditMainList>();
    final latestMyList = Completer<AuditMainList>();
    repository.getMyAuditsHandler = () => olderMyList.future;
    final first = controller.selectStatus(
      AuditMemberStatus.deactivated,
      refresh: true,
    );
    expect(controller.state.isLoading, isFalse);
    repository.getAuditMainListHandler =
        ({
          required page,
          required pageSize,
          required year,
          required quarter,
          search,
          jobUuid,
        }) => olderTeamList.future;
    final second = controller.selectStatus(
      AuditMemberStatus.active,
      refresh: true,
    );
    repository.getMyAuditsHandler = () => latestMyList.future;
    final third = controller.selectStatus(
      AuditMemberStatus.deactivated,
      refresh: true,
    );
    expect(controller.state.isLoading, isFalse);
    latestMyList.complete(_buildMainList(['Latest My Member']));
    await third;
    olderMyList.complete(_buildMainList(['Older My Member']));
    olderTeamList.complete(_buildMainList(['Older Team Member']));
    await Future.wait([first, second]);
    expect(controller.state.selectedStatus, AuditMemberStatus.deactivated);
    expect(controller.state.mainList!.results.single.name, 'Latest My Member');
    expect(controller.state.isLoading, isFalse);
  });

  test('tab reentry discards pagination from the previous tab', () async {
    await AppPreference.saveUser(User(roles: ['team_lead']));
    final pending = Completer<AuditMainList>();
    final repository = _FakeAuditRepository();
    repository.getAuditMainListHandler =
        ({
          required page,
          required pageSize,
          required year,
          required quarter,
          search,
          jobUuid,
        }) => page == 2
        ? pending.future
        : Future.value(_buildMainList(['Team Member'], next: '?page=2'));
    final controller = _controller(repository);
    addTearDown(controller.dispose);
    await controller.initialize();
    final pagination = controller.loadNextPage();
    await controller.selectStatus(AuditMemberStatus.deactivated, refresh: true);
    pending.complete(_buildMainList(['Older Team Page']));
    await pagination;
    expect(controller.state.mainList!.results.single.name, 'My Member');
    expect(controller.state.isLoadingMore, isFalse);
  });

  group('CheckInController search', () {
    test(
      'continues with the latest query after an older response finishes',
      () async {
        final firstSearchCompleter = Completer<AuditMainList>();
        final secondSearchCompleter = Completer<AuditMainList>();
        final repository = _FakeAuditRepository();

        repository.getAuditMainListHandler =
            ({
              required int page,
              required int pageSize,
              required int year,
              required int quarter,
              String? search,
              String? jobUuid,
            }) {
              repository.requestedSearches.add(search);
              if (search == 'mi') {
                return firstSearchCompleter.future;
              }
              if (search == 'miss') {
                return secondSearchCompleter.future;
              }
              return Future<AuditMainList>.value(
                _buildMainList(<String>['Default Member']),
              );
            };

        final controller = CheckInController(
          GetAuditOverviewUseCase(repository),
          null,
          null,
          null,
          null,
          null,
          null,
          repository,
        );
        addTearDown(controller.dispose);

        await controller.initialize();

        controller.updateSearchQuery('mi');
        await Future<void>.delayed(const Duration(milliseconds: 450));

        controller.updateSearchQuery('miss');
        await Future<void>.delayed(const Duration(milliseconds: 450));

        firstSearchCompleter.complete(_buildMainList(const <String>[]));
        await Future<void>.delayed(const Duration(milliseconds: 25));

        expect(
          repository.requestedSearches
              .where((search) => search == 'miss')
              .length,
          1,
        );

        secondSearchCompleter.complete(
          _buildMainList(<String>['Latest Member']),
        );
        await Future<void>.delayed(const Duration(milliseconds: 25));

        expect(controller.state.isLoading, isFalse);
        expect(controller.state.searchQuery, 'miss');
        expect(
          controller.state.mainList?.results
              .map((member) => member.name)
              .toList(),
          <String>['Latest Member'],
        );
      },
    );

    test(
      'restores the default list when the search query is cleared',
      () async {
        final repository = _FakeAuditRepository();
        repository.getAuditMainListHandler =
            ({
              required int page,
              required int pageSize,
              required int year,
              required int quarter,
              String? search,
              String? jobUuid,
            }) {
              repository.requestedSearches.add(search);
              if (search == null || search.isEmpty) {
                return Future<AuditMainList>.value(
                  _buildMainList(<String>['Default Member']),
                );
              }

              return Future<AuditMainList>.value(
                _buildMainList(const <String>[]),
              );
            };

        final controller = CheckInController(
          GetAuditOverviewUseCase(repository),
          null,
          null,
          null,
          null,
          null,
          null,
          repository,
        );
        addTearDown(controller.dispose);

        await controller.initialize();

        controller.updateSearchQuery('zzz');
        await Future<void>.delayed(const Duration(milliseconds: 450));
        await Future<void>.delayed(const Duration(milliseconds: 25));

        expect(controller.state.mainList?.results, isEmpty);

        final requestCountBeforeClear = repository.requestedSearches.length;
        controller.updateSearchQuery('');

        expect(controller.state.searchQuery, isEmpty);
        expect(controller.state.isLoading, isFalse);
        expect(
          controller.state.mainList?.results
              .map((member) => member.name)
              .toList(),
          <String>['Default Member'],
        );
        expect(repository.requestedSearches.length, requestCountBeforeClear);
      },
    );

    test(
      'search request retains the selected job and quarter filters',
      () async {
        final repository = _FakeAuditRepository();
        repository.jobOptions = const <AuditJobOption>[
          AuditJobOption(uuid: 'job-uuid', title: 'Assembly'),
        ];
        repository.getAuditMainListHandler =
            ({
              required int page,
              required int pageSize,
              required int year,
              required int quarter,
              String? search,
              String? jobUuid,
            }) {
              repository.requests.add(
                _AuditListRequest(
                  page: page,
                  pageSize: pageSize,
                  year: year,
                  quarter: quarter,
                  search: search,
                  jobUuid: jobUuid,
                ),
              );
              return Future<AuditMainList>.value(
                _buildMainList(const <String>[]),
              );
            };

        final controller = CheckInController(
          GetAuditOverviewUseCase(repository),
          null,
          null,
          null,
          null,
          null,
          null,
          repository,
        );
        addTearDown(controller.dispose);

        await controller.initialize();
        await controller.applyFilters(
          yearQuarter: '2025 - Q2',
          seatProfile: 'Assembly',
        );
        controller.updateSearchQuery('alex');
        await Future<void>.delayed(const Duration(milliseconds: 450));
        await Future<void>.delayed(const Duration(milliseconds: 25));

        expect(repository.requests.last.jobUuid, 'job-uuid');
        expect(repository.requests.last.year, 2025);
        expect(repository.requests.last.quarter, 2);
        expect(repository.requests.last.search, 'alex');
        expect(repository.requests.last.page, 1);
        expect(repository.requests.last.pageSize, 12);
      },
    );
  });
}

CheckInController _controller(AuditRepository repository) => CheckInController(
  GetAuditOverviewUseCase(repository),
  null,
  null,
  null,
  null,
  null,
  null,
  repository,
);

AuditMainList _buildMainList(List<String> names, {String? next}) {
  return AuditMainList(
    count: names.length,
    next: next,
    previous: null,
    current: 1,
    results: names
        .map(
          (name) => AuditProfile(
            uuid: '$name-uuid',
            profileJob: '$name-job',
            profileUuid: '$name-profile',
            email: '${name.toLowerCase().replaceAll(' ', '.')}@example.com',
            imageUrl: null,
            isFavorite: false,
            lastAuditDates: const <String?>[],
            roleTitle: 'Operator',
            name: name,
            lastAuditLabel: 'Q3',
            yearQuarter: '2026 - Q3',
            seatProfile: 'Assembly',
            overallScore: 90,
            confidenceLevel: 95,
            status: AuditMemberStatus.active,
            reviewerInitials: const <String>['AB'],
            avatarLabel: name[0].toUpperCase(),
          ),
        )
        .toList(growable: false),
  );
}

class _FakeAuditRepository extends Fake implements AuditRepository {
  final List<String?> requestedSearches = <String?>[];
  final List<_AuditListRequest> requests = <_AuditListRequest>[];
  List<AuditJobOption> jobOptions = const <AuditJobOption>[];
  final forceRefreshes = <bool>[];
  Future<AuditMainList> Function()? getMyAuditsHandler;

  late Future<AuditMainList> Function({
    required int page,
    required int pageSize,
    required int year,
    required int quarter,
    String? search,
    String? jobUuid,
  })
  getAuditMainListHandler;

  @override
  Future<AuditMainList> getAuditMainList({
    required int page,
    required int pageSize,
    required int year,
    required int quarter,
    String? search,
    String? jobUuid,
    bool forceRefresh = false,
  }) {
    forceRefreshes.add(forceRefresh);
    return getAuditMainListHandler(
      page: page,
      pageSize: pageSize,
      year: year,
      quarter: quarter,
      search: search,
      jobUuid: jobUuid,
    );
  }

  @override
  Future<AuditMainList> getMyAudits({
    required int page,
    required int pageSize,
    int? year,
    int? quarter,
    String? search,
    bool forceRefresh = false,
  }) =>
      getMyAuditsHandler?.call() ?? Future.value(_buildMainList(['My Member']));

  @override
  Future<List<AuditJobOption>> getSubordinateJobOptions() {
    return Future<List<AuditJobOption>>.value(jobOptions);
  }
}

class _AuditListRequest {
  const _AuditListRequest({
    required this.page,
    required this.pageSize,
    required this.year,
    required this.quarter,
    required this.search,
    required this.jobUuid,
  });

  final int page;
  final int pageSize;
  final int year;
  final int quarter;
  final String? search;
  final String? jobUuid;
}
