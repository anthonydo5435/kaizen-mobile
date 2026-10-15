import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;

import '../../../../core/constants/app_strings.dart';
import '../../../../core/utils/custom_functions.dart';
import '../../../check_in/domain/repositories/audit_repository.dart';
import '../../../seat_profile/domain/entities/seat_profile_detail.dart';
import '../../../seat_profile/domain/usecases/get_seat_profiles_usecase.dart';
import '../../data/repositories/training_library_repository_impl.dart';
import '../../domain/entities/seat_description_training_route.dart';
import '../../domain/entities/training_library_module.dart';
import '../../domain/usecases/get_training_library_modules_usecase.dart';
import '../models/training_library_filter_tag.dart';
import 'training_library_detail_controller.dart';
import 'training_library_thumbnail_controller.dart';

enum TrainingLibraryViewMode { grid, list }

enum TrainingLibrarySearchFilter { category, department, seat }

enum _LibrarySelectionField { department, seat, filterTag }

extension TrainingLibrarySearchFilterValue on TrainingLibrarySearchFilter {
  String get apiValue => name;
}

class TrainingLibraryController extends ChangeNotifier {
  TrainingLibraryController(
    this._getTrainingLibraryModulesUseCase, {
    required GetSeatProfilesUseCase getSeatProfilesUseCase,
    bool Function()? canCreateTraining,
    AuditRepository? auditRepository,
    bool Function(String seatProfileId)? canManageSeatTraining,
    ValueChanged<bool>? onNavigationBarsVisibilityChanged,
  }) : _getSeatProfilesUseCase = getSeatProfilesUseCase,
       _canCreateTraining = canCreateTraining,
       _auditRepository = auditRepository,
       _onNavigationBarsVisibilityChanged = onNavigationBarsVisibilityChanged,
       _canManageSeatTraining = canManageSeatTraining {
    scrollController.addListener(_handleScroll);
  }

  final GetTrainingLibraryModulesUseCase _getTrainingLibraryModulesUseCase;
  final GetSeatProfilesUseCase _getSeatProfilesUseCase;
  final bool Function()? _canCreateTraining;
  final AuditRepository? _auditRepository;
  final bool Function(String seatProfileId)? _canManageSeatTraining;
  final ValueChanged<bool>? _onNavigationBarsVisibilityChanged;
  bool _navigationBarsVisible = true;
  double _previousScrollOffset = 0;
  double _scrollTravel = 0;
  static const double _navigationScrollThreshold = 12;

  bool get navigationBarsVisible => _navigationBarsVisible;
  bool _isShowingModuleActions = false;
  final ScrollController scrollController = ScrollController();
  bool _isDisposed = false;
  static const int _pageSize = 25;
  static const int _prefetchRemainingItems = 9;
  final TrainingLibraryThumbnailController thumbnailCache =
      TrainingLibraryThumbnailController();
  int _listingVersion = 0;
  String? _loadMoreErrorMessage;
  static const Duration _searchDebounceDuration = Duration(milliseconds: 400);

  bool _isInitialLoading = false;
  bool _isRefreshing = false;
  bool _isPreservingListDuringRefresh = false;
  bool _isViewSyncing = false;
  bool _isLoadingMore = false;
  bool _hasNextPage = true;
  int _currentPage = 0;
  String? _errorMessage;
  String _selectedDepartmentId = 'all';
  TrainingLibraryViewMode _viewMode = TrainingLibraryViewMode.list;
  TrainingLibrarySearchFilter _searchFilter = TrainingLibrarySearchFilter.seat;
  String _searchQuery = '';
  TrainingLibrarySeat? _selectedSeat;
  String? get _selectedSeatId => _selectedSeat?.id;
  SeatProfileCategory? _selectedCategory;
  SeatProfileDescription? _selectedDescription;
  TrainingLibrarySeat? _pendingSeatSelection;
  SeatProfileCategory? _pendingCategorySelection;
  SeatProfileDescription? _pendingDescriptionSelection;
  List<SeatProfileDetail> _seatProfiles = const [];
  bool _isLoadingSeatOptions = false;
  String? _seatOptionsError;
  int _seatRequestId = 0;
  List<TrainingLibraryDepartment> _departments =
      const <TrainingLibraryDepartment>[];
  String _departmentSearchQuery = '';
  List<TrainingLibraryModule> _items = const <TrainingLibraryModule>[];
  Timer? _searchDebounceTimer;
  bool _hasPendingSearchRefresh = false;
  _LibrarySelectionField? _applyingSelectionField;
  String? _applyingSelectionId;
  List<TrainingLibraryModule>? _itemsBeforeSelection;
  List<TrainingLibraryModule>? _itemsDuringPositionPreservingRefresh;
  String? _selectionErrorMessage;

