import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/managers/app_manager.dart';
import '../../../seat_profile/domain/entities/department.dart';
import '../../data/datasources/paygrade_remote_data_source.dart';
import '../../data/repositories/paygrade_repository_impl.dart';
import '../../domain/entities/paygrade.dart';
import '../../domain/usecases/get_paygrades_usecase.dart';

class PaygradesController extends ChangeNotifier {
  PaygradesController(this._getPaygradesUseCase);

  final GetPaygradesUseCase _getPaygradesUseCase;
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
  bool _hasGlobalDepartmentAccess = true;
  String? _errorMessage;
  String _searchQuery = '';
  String _selectedDepartmentId = 'all';
  List<Department> _departments = const <Department>[];
  List<Paygrade> _items = const <Paygrade>[];
  Timer? _searchDebounceTimer;
  bool _hasPendingSearchRefresh = false;
  bool _hasPendingDepartmentRefresh = false;

  bool get isInitialLoading => _isInitialLoading;
  bool get isListLoading => _isListLoading;
  bool get isRefreshing => _isRefreshing;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasGlobalDepartmentAccess => _hasGlobalDepartmentAccess;
  String? get errorMessage => _errorMessage;
  String get selectedDepartmentId => _selectedDepartmentId;
  List<Department> get departments =>
      List<Department>.unmodifiable(_departments);
  List<Paygrade> get items => List<Paygrade>.unmodifiable(_items);

  Future<void> initialize() async {
    if (_isInitialLoading) {
      return;
    }

    _isInitialLoading = true;
    _errorMessage = null;
    _hasGlobalDepartmentAccess = true;
    _selectedDepartmentId = 'all';
    _searchQuery = '';
    _departments = const <Department>[];
    _items = const <Paygrade>[];
    searchController.clear();
    notifyListeners();

    try {
      _hasGlobalDepartmentAccess =
          AppManager.instance.currentUserHasOwnerOverrideAccess ||
          AppManager.instance.currentUserCanManagePaygrades;
      await _loadDepartments();
      if (!_hasGlobalDepartmentAccess && _departments.isNotEmpty) {
        _selectedDepartmentId = _departments.first.id;
      }
      await _reloadPaygrades();
    } catch (error) {
      _errorMessage = error.toString();
    }

    _isInitialLoading = false;
    notifyListeners();
  }

  Future<void> refresh() {
    return _refreshPaygrades(showLoader: false, forceRefresh: true);
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
      _flushPendingRefreshes();
    }
  }

  Future<void> _loadDepartments() async {
    _departments = List<Department>.unmodifiable(
      await _getPaygradesUseCase.getDepartments(
        isOwner: _hasGlobalDepartmentAccess,
      ),
    );
  }

  Future<void> _refreshPaygrades({
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
      await _reloadPaygrades(forceRefresh: forceRefresh);
    } catch (error) {
      _errorMessage = error.toString();
    }

    if (showLoader) {
      _isListLoading = false;
    } else {
      _isRefreshing = false;
    }
    notifyListeners();
    _flushPendingRefreshes();
  }

  Future<void> _reloadPaygrades({bool forceRefresh = false}) async {
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
    final response = await _getPaygradesUseCase(
      page: page,
      pageSize: _pageSize,
      departmentId: _selectedDepartmentId == 'all'
          ? null
          : _selectedDepartmentId,
      title: _searchQuery.trim().isEmpty ? null : _searchQuery.trim(),
      forceRefresh: forceRefresh,
    );
    if (requestVersion != _listRequestVersion) {
      return;
    }
    _currentPage = page;
    _hasNextPage = response.hasNextPage && response.items.isNotEmpty;
    _items = replace
        ? List<Paygrade>.unmodifiable(response.items)
        : List<Paygrade>.unmodifiable(<Paygrade>[..._items, ...response.items]);
  }

  void updateSearchQuery(String value) {
    if (_searchQuery == value) {
      return;
    }

    _searchQuery = value;
    _scheduleSearchRefresh();
  }

  Future<void> selectDepartment(String departmentId) async {
    if (_selectedDepartmentId == departmentId) {
      return;
    }

    _selectedDepartmentId = departmentId;
    notifyListeners();

    if (_isInitialLoading ||
        _isListLoading ||
        _isRefreshing ||
        _isLoadingMore) {
      _hasPendingDepartmentRefresh = true;
      return;
    }

    await _refreshPaygrades(showLoader: true);
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
    await _refreshPaygrades(showLoader: true);
  }

  void _flushPendingRefreshes() {
    if (_hasPendingDepartmentRefresh &&
        !_isInitialLoading &&
        !_isListLoading &&
        !_isRefreshing &&
        !_isLoadingMore) {
      _hasPendingDepartmentRefresh = false;
      unawaited(_refreshPaygrades(showLoader: true));
      return;
    }

    if (!_hasPendingSearchRefresh ||
        _isInitialLoading ||
        _isListLoading ||
        _isRefreshing ||
        _isLoadingMore) {
      return;
    }

    _hasPendingSearchRefresh = false;
    _scheduleSearchRefresh(immediate: true);
  }
}

PaygradeRepositoryImpl createPaygradeRepository(
  PaygradeRemoteDataSource remoteDataSource,
) {
  return PaygradeRepositoryImpl(remoteDataSource);
}

GetPaygradesUseCase createGetPaygradesUseCase(
  PaygradeRepositoryImpl repository,
) {
  return GetPaygradesUseCase(repository);
}
