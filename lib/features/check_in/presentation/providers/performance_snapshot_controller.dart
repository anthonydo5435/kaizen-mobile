import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/network/api_error.dart';
import '../../../../core/preference/app_preference.dart';
import '../../../../core/utils/app_permission_utils.dart';
import '../../data/repositories/audit_repository_impl.dart';
import '../../domain/entities/audit_main_list.dart';
import '../../domain/entities/audit_member.dart';
import '../../domain/entities/audit_member_status.dart';
import '../../domain/entities/audit_profile.dart';

enum PerformanceSnapshotTab { reports, myReports }

class PerformanceSnapshotController extends ChangeNotifier {
  static const Duration _searchDebounceDuration = Duration(milliseconds: 400);

  PerformanceSnapshotController(this._repository) {
    scrollController.addListener(_handleScroll);
  }

  final AuditRepositoryImpl _repository;

  final TextEditingController searchController = TextEditingController();
  final ScrollController scrollController = ScrollController();

  PerformanceSnapshotTab _selectedTab = PerformanceSnapshotTab.myReports;
  PagedAuditData _reportsData = const PagedAuditData();
  PagedAuditData _myReportsData = const PagedAuditData();
  PagedAuditData? _defaultReportsData;
  PagedAuditData? _defaultMyReportsData;
  bool _canAccessTeamReports = false;
  bool _isActualOwner = false;
  bool _isInitializing = true;
  bool _isFilterLoading = false;
  List<String> _jobOptions = const <String>[];
  String _searchQuery = '';
  String? _selectedJobTitle;
  String? _myReportsErrorMessage;
  Timer? _searchDebounceTimer;
  bool _hasPendingSearchRefresh = false;
  bool _isDisposed = false;

  bool get canAccessTeamReports => _canAccessTeamReports;
  bool get isActualOwner => _isActualOwner;
  PerformanceSnapshotTab get selectedTab => _selectedTab;
  bool get isFilterLoading => _isFilterLoading;
  List<String> get jobOptions => _jobOptions;
  String get searchQuery => _searchQuery;
  String? get selectedJobTitle => _selectedJobTitle;
  bool get isSearchLoading =>
      currentData.isLoading &&
      currentData.items.isNotEmpty &&
      _searchQuery.trim().isNotEmpty;

  PagedAuditData get currentData =>
      _selectedTab == PerformanceSnapshotTab.reports
      ? _reportsData
      : _myReportsData;

  List<AuditProfile> get visibleReports {
    return currentData.items
        .where((item) {
          final matchesJob =
              _selectedJobTitle == null || item.roleTitle == _selectedJobTitle;
          return matchesJob;
        })
        .toList(growable: false);
  }

  bool get isInitialLoading =>
      _isInitializing || (currentData.isLoading && currentData.items.isEmpty);

  String get emptyStateMessage {
    final hasFilters =
        _searchQuery.trim().isNotEmpty || _selectedJobTitle != null;
    return switch (_selectedTab) {
      PerformanceSnapshotTab.reports when !hasFilters =>
        AppStrings.performanceSnapshotDataUnavailable,
      PerformanceSnapshotTab.reports => AppStrings.performanceSnapshotNoReports,
      PerformanceSnapshotTab.myReports when _myReportsErrorMessage != null =>
        _myReportsErrorMessage!,
      PerformanceSnapshotTab.myReports =>
        AppStrings.performanceSnapshotNoMyReports,
    };
  }

  Future<void> initialize() async {
    try {
      _cancelPendingSearchRefresh();
      _searchQuery = '';
      searchController.clear();
      _reportsData = const PagedAuditData();
      _myReportsData = const PagedAuditData();
      _defaultReportsData = null;
      _defaultMyReportsData = null;
      final user = await AppPreference.getUser();
      _canAccessTeamReports = AppPermissionUtils.canAccessAuditTeamMembers(
        user,
      );
      _isActualOwner = AppPermissionUtils.hasOwnerOverrideAccess(user);
      _selectedTab = _canAccessTeamReports
          ? PerformanceSnapshotTab.reports
          : PerformanceSnapshotTab.myReports;
      notifyListeners();

      if (_canAccessTeamReports) {
        await loadReports();
      } else {
        await loadMyReports();
      }
    } finally {
      _isInitializing = false;
      notifyListeners();
    }
  }