  bool get canCreateTraining => _canCreateTraining?.call() ?? false;
  bool get hasSearchQuery => _hasActiveSearch;
  List<TrainingLibraryDepartment> get departmentTabs => [
    const TrainingLibraryDepartment(
      id: 'all',
      name: AppStrings.trainingLibraryAllFilter,
    ),
    ..._departments.take(3),
  ];

  static String displayModuleTitle(TrainingLibraryModule module) {
    final title = module.title.trim();
    return title.isEmpty ? AppStrings.trainingLibraryUntitledModule : title;
  }

  static String displayModuleValue(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? AppStrings.trainingLibraryNotAvailable : trimmed;
  }

  static String displayModuleLessonCount(TrainingLibraryModule module) =>
      AppStrings.trainingLibraryVideosCount(module.lessonsCount);

  static String displayModuleDuration(TrainingLibraryModule module) =>
      displayDuration(module.totalDuration);

  static String displayDuration(int seconds) {
    final duration = CustomFunctions.formatDuration(seconds);
    return seconds < 3600
        ? AppStrings.trainingLibraryMinutesDuration(duration)
        : duration;
  }

  Future<void> openLesson(
    TrainingLibraryModule module, {
    required Future<void> Function(SeatDescriptionTrainingRoute route)
    openDetails,
  }) async {
    final lessonId = module.id.trim();
    final descriptionId = module.trainingDescriptionId.trim();
    if (_isDisposed ||
        !module.isLessonListing ||
        lessonId.isEmpty ||
        descriptionId.isEmpty) {
      return;
    }
    final canManageTraining =
        _canManageSeatTraining?.call(module.seat.id) ?? false;
    await openDetails(
      SeatDescriptionTrainingRoute(
        job: module.seat.id,
        category: module.category.id,
        description: descriptionId,
        initialModuleId: lessonId,
      ),
    );
    if (!_isDisposed && canManageTraining) {
      await refresh(preservePosition: true);
    }
  }

  bool canShowModuleActions(TrainingLibraryModule module) =>
      !_isDisposed &&
      _auditRepository != null &&
      module.isLessonListing &&
      module.id.trim().isNotEmpty &&
      module.lessons.length == 1 &&
      module.lessons.single.id == module.id &&
      (_canManageSeatTraining?.call(module.seat.id) ?? false);

  Future<void> openModuleActions(
    TrainingLibraryModule module, {
    required Future<void> Function(
      TrainingLibraryDetailController controller,
      TrainingLibraryLesson lesson,
    )
    showActions,
  }) async {
    if (_isShowingModuleActions || !canShowModuleActions(module)) {
      return;
    }
    _isShowingModuleActions = true;
    final actionsController = TrainingLibraryDetailController(
      initialModule: module,
      getTrainingLibraryModules: _getTrainingLibraryModulesUseCase,
      auditRepository: _auditRepository!,
      canManageSeatTraining: (seatId) =>
          !_isDisposed && (_canManageSeatTraining?.call(seatId) ?? false),
      view: _viewMode.name,
    );
    var didChange = false;
    try {
      await showActions(actionsController, module.lessons.single);
      didChange = actionsController.navigationResult == true;
    } finally {
      actionsController.dispose();
      _isShowingModuleActions = false;
    }
    if (!_isDisposed && didChange) {
      await refresh();
    }
  }

