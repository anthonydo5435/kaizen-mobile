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