  Future<void> refresh() async {
    if (_isDisposed ||
        _isInitializing ||
        currentData.isLoading ||
        currentData.isLoadingMore) {
      return;
    }
    _cancelPendingSearchRefresh();
    await _refreshSearchResults(showLoader: true, forceRefresh: true);
  }

  void selectTab(AuditMemberStatus status) {
    if (!_canAccessTeamReports) {
      return;
    }

    final nextTab = status == AuditMemberStatus.active
        ? PerformanceSnapshotTab.reports
        : PerformanceSnapshotTab.myReports;
    if (_selectedTab == nextTab) {
      return;
    }

    _selectedTab = nextTab;
    _selectedJobTitle = null;
    _cancelPendingSearchRefresh();
    _searchQuery = '';
    searchController.clear();
    final nextTabData = currentData;
    notifyListeners();

    if (_currentDataMatchesSearch() && nextTabData.currentPage > 0) {
      return;
    }

    if (nextTab == PerformanceSnapshotTab.reports) {
      unawaited(loadReports());
      return;
    }

    unawaited(loadMyReports());
  }

  Future<void> loadReports({
    bool loadMore = false,
    bool force = false,
    bool showLoader = true,
    bool forceRefresh = false,
  }) async {
    final currentData = _reportsData;
    if (!force && (currentData.isLoading || currentData.isLoadingMore)) {
      return;
    }

    _reportsData = currentData.copyWith(
      isLoading: !loadMore && showLoader,
      isLoadingMore: loadMore,
    );
    notifyListeners();

    final nextPage = loadMore ? currentData.currentPage + 1 : 1;
    final requestQuery = _searchQuery.trim();
    final requestKey = _requestKeyFor(
      tab: PerformanceSnapshotTab.reports,
      query: requestQuery,
    );
    try {
      final result = await _repository.getPerformanceSnapshot(
        page: nextPage,
        pageSize: 12,
        search: requestQuery.isEmpty ? null : requestQuery,
        forceRefresh: forceRefresh,
      );
      if (_isDisposed) {
        return;
      }
      final isStaleRequest =
          requestKey !=
          _requestKeyFor(
            tab: PerformanceSnapshotTab.reports,
            query: _searchQuery.trim(),
          );
      if (isStaleRequest) {
        _reportsData = _reportsData.copyWith(
          isLoading: false,
          isLoadingMore: false,
        );
        notifyListeners();
        _flushPendingSearchRefresh();
        return;
      }

      final parsed = _parsePerformanceSnapshotResponse(result);
      final parsedItems = parsed.items;

      _reportsData = PagedAuditData.fromMainList(
        parsed.mainList,
        items: loadMore ? [...currentData.items, ...parsedItems] : parsedItems,
        query: requestQuery,
      );
      if (requestQuery.isEmpty) {
        _defaultReportsData = _reportsData;
      }
    } catch (error) {
      if (_isDisposed) {
        return;
      }
      final isStaleRequest =
          requestKey !=
          _requestKeyFor(
            tab: PerformanceSnapshotTab.reports,
            query: _searchQuery.trim(),
          );
      if (isStaleRequest) {
        _reportsData = _reportsData.copyWith(
          isLoading: false,
          isLoadingMore: false,
        );
        notifyListeners();
        _flushPendingSearchRefresh();
        return;
      }

      _reportsData = currentData.copyWith(
        isLoading: false,
        isLoadingMore: false,
      );
      debugPrint('PerformanceSnapshotController.loadReports failed: $error');
    }
    notifyListeners();
    _flushPendingSearchRefresh();
  }