  void openCreateFlow({required VoidCallback onOpen}) {
    if (canCreateTraining) {
      onOpen();
    }
  }

  void _handleScroll() {
    if (!scrollController.hasClients) {
      return;
    }
    _updateNavigationBarsForScroll();
  }

  void preloadThumbnails(List<TrainingLibraryModule> modules) {
    if (_isDisposed) return;
    thumbnailCache.preload(
      modules
          .map(
            (module) => CustomFunctions.resolveImageUrl(module.thumbnailLink),
          )
          .whereType<String>(),
    );
  }

  void onItemVisible(String moduleId) {
    if (_isDisposed || _loadMoreErrorMessage != null) return;
    final visible = visibleItems;
    final index = visible.indexWhere((module) => module.id == moduleId);
    if (index >= 0 && visible.length - index - 1 <= _prefetchRemainingItems) {
      unawaited(loadNextPage());
    }
  }

  void _updateNavigationBarsForScroll() {
    final position = scrollController.position;
    final offset = position.pixels;
    final delta = offset - _previousScrollOffset;
    _previousScrollOffset = offset;

    if (offset <= position.minScrollExtent ||
        position.maxScrollExtent <= position.minScrollExtent) {
      _scrollTravel = 0;
      _setNavigationBarsVisible(true);
      return;
    }
    // Ignore programmatic jumps, layout corrections, and overscroll rebound.
    final direction = position.userScrollDirection;
    if (position.outOfRange ||
        direction == ScrollDirection.idle ||
        (direction == ScrollDirection.reverse && delta < 0) ||
        (direction == ScrollDirection.forward && delta > 0)) {
      _scrollTravel = 0;
      return;
    }
    if (delta == 0) {
      return;
    }
    _scrollTravel = _scrollTravel.sign == delta.sign
        ? _scrollTravel + delta
        : delta;
    if (_scrollTravel.abs() >= _navigationScrollThreshold) {
      _setNavigationBarsVisible(delta < 0);
      _scrollTravel = 0;
    }
  }

  void _setNavigationBarsVisible(bool visible) {
    if (_navigationBarsVisible == visible) {
      return;
    }
    _navigationBarsVisible = visible;
    _onNavigationBarsVisibilityChanged?.call(visible);
    notifyListeners();
  }

  bool get isInitialLoading => _isInitialLoading;
  bool get isRefreshing => _isRefreshing;
  bool get isViewSyncing => _isViewSyncing;
  bool get isLoadingMore => _isLoadingMore;
  String? get loadMoreErrorMessage => _loadMoreErrorMessage;
  bool get isInlineLoading =>
      _applyingSelectionField == _LibrarySelectionField.filterTag ||
      (!isApplyingSelection &&
          ((_isRefreshing && !_isPreservingListDuringRefresh) ||
              _isViewSyncing));
  bool get isApplyingSelection => _applyingSelectionField != null;
  bool get canApplySelection =>
      !isApplyingSelection &&
      !_isInitialLoading &&
      !_isRefreshing &&
      !_isViewSyncing &&
      !_isLoadingMore;
  String? get selectionErrorMessage => _selectionErrorMessage;

  bool isApplyingSeatSelection(String? seatId) =>
      _applyingSelectionField == _LibrarySelectionField.seat &&
      _applyingSelectionId == seatId;

  bool isApplyingDepartmentSelection(String departmentId) =>
      _applyingSelectionField == _LibrarySelectionField.department &&
      _applyingSelectionId == departmentId;

  void clearSelectionError() {
    _selectionErrorMessage = null;
  }

  Future<bool> applySeatSelection(TrainingLibrarySeat? seat) => _applySelection(
    field: _LibrarySelectionField.seat,
    id: seat?.id,
    apply: () => selectSeat(seat),
  );

  Future<bool> applyDepartmentSelection(String departmentId) => _applySelection(
    field: _LibrarySelectionField.department,
    id: departmentId,
    apply: () => selectDepartment(departmentId),
  );

