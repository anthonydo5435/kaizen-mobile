import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/constants/app_strings.dart';
import '../../data/datasources/seat_profile_remote_data_source.dart';
import '../../data/repositories/seat_profile_repository_impl.dart';
import '../../domain/entities/department.dart';
import '../../domain/entities/seat_profile.dart';
import '../../domain/usecases/get_seat_profiles_usecase.dart';

enum SeatProfileFilter { all, primaryPaygrade, ancillaryPaygrade }

class SeatProfileController extends ChangeNotifier {
  SeatProfileController(this._getSeatProfilesUseCase);

  final GetSeatProfilesUseCase _getSeatProfilesUseCase;
  final TextEditingController searchController = TextEditingController();

  static const int _pageSize = 10;
  static const Duration _searchDebounceDuration = Duration(milliseconds: 400);

  bool _isInitialLoading = false;
  bool _isListLoading = false;
  bool _isRefreshing = false;
  bool _isLoadingMore = false;
  bool _hasNextPage = true;
  int _currentPage = 0;
  int _listRequestVersion = 0;
  String? _errorMessage;
  String _searchQuery = '';
  SeatProfileFilter _selectedFilter = SeatProfileFilter.all;
  String _selectedDepartmentId = 'all';
  List<Department> _departments = const <Department>[];
  List<SeatProfile> _items = const <SeatProfile>[];
  Timer? _searchDebounceTimer;
  bool _hasPendingSearchRefresh = false;

  bool get isInitialLoading => _isInitialLoading;
  bool get isListLoading => _isListLoading;
  bool get isRefreshing => _isRefreshing;
  bool get isLoadingMore => _isLoadingMore;
  String? get errorMessage => _errorMessage;
  SeatProfileFilter get selectedFilter => _selectedFilter;
  String get selectedDepartmentId => _selectedDepartmentId;
  List<Department> get departments =>
      List<Department>.unmodifiable(_departments);

  List<SeatProfile> get visibleItems {
    return _items
        .where((item) {
          return switch (_selectedFilter) {
            SeatProfileFilter.all => true,
            SeatProfileFilter.primaryPaygrade => item.hasPrimaryPaygrade,
            SeatProfileFilter.ancillaryPaygrade => item.hasAncillaryPaygrade,
          };
        })
        .toList(growable: false);
  }

  String get selectedFilterLabel {
    return switch (_selectedFilter) {
      SeatProfileFilter.all => AppStrings.seatProfileFilterAll,
      SeatProfileFilter.primaryPaygrade =>
        AppStrings.seatProfileFilterPrimaryPaygrade,
      SeatProfileFilter.ancillaryPaygrade =>
        AppStrings.seatProfileFilterAncillaryPaygrade,
    };
  }

  Future<void> initialize() async {
    if (_isInitialLoading) {
      return;
    }

    _isInitialLoading = true;
    _errorMessage = null;
    _selectedDepartmentId = 'all';
    _searchQuery = '';
    _departments = const <Department>[];
    searchController.clear();
    notifyListeners();

    try {
      await _loadDepartments();
      await _reloadSeatProfiles();
    } catch (error) {
      _errorMessage = error.toString();
    }

    _isInitialLoading = false;
    notifyListeners();
  }

  Future<void> refresh() {
    return _refreshSeatProfiles(showLoader: false, forceRefresh: true);
  }

  Future<void> loadNextPage() async {
    if (_isInitialLoading ||
        _isListLoading ||
        _isRefreshing ||
        _isLoadingMore ||
        !_hasNextPage) {
      return;
    }

    _isLoadingMore = true;
    notifyListeners();

    try {
      await _loadPage(_currentPage + 1);
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  Future<void> _loadDepartments() async {
    _departments = List<Department>.unmodifiable(
      await _getSeatProfilesUseCase.getDepartments(),
    );
  }

  Future<void> _refreshSeatProfiles({
    required bool showLoader,
    bool forceRefresh = false,
  }) async {
    if (_isInitialLoading || _isListLoading || _isRefreshing) {
      return;
    }

    if (showLoader) {
      _isListLoading = true;
    } else {
      _isRefreshing = true;
    }
    _errorMessage = null;
    notifyListeners();

    try {
      await _reloadSeatProfiles(forceRefresh: forceRefresh);
    } catch (error) {
      _errorMessage = error.toString();
    }

    if (showLoader) {
      _isListLoading = false;
    } else {
      _isRefreshing = false;
    }
    notifyListeners();
    _flushPendingSearchRefresh();
  }

  Future<void> _reloadSeatProfiles({bool forceRefresh = false}) async {
    // Retain the current cards until a successful replacement arrives.
    _listRequestVersion++;
    await _loadPage(1, replace: true, forceRefresh: forceRefresh);
  }

  Future<void> _loadPage(
    int page, {
    bool replace = false,
    bool forceRefresh = false,
  }) async {
    final requestVersion = _listRequestVersion;
    final response = await _getSeatProfilesUseCase(
      page: page,
      pageSize: _pageSize,
      departmentId: _selectedDepartmentId == 'all'
          ? null
          : _selectedDepartmentId,
      title: _searchQuery.trim(),
      forceRefresh: forceRefresh,
    );
    if (requestVersion != _listRequestVersion) {
      return;
    }
    _currentPage = page;
    _hasNextPage = response.hasNextPage && response.items.isNotEmpty;
    _items = replace
        ? List<SeatProfile>.unmodifiable(response.items)
        : List<SeatProfile>.unmodifiable(<SeatProfile>[
            ..._items,
            ...response.items,
          ]);
  }

  void updateSearchQuery(String value) {
    if (_searchQuery == value) {
      return;
    }

    _searchQuery = value;
    _scheduleSearchRefresh();
  }

  void selectFilter(SeatProfileFilter filter) {
    if (_selectedFilter == filter) {
      return;
    }

    _selectedFilter = filter;
    notifyListeners();
  }

  Future<void> selectDepartment(String departmentId) async {
    if (_selectedDepartmentId == departmentId) {
      return;
    }

    _selectedDepartmentId = departmentId;
    await _refreshSeatProfiles(showLoader: true);
  }

  @override
  void dispose() {
    _searchDebounceTimer?.cancel();
    searchController.dispose();
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
    if (_isInitialLoading || _isListLoading || _isRefreshing) {
      _hasPendingSearchRefresh = true;
      return;
    }

    _hasPendingSearchRefresh = false;
    await _refreshSeatProfiles(showLoader: true);
  }

  void _flushPendingSearchRefresh() {
    if (!_hasPendingSearchRefresh ||
        _isInitialLoading ||
        _isListLoading ||
        _isRefreshing) {
      return;
    }

    _hasPendingSearchRefresh = false;
    _scheduleSearchRefresh(immediate: true);
  }
}

SeatProfileRepositoryImpl createSeatProfileRepository(
  SeatProfileRemoteDataSource remoteDataSource,
) {
  return SeatProfileRepositoryImpl(remoteDataSource);
}

GetSeatProfilesUseCase createGetSeatProfilesUseCase(
  SeatProfileRepositoryImpl repository,
) {
  return GetSeatProfilesUseCase(repository);
}