  Future<void> loadMyReports({
    bool loadMore = false,
    bool force = false,
    bool showLoader = true,
    bool forceRefresh = false,
  }) async {
    final currentData = _myReportsData;
    if (!force && (currentData.isLoading || currentData.isLoadingMore)) {
      return;
    }

    _myReportsData = currentData.copyWith(
      isLoading: !loadMore && showLoader,
      isLoadingMore: loadMore,
    );
    if (!loadMore) {
      _myReportsErrorMessage = null;
    }
    notifyListeners();

    final nextPage = loadMore ? currentData.currentPage + 1 : 1;
    final requestQuery = _searchQuery.trim();
    final requestKey = _requestKeyFor(
      tab: PerformanceSnapshotTab.myReports,
      query: requestQuery,
    );
    try {
      final result = await _repository.getMyPerformanceSnapshot(
        page: nextPage,
        pageSize: 12,
        search: requestQuery.isEmpty ? null : requestQuery,
        forceRefresh: forceRefresh,
      );
      if (_isDisposed) {
        return;
      }
      final isStaleRequest =
          requestKey !=
          _requestKeyFor(
            tab: PerformanceSnapshotTab.myReports,
            query: _searchQuery.trim(),
          );
      if (isStaleRequest) {
        _myReportsData = _myReportsData.copyWith(
          isLoading: false,
          isLoadingMore: false,
        );
        notifyListeners();
        _flushPendingSearchRefresh();
        return;
      }

      final parsed = _parsePerformanceSnapshotResponse(result);
      final parsedItems = parsed.items;

      _myReportsData = PagedAuditData.fromMainList(
        parsed.mainList,
        items: loadMore ? [...currentData.items, ...parsedItems] : parsedItems,
        query: requestQuery,
      );
      if (requestQuery.isEmpty) {
        _defaultMyReportsData = _myReportsData;
      }
      _myReportsErrorMessage = null;
    } on ApiError catch (error) {
      final isStaleRequest =
          requestKey !=
          _requestKeyFor(
            tab: PerformanceSnapshotTab.myReports,
            query: _searchQuery.trim(),
          );
      if (isStaleRequest) {
        _myReportsData = _myReportsData.copyWith(
          isLoading: false,
          isLoadingMore: false,
        );
        notifyListeners();
        _flushPendingSearchRefresh();
        return;
      }

      if (error.statusCode == 400) {
        _myReportsData = currentData.copyWith(
          isLoading: false,
          isLoadingMore: false,
        );
        _myReportsErrorMessage = 'Profile doesnt exist';
      } else {
        _myReportsData = currentData.copyWith(
          isLoading: false,
          isLoadingMore: false,
        );
        _myReportsErrorMessage = error.message;
        debugPrint(
          'PerformanceSnapshotController.loadMyReports failed: $error',
        );
      }
    } catch (error) {
      if (_isDisposed) {
        return;
      }
      final isStaleRequest =
          requestKey !=
          _requestKeyFor(
            tab: PerformanceSnapshotTab.myReports,
            query: _searchQuery.trim(),
          );
      if (isStaleRequest) {
        _myReportsData = _myReportsData.copyWith(
          isLoading: false,
          isLoadingMore: false,
        );
        notifyListeners();
        _flushPendingSearchRefresh();
        return;
      }

      _myReportsData = currentData.copyWith(
        isLoading: false,
        isLoadingMore: false,
      );
      _myReportsErrorMessage = error.toString();
      debugPrint('PerformanceSnapshotController.loadMyReports failed: $error');
    }
    notifyListeners();
    _flushPendingSearchRefresh();
  }

  Future<void> loadMore() async {
    final data = currentData;
    if (!data.hasNextPage || data.isLoading || data.isLoadingMore) {
      return;
    }

    if (_selectedTab == PerformanceSnapshotTab.reports) {
      await loadReports(loadMore: true);
      return;
    }

    await loadMyReports(loadMore: true);
  }

  Future<void> ensureJobOptionsLoaded() async {
    if (_isFilterLoading || _jobOptions.isNotEmpty) {
      return;
    }

    _isFilterLoading = true;
    notifyListeners();

    try {
      _jobOptions = await _repository.getSubordinateJobTitles();
    } catch (error) {
      debugPrint(
        'PerformanceSnapshotController.ensureJobOptionsLoaded failed: $error',
      );
    } finally {
      _isFilterLoading = false;
      notifyListeners();
    }
  }