  Future<bool> _applySelection({
    required _LibrarySelectionField field,
    required String? id,
    required Future<bool> Function() apply,
  }) async {
    if (!canApplySelection) {
      return false;
    }
    final previous = (
      departmentId: _selectedDepartmentId,
      seat: _selectedSeat,
      category: _selectedCategory,
      description: _selectedDescription,
      searchQuery: _searchQuery,
      searchFilter: _searchFilter,
      items: _items,
      departments: _departments,
      page: _currentPage,
      hasNextPage: _hasNextPage,
      errorMessage: _errorMessage,
    );
    _itemsBeforeSelection = visibleItems;
    _applyingSelectionField = field;
    _applyingSelectionId = id;
    _selectionErrorMessage = null;
    _searchDebounceTimer?.cancel();
    _hasPendingSearchRefresh = false;
    notifyListeners();
    try {
      final succeeded = await apply();
      if (!succeeded) {
        _selectedDepartmentId = previous.departmentId;
        _selectedSeat = previous.seat;
        _selectedCategory = previous.category;
        _selectedDescription = previous.description;
        _searchQuery = previous.searchQuery;
        _searchFilter = previous.searchFilter;
        _items = previous.items;
        _departments = previous.departments;
        _currentPage = previous.page;
        _hasNextPage = previous.hasNextPage;
        _errorMessage = previous.errorMessage;
        _selectionErrorMessage = AppStrings.trainingLibraryUnableToApplyFilter;
      }
      return succeeded;
    } finally {
      _applyingSelectionField = null;
      _applyingSelectionId = null;
      _itemsBeforeSelection = null;
      notifyListeners();
      _flushPendingSearchRefresh();
    }
  }

  bool get isShowingFullscreenLoading => _isInitialLoading && _items.isEmpty;
  String? get errorMessage => _errorMessage;
  String get selectedDepartmentId => _selectedDepartmentId;
  TrainingLibraryViewMode get viewMode => _viewMode;
  TrainingLibrarySearchFilter get searchFilter => _searchFilter;
  String get searchQuery => _searchQuery;
  String? get selectedSeatId => _selectedSeatId;
  String? get selectedCategoryId => _selectedCategory?.id;
  String? get selectedDescriptionId => _selectedDescription?.id;
  List<TrainingLibraryFilterTag> get appliedFilterTags => [
    if (_selectedSeat != null)
      (type: TrainingLibraryFilter.seat, label: _selectedSeat!.title),
    if (_selectedCategory != null)
      (type: TrainingLibraryFilter.category, label: _selectedCategory!.title),
    if (_selectedDescription != null)
      (
        type: TrainingLibraryFilter.description,
        label: _selectedDescription!.name,
      ),
  ];
  String? get pendingSeatSelectionId => _pendingSeatSelection?.id;
  TrainingLibrarySeat? get pendingSeatSelection => _pendingSeatSelection;
  SeatProfileCategory? get pendingCategorySelection =>
      _pendingCategorySelection;
  SeatProfileDescription? get pendingDescriptionSelection =>
      _pendingDescriptionSelection;

  List<TrainingLibrarySeat> get seatOptions => List.unmodifiable(
    _seatProfiles.map(
      (profile) => TrainingLibrarySeat(id: profile.id, title: profile.title),
    ),
  );
  List<SeatProfileCategory> get categoryOptions {
    for (final profile in _seatProfiles) {
      if (profile.id == pendingSeatSelectionId) {
        return profile.categories;
      }
    }
    return const [];
  }

  List<SeatProfileDescription> get descriptionOptions =>
      _pendingCategorySelection?.descriptions ?? const [];
  bool get isLoadingSeatOptions => _isLoadingSeatOptions;
  String? get seatOptionsError => _seatOptionsError;

  List<TrainingLibraryDepartment> get departments =>
      List<TrainingLibraryDepartment>.unmodifiable(_departments);
  List<TrainingLibraryDepartment> get departmentOptions {
    final query = _departmentSearchQuery.trim().toLowerCase();
    return List<TrainingLibraryDepartment>.unmodifiable(
      _departments.where(
        (department) => department.name.toLowerCase().contains(query),
      ),
    );
  }