  void setSelectedJobTitle(String? value) {
    final nextValue = value == null || value.isEmpty ? null : value;
    if (_selectedJobTitle == nextValue) {
      return;
    }

    _selectedJobTitle = nextValue;
    notifyListeners();
  }

  void clearSelectedJobTitle() {
    if (_selectedJobTitle == null) {
      return;
    }

    _selectedJobTitle = null;
    notifyListeners();
  }

  void updateSearchQuery(String value) {
    final nextQuery = value.trim().isEmpty ? '' : value;
    if (_searchQuery == nextQuery) {
      return;
    }

    _cancelPendingSearchRefresh();
    _searchQuery = nextQuery;

    if (nextQuery.isEmpty) {
      final defaultData = _defaultDataForSelectedTab;
      if (defaultData != null) {
        _setDataForSelectedTab(defaultData);
      }
      notifyListeners();

      if (defaultData != null) {
        return;
      }

      _scheduleSearchRefresh(immediate: true);
      return;
    }

    notifyListeners();
    _scheduleSearchRefresh();
  }

  Future<void> resetSearch({bool showLoader = true}) async {
    _cancelPendingSearchRefresh();
    final defaultData = _defaultDataForSelectedTab;
    _searchQuery = '';
    searchController.clear();
    if (defaultData != null) {
      _setDataForSelectedTab(defaultData);
    }
    notifyListeners();

    if (defaultData != null) {
      return;
    }

    await _refreshSearchResults(showLoader: showLoader);
  }

  void _handleScroll() {
    if (!scrollController.hasClients ||
        scrollController.position.extentAfter > 360) {
      return;
    }

    loadMore();
  }

  _PerformanceSnapshotParseResult _parsePerformanceSnapshotResponse(
    dynamic json,
  ) {
    final listContainer = switch (json) {
      Map<String, dynamic>() =>
        json['results'] ??
            json['data'] ??
            json['items'] ??
            json['records'] ??
            json,
      _ => json,
    };

    final records = switch (listContainer) {
      List<dynamic>() => listContainer.whereType<Map<String, dynamic>>().toList(
        growable: false,
      ),
      Map<String, dynamic>() when listContainer['results'] is List<dynamic> =>
        (listContainer['results'] as List<dynamic>)
            .whereType<Map<String, dynamic>>()
            .toList(growable: false),
      _ => const <Map<String, dynamic>>[],
    };

    final items = records
        .map(_mapSnapshotRecordToProfile)
        .toList(growable: false);
    final mainList = AuditMainList(
      count: _readInt(json, 'count') ?? items.length,
      next: _readString(json, 'next'),
      previous: _readString(json, 'previous'),
      current: _readInt(json, 'current') ?? _readInt(json, 'page') ?? 1,
      results: items,
    );

    return _PerformanceSnapshotParseResult(mainList: mainList, items: items);
  }

  AuditProfile _mapSnapshotRecordToProfile(Map<String, dynamic> json) {
    String firstStringFrom(
      List<Map<String, dynamic>> sources,
      List<String> keys, {
      String fallback = '',
    }) {
      for (final source in sources) {
        for (final key in keys) {
          final value = source[key];
          if (value is String && value.trim().isNotEmpty) {
            return value.trim();
          }
        }
      }
      return fallback;
    }

    num firstNumFrom(
      List<Map<String, dynamic>> sources,
      List<String> keys, {
      num fallback = 0,
    }) {
      for (final source in sources) {
        for (final key in keys) {
          final value = source[key];
          if (value is num) {
            return value;
          }
          if (value is String) {
            final parsed = num.tryParse(value);
            if (parsed != null) {
              return parsed;
            }
          }
        }
      }
      return fallback;
    }

    final profile = _readMap(json, 'profile');
    final job = _readMap(json, 'job');
    final sources = [json, profile, job];

    String firstString(List<String> keys, {String fallback = ''}) {
      return firstStringFrom(sources, keys, fallback: fallback);
    }

    num firstNum(List<String> keys, {num fallback = 0}) {
      return firstNumFrom(sources, keys, fallback: fallback);
    }

    final name = firstString([
      'name',
      'full_name',
      'employee_name',
      'team_member_name',
    ], fallback: 'No Profile Allocated');
    final roleTitle = firstString([
      'role_title',
      'job_title',
      'title',
      'seat_title',
    ], fallback: 'Performance Snapshot');
    final seatProfile = firstString([
      'seat_profile',
      'seat_profile_title',
      'seat_title',
      'title',
      'job_title',
      'role_title',
    ], fallback: roleTitle);
    final overallScore = firstNum([
      'overall_score',
      'overall_performance_score',
      'score',
    ]).toDouble();
    final confidenceLevel = firstNum([
      'confidence_level',
      'confidence_percent',
    ]).round();
    final profiles = _readProfiles(
      json['profiles'] ?? profile['profiles'] ?? profile['team_members'],
    );

    return AuditProfile(
      uuid: firstString(['uuid', 'id']),
      profileJob: firstString(['profile_job', 'profile_job_id']),
      profileUuid: firstStringFrom(
        [profile],
        ['uuid'],
        fallback: firstStringFrom(
          [json],
          ['profile_uuid', 'employee_uuid', 'user_uuid'],
        ),
      ),
      email: firstString(['email']),
      imageUrl:
          firstString(['image_url', 'avatar_url', 'photo', 'image']).isEmpty
          ? null
          : firstString(['image_url', 'avatar_url', 'photo', 'image']),
      isFavorite: false,
      lastAuditDates: const <String?>[],
      roleTitle: roleTitle,
      name: name,
      lastAuditLabel: firstString([
        'last_audit_label',
        'last_audit_date',
        'reporting_period',
      ], fallback: 'N/A'),
      yearQuarter: firstString(['year_quarter', 'quarter_label']),
      seatProfile: seatProfile,
      overallScore: overallScore,
      confidenceLevel: confidenceLevel,
      status: AuditMemberStatus.active,
      reviewerInitials: const <String>[],
      avatarLabel: name.isNotEmpty ? name.trim()[0].toUpperCase() : 'U',
      profiles: profiles,
      avatarImageUrl:
          firstString(['image_url', 'avatar_url', 'photo', 'image']).isEmpty
          ? null
          : firstString(['image_url', 'avatar_url', 'photo', 'image']),
    );
  }

  int? _readInt(dynamic json, String key) {
    if (json is! Map<String, dynamic>) {
      return null;
    }
    final value = json[key];
    if (value is int) {
      return value;
    }
    if (value is String) {
      return int.tryParse(value);
    }
    return null;
  }

  String? _readString(dynamic json, String key) {
    if (json is! Map<String, dynamic>) {
      return null;
    }
    final value = json[key];
    if (value is String && value.trim().isNotEmpty) {
      return value;
    }
    return null;
  }

  Map<String, dynamic> _readMap(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    return const <String, dynamic>{};
  }

  List<AuditMemberProfile> _readProfiles(dynamic value) {
    if (value is! List) {
      return const <AuditMemberProfile>[];
    }

    return value
        .whereType<Map<String, dynamic>>()
        .map(
          (item) => AuditMemberProfile(
            uuid: _readString(item, 'uuid') ?? '',
            name:
                _readString(item, 'name') ??
                _readString(item, 'full_name') ??
                '',
            email: _readString(item, 'email') ?? '',
            imageUrl:
                _readString(item, 'image') ??
                _readString(item, 'image_url') ??
                _readString(item, 'avatar_url') ??
                _readString(item, 'photo'),
            onboarded: _readBool(item['onboarded']) ?? true,
          ),
        )
        .where((item) => item.uuid.isNotEmpty || item.name.isNotEmpty)
        .toList(growable: false);
  }