  void updateDepartmentSearchQuery(String query) {
    if (_departmentSearchQuery == query) {
      return;
    }
    _departmentSearchQuery = query;
    notifyListeners();
  }

  List<TrainingLibraryModule> get items =>
      List<TrainingLibraryModule>.unmodifiable(_items);
  bool get _hasActiveSearch => _searchQuery.trim().isNotEmpty;
  bool get _hasActiveDepartmentFilter => _selectedDepartmentId != 'all';

  List<TrainingLibraryModule> get visibleItems {
    if (_itemsBeforeSelection != null) {
      return _itemsBeforeSelection!;
    }
    if (_itemsDuringPositionPreservingRefresh != null) {
      return _itemsDuringPositionPreservingRefresh!;
    }
    return List.unmodifiable(_filteredItems);
  }

  Iterable<TrainingLibraryModule> get _filteredItems => _items.where(
    (item) =>
        (!_hasActiveDepartmentFilter ||
            item.department.id == _selectedDepartmentId) &&
        (_selectedSeatId == null || item.seat.id == _selectedSeatId) &&
        (_selectedCategory == null ||
            item.category.id == _selectedCategory!.id) &&
        (_selectedDescription == null ||
            item.trainingDescriptionId == _selectedDescription!.id),
  );

  Future<void> openSeatSelection() {
    _pendingSeatSelection = _selectedSeat;
    _pendingCategorySelection = _selectedCategory;
    _pendingDescriptionSelection = _selectedDescription;
    return loadSeatOptions();
  }

  void updatePendingSeatSelection(TrainingLibrarySeat? seat) {
    if (isApplyingSelection) {
      return;
    }

    if (seat?.id != _pendingSeatSelection?.id) {
      _pendingCategorySelection = null;
      _pendingDescriptionSelection = null;
    }
    _pendingSeatSelection = seat;
    _selectionErrorMessage = null;
    notifyListeners();
  }

  void updatePendingCategorySelection(SeatProfileCategory? category) {
    if (isApplyingSelection ||
        (category != null && !categoryOptions.contains(category))) {
      return;
    }
    if (category?.id != _pendingCategorySelection?.id) {
      _pendingDescriptionSelection = null;
    }
    _pendingCategorySelection = category;
    _selectionErrorMessage = null;
    notifyListeners();
  }

  void updatePendingDescriptionSelection(SeatProfileDescription? description) {
    if (isApplyingSelection ||
        (description != null && !descriptionOptions.contains(description))) {
      return;
    }
    _pendingDescriptionSelection = description;
    _selectionErrorMessage = null;
    notifyListeners();
  }

  Future<bool> applyPendingSeatSelection() => _applySelection(
    field: _LibrarySelectionField.seat,
    id: pendingSeatSelectionId,
    apply: () => _selectSeatFilter(
      _pendingSeatSelection,
      category: _pendingCategorySelection,
      description: _pendingDescriptionSelection,
    ),
  );

  Future<bool> removeFilter(TrainingLibraryFilter filter) => _applySelection(
    field: _LibrarySelectionField.filterTag,
    id: _selectedSeatId,
    apply: () => _selectSeatFilter(
      filter == TrainingLibraryFilter.seat ? null : _selectedSeat,
      category: filter == TrainingLibraryFilter.description
          ? _selectedCategory
          : null,
    ),
  );

  void closeSeatSelection() {
    _seatRequestId++;
    _isLoadingSeatOptions = false;
    _pendingSeatSelection = null;
    _pendingCategorySelection = null;
    _pendingDescriptionSelection = null;
  }