  bool? _readBool(dynamic value) {
    if (value is bool) {
      return value;
    }
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      if (normalized == 'true') {
        return true;
      }
      if (normalized == 'false') {
        return false;
      }
    }
    return null;
  }

  @override
  void dispose() {
    _isDisposed = true;
    _searchDebounceTimer?.cancel();
    searchController.dispose();
    scrollController
      ..removeListener(_handleScroll)
      ..dispose();
    super.dispose();
  }

  void _scheduleSearchRefresh({bool immediate = false}) {
    _searchDebounceTimer?.cancel();

    if (immediate) {
      unawaited(_runDebouncedSearchRefresh());
      return;
    }

    _searchDebounceTimer = Timer(_searchDebounceDuration, () {
      unawaited(_runDebouncedSearchRefresh());
    });
  }

  Future<void> _runDebouncedSearchRefresh() async {
    if (_isInitializing || currentData.isLoading || currentData.isLoadingMore) {
      _hasPendingSearchRefresh = true;
      return;
    }

    _hasPendingSearchRefresh = false;
    await _refreshSearchResults(showLoader: true);
  }

  Future<void> _refreshSearchResults({
    required bool showLoader,
    bool forceRefresh = false,
  }) async {
    if (_selectedTab == PerformanceSnapshotTab.reports) {
      await loadReports(
        force: true,
        showLoader: showLoader,
        forceRefresh: forceRefresh,
      );
      return;
    }

    await loadMyReports(
      force: true,
      showLoader: showLoader,
      forceRefresh: forceRefresh,
    );
  }

  void _flushPendingSearchRefresh() {
    if (!_hasPendingSearchRefresh ||
        _isInitializing ||
        currentData.isLoading ||
        currentData.isLoadingMore) {
      return;
    }

    _hasPendingSearchRefresh = false;
    _scheduleSearchRefresh(immediate: true);
  }

  void _cancelPendingSearchRefresh() {
    _searchDebounceTimer?.cancel();
    _hasPendingSearchRefresh = false;
  }

  PagedAuditData? get _defaultDataForSelectedTab =>
      _selectedTab == PerformanceSnapshotTab.reports
      ? _defaultReportsData
      : _defaultMyReportsData;

  void _setDataForSelectedTab(PagedAuditData data) {
    if (_selectedTab == PerformanceSnapshotTab.reports) {
      _reportsData = data;
      return;
    }

    _myReportsData = data;
  }

  bool _currentDataMatchesSearch() {
    return currentData.query.trim() == _searchQuery.trim();
  }

  String _requestKeyFor({
    required PerformanceSnapshotTab tab,
    required String query,
  }) {
    return '${tab.name}|$query';
  }
}

class _PerformanceSnapshotParseResult {
  const _PerformanceSnapshotParseResult({
    required this.mainList,
    required this.items,
  });

  final AuditMainList mainList;
  final List<AuditProfile> items;
}

class PagedAuditData {
  const PagedAuditData({
    this.items = const <AuditProfile>[],
    this.currentPage = 0,
    this.hasNextPage = false,
    this.isLoading = false,
    this.isLoadingMore = false,
    this.query = '',
  });

  final List<AuditProfile> items;
  final int currentPage;
  final bool hasNextPage;
  final bool isLoading;
  final bool isLoadingMore;
  final String query;

  PagedAuditData copyWith({
    List<AuditProfile>? items,
    int? currentPage,
    bool? hasNextPage,
    bool? isLoading,
    bool? isLoadingMore,
    String? query,
  }) {
    return PagedAuditData(
      items: items ?? this.items,
      currentPage: currentPage ?? this.currentPage,
      hasNextPage: hasNextPage ?? this.hasNextPage,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      query: query ?? this.query,
    );
  }

  factory PagedAuditData.fromMainList(
    AuditMainList list, {
    required List<AuditProfile> items,
    String query = '',
  }) {
    return PagedAuditData(
      items: items,
      currentPage: list.current,
      hasNextPage: list.next != null,
      isLoading: false,
      isLoadingMore: false,
      query: query,
    );
  }
}