  Future<void> loadSeatOptions() async {
    final requestId = ++_seatRequestId;
    _isLoadingSeatOptions = true;
    _seatOptionsError = null;
    _seatProfiles = const [];
    notifyListeners();

    try {
      final profiles = await _getSeatProfilesUseCase
          .seatProfileCategoryTrainings();
      if (requestId != _seatRequestId) {
        return;
      }

      final seats = <String, SeatProfileDetail>{};
      for (final profile in profiles) {
        final id = profile.id.trim();
        final title = profile.title.trim();
        if (id.isNotEmpty &&
            title.isNotEmpty &&
            (!_hasActiveDepartmentFilter ||
                profile.department?.id == _selectedDepartmentId)) {
          seats[id] = profile;
        }
      }
      _seatProfiles = List.unmodifiable(seats.values);
      // Reconcile reopened drafts against the latest hierarchy.
      _pendingCategorySelection = categoryOptions
          .where((category) => category.id == _pendingCategorySelection?.id)
          .firstOrNull;
      _pendingDescriptionSelection = descriptionOptions
          .where(
            (description) => description.id == _pendingDescriptionSelection?.id,
          )
          .firstOrNull;
    } catch (_) {
      if (requestId == _seatRequestId) {
        _seatOptionsError = AppStrings.trainingLibraryUnableToLoadSeats;
      }
    } finally {
      if (requestId == _seatRequestId) {
        _isLoadingSeatOptions = false;
        notifyListeners();
      }
    }
  }

  Future<bool> selectSeat(TrainingLibrarySeat? seat) => _selectSeatFilter(seat);

  Future<bool> _selectSeatFilter(
    TrainingLibrarySeat? seat, {
    SeatProfileCategory? category,
    SeatProfileDescription? description,
  }) async {
    _searchDebounceTimer?.cancel();
    _selectedSeat = seat;
    _selectedCategory = category;
    _selectedDescription = description;
    _searchFilter = TrainingLibrarySearchFilter.seat;
    _errorMessage = null;
    notifyListeners();
    return _reloadModulesForActiveFilters();
  }

  Future<void> initialize() async {
    if (_isInitialLoading) {
      return;
    }

    _isInitialLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _reloadModules();
    } catch (error) {
      _errorMessage = error.toString();
    }

    _isInitialLoading = false;
    notifyListeners();
  }

  Future<void> refresh({bool preservePosition = false}) async {
    if (_isDisposed || _isInitialLoading || _isRefreshing) {
      return;
    }

    final loadedPages = _currentPage;
    _isPreservingListDuringRefresh = preservePosition;
    final previousItems = _items;
    final previousDepartments = _departments;
    final previousHasNextPage = _hasNextPage;
    if (_isPreservingListDuringRefresh) {
      _itemsDuringPositionPreservingRefresh = visibleItems;
    }
    _isRefreshing = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _reloadModules(
        keepExistingItems: _isPreservingListDuringRefresh,
        minimumPageCount: _isPreservingListDuringRefresh ? loadedPages : 1,
        forceRefresh: true,
      );
    } catch (error) {
      if (_isDisposed) return;
      _errorMessage = error.toString();
      if (_isPreservingListDuringRefresh) {
        _items = previousItems;
        _departments = previousDepartments;
        _currentPage = loadedPages;
        _hasNextPage = previousHasNextPage;
      }
    }

    if (_isDisposed) return;
    _isRefreshing = false;
    _isPreservingListDuringRefresh = false;
    _itemsDuringPositionPreservingRefresh = null;
    notifyListeners();
    _flushPendingSearchRefresh();
  }

  Future<void> changeViewMode(TrainingLibraryViewMode mode) async {
    if (_viewMode == mode || _isViewSyncing) {
      return;
    }

    _viewMode = mode;
    _isViewSyncing = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _reloadModules();
    } catch (error) {
      _errorMessage = error.toString();
    }

    _isViewSyncing = false;
    notifyListeners();
    _flushPendingSearchRefresh();
  }

  Future<bool> selectDepartment(String departmentId) async {
    if (_selectedDepartmentId == departmentId) {
      return true;
    }

    _searchDebounceTimer?.cancel();
    _selectedDepartmentId = departmentId;
    if (_selectedSeatId != null) {
      _selectedSeat = null;
      _selectedCategory = null;
      _selectedDescription = null;
      _searchQuery = '';
    }
    _errorMessage = null;
    notifyListeners();
    return _reloadModulesForActiveFilters();
  }

  Future<void> selectSearchFilter(TrainingLibrarySearchFilter filter) async {
    if (_searchFilter == filter) {
      return;
    }

    _searchDebounceTimer?.cancel();
    _searchFilter = filter;
    if (_searchQuery.trim().isEmpty) {
      notifyListeners();
      return;
    }

    notifyListeners();
    await _reloadModulesForActiveFilters();
  }

  void updateSearchQuery(String value) {
    if (_searchQuery == value) {
      return;
    }

    _searchQuery = value;
    _errorMessage = null;
    notifyListeners();
    _scheduleSearchRefresh();
  }

  Future<void> clearSearch() async {
    if (!_hasActiveSearch) {
      return;
    }

    _searchDebounceTimer?.cancel();
    _searchQuery = '';
    _errorMessage = null;
    notifyListeners();
    await _reloadModulesForActiveFilters();
  }

  Future<void> loadNextPage() async {
    if (_isDisposed ||
        _isInitialLoading ||
        _isRefreshing ||
        _isViewSyncing ||
        _isLoadingMore ||
        !_hasNextPage) {
      return;
    }

    _isLoadingMore = true;
    _loadMoreErrorMessage = null;
    final version = _listingVersion;
    notifyListeners();

    try {
      await _loadPage(_currentPage + 1);
    } catch (_) {
      if (!_isDisposed && version == _listingVersion) {
        _loadMoreErrorMessage = AppStrings.trainingLibraryUnableToLoadMore;
      }
    } finally {
      if (!_isDisposed && version == _listingVersion) {
        _isLoadingMore = false;
        notifyListeners();
        _flushPendingSearchRefresh();
      }
    }
  }

  Future<void> _reloadModules({
    bool keepExistingItems = false,
    int minimumPageCount = 1,
    bool forceRefresh = false,
  }) async {
    _listingVersion++;
    _isLoadingMore = false;
    _loadMoreErrorMessage = null;
    if (!keepExistingItems) {
      _scrollTravel = 0;
      _setNavigationBarsVisible(true);
    }
    _currentPage = 0;
    _hasNextPage = true;
    if (!isApplyingSelection && !keepExistingItems) {
      _items = const <TrainingLibraryModule>[];
    }
    // Keep department choices visible until the replacement page arrives.
    await _loadPage(1, replace: true, forceRefresh: forceRefresh);
    while (_currentPage < minimumPageCount && _hasNextPage && !_isDisposed) {
      await _loadPage(_currentPage + 1, forceRefresh: forceRefresh);
    }
    await _loadUntilFiltersHaveVisibleItems(forceRefresh: forceRefresh);
  }

  Future<void> _loadPage(
    int page, {
    bool replace = false,
    bool forceRefresh = false,
  }) async {
    final version = _listingVersion;
    final response = await _getTrainingLibraryModulesUseCase(
      view: _viewMode.name,
      page: page,
      pageSize: _pageSize,
      searchType: _searchFilter.apiValue,
      searchText: _searchQuery.trim(),
      departmentId: _hasActiveDepartmentFilter ? _selectedDepartmentId : null,
      jobId: _selectedSeatId,
      jobCategoryId: _selectedCategory?.id,
      jobCategoryDescriptionId: _selectedDescription?.id,
      forceRefresh: forceRefresh,
    );

    if (_isDisposed || version != _listingVersion) return;

    final seenIds = replace
        ? <String>{}
        : _items.map((item) => item.id).toSet();
    final newItems = response.items
        .where((item) => seenIds.add(item.id))
        .toList(growable: false);
    final nextItems = replace
        ? newItems
        : <TrainingLibraryModule>[..._items, ...newItems];
    _currentPage = page;
    // Stop if the endpoint repeats a page while searching for an exact match.
    _hasNextPage = response.hasNextPage && newItems.isNotEmpty;
    _items = List<TrainingLibraryModule>.unmodifiable(nextItems);
    _departments = List<TrainingLibraryDepartment>.unmodifiable(
      _resolveVisibleDepartments(_items),
    );
    _syncSelectedDepartment();
  }

  Future<void> _loadUntilFiltersHaveVisibleItems({
    bool forceRefresh = false,
  }) async {
    while ((_hasActiveDepartmentFilter || _selectedSeatId != null) &&
        _filteredItems.isEmpty &&
        _hasNextPage &&
        !_isDisposed) {
      await _loadPage(_currentPage + 1, forceRefresh: forceRefresh);
    }
  }

  List<TrainingLibraryDepartment> _resolveDepartments(
    List<TrainingLibraryModule> modules,
  ) {
    final seenDepartmentIds = <String>{};
    final departments = <TrainingLibraryDepartment>[];

    for (final module in modules) {
      final departmentId = module.department.id.trim();
      final departmentName = module.department.name.trim();
      if (departmentId.isEmpty || departmentName.isEmpty) {
        continue;
      }

      if (seenDepartmentIds.add(departmentId)) {
        departments.add(module.department);
      }
    }

    return departments;
  }

  List<TrainingLibraryDepartment> _resolveVisibleDepartments(
    List<TrainingLibraryModule> modules,
  ) {
    final resolvedDepartments = _resolveDepartments(modules);
    if (!_hasActiveSearch && !_hasActiveDepartmentFilter) {
      return resolvedDepartments;
    }

    return _mergeDepartments(_departments, resolvedDepartments);
  }

  Future<bool> _reloadModulesForActiveFilters() async {
    if (_isInitialLoading ||
        _isRefreshing ||
        _isViewSyncing ||
        _isLoadingMore) {
      _hasPendingSearchRefresh = true;
      return false;
    }

    _isRefreshing = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _reloadModules();
    } catch (error) {
      _errorMessage = error.toString();
    }

    _isRefreshing = false;
    notifyListeners();
    _flushPendingSearchRefresh();
    return _errorMessage == null;
  }

  List<TrainingLibraryDepartment> _mergeDepartments(
    List<TrainingLibraryDepartment> existingDepartments,
    List<TrainingLibraryDepartment> nextDepartments,
  ) {
    final mergedDepartments = <TrainingLibraryDepartment>[];
    final seenDepartmentIds = <String>{};

    for (final department in <TrainingLibraryDepartment>[
      ...existingDepartments,
      ...nextDepartments,
    ]) {
      final departmentId = department.id.trim();
      final departmentName = department.name.trim();
      if (departmentId.isEmpty || departmentName.isEmpty) {
        continue;
      }

      if (seenDepartmentIds.add(departmentId)) {
        mergedDepartments.add(department);
      }
    }

    return mergedDepartments;
  }

  void _syncSelectedDepartment() {
    if (_selectedDepartmentId == 'all') {
      return;
    }

    if (_hasNextPage) {
      return;
    }

    for (final department in _departments) {
      if (department.id == _selectedDepartmentId) {
        return;
      }
    }

    _selectedDepartmentId = 'all';
  }

  @override
  void dispose() {
    _isDisposed = true;
    thumbnailCache.dispose();
    scrollController
      ..removeListener(_handleScroll)
      ..dispose();
    closeSeatSelection();
    _searchDebounceTimer?.cancel();
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
    if (_isInitialLoading ||
        _isRefreshing ||
        _isViewSyncing ||
        _isLoadingMore) {
      _hasPendingSearchRefresh = true;
      return;
    }

    _hasPendingSearchRefresh = false;
    await _reloadModulesForActiveFilters();
  }

  void _flushPendingSearchRefresh() {
    if (!_hasPendingSearchRefresh ||
        isApplyingSelection ||
        _isInitialLoading ||
        _isRefreshing ||
        _isViewSyncing ||
        _isLoadingMore) {
      return;
    }

    _hasPendingSearchRefresh = false;
    _scheduleSearchRefresh(immediate: true);
  }
}

GetTrainingLibraryModulesUseCase createGetTrainingLibraryModulesUseCase(
  TrainingLibraryRepositoryImpl repository,
) {
  return GetTrainingLibraryModulesUseCase(repository);
}
