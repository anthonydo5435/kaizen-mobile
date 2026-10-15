import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/network/api_error.dart';
import '../../../../core/preference/app_preference.dart';
import '../../../../core/utils/app_permission_utils.dart';
import '../../../../core/utils/custom_functions.dart';
import '../../data/datasources/audit_remote_data_source.dart';
import '../../data/repositories/audit_repository_impl.dart';
import '../../domain/entities/audit_description_audit.dart';
import '../../domain/entities/audit_details.dart';
import '../../domain/entities/audit_list.dart';
import '../../domain/entities/audit_job_option.dart';
import '../../domain/entities/audit_main_list.dart';
import '../../domain/entities/audit_member.dart';
import '../../domain/entities/audit_member_status.dart';
import '../../domain/entities/audit_profile.dart';
import '../../domain/entities/performance_report.dart';
import '../../domain/entities/quarterly_audit.dart';
import '../../domain/entities/seat_description_audit_report_comments.dart';
import '../../domain/entities/seat_description_final_audit_report.dart';
import '../../domain/entities/single_audit_report_category_details.dart';
import '../../domain/repositories/audit_repository.dart';
import '../../domain/usecases/get_audit_details_usecase.dart';
import '../../domain/usecases/get_audit_evaluation_chart_usecase.dart';
import '../../domain/usecases/get_audit_overview_usecase.dart';
import '../../domain/usecases/get_audit_team_members_usecase.dart';
import '../../domain/usecases/get_quarterly_audit_usecase.dart';
import '../../domain/usecases/mark_favorite_subordinate_usecase.dart';
import '../../domain/usecases/mark_unfavorite_subordinate_usecase.dart';
import '../../domain/usecases/submit_description_audit_usecase.dart';
import '../../../login/domain/entities/user.dart';
import 'check_in_media_upload_controller.dart';
import 'check_in_state.dart';

class CheckInController extends ChangeNotifier {
  static const Duration _certifiedReportPdfUrlCacheTtl = Duration(minutes: 10);
  static const Duration _mainListSearchDebounceDuration = Duration(
    milliseconds: 400,
  );
  static const Duration _teamMembersSearchDebounceDuration = Duration(
    milliseconds: 400,
  );
  static const int _teamMembersScreenPageSize = 10;

  CheckInController(
    this._getAuditOverviewUseCase, [
    this._getAuditDetailsUseCase,
    this._getAuditEvaluationChartUseCase,
    this._getQuarterlyAuditUseCase,
    this._getAuditTeamMembersUseCase,
    this._markFavoriteSubordinateUseCase,
    this._markUnfavoriteSubordinateUseCase,
    this._auditRepository,
  ]);

  var showGraph = false;

  final GetAuditOverviewUseCase _getAuditOverviewUseCase;
  final GetAuditDetailsUseCase? _getAuditDetailsUseCase;
  final GetAuditEvaluationChartUseCase? _getAuditEvaluationChartUseCase;
  final GetQuarterlyAuditUseCase? _getQuarterlyAuditUseCase;
  final GetAuditTeamMembersUseCase? _getAuditTeamMembersUseCase;
  final MarkFavoriteSubordinateUseCase? _markFavoriteSubordinateUseCase;
  final MarkUnfavoriteSubordinateUseCase? _markUnfavoriteSubordinateUseCase;
  final AuditRepository? _auditRepository;
  late final SubmitDescriptionAuditUseCase? _submitDescriptionAuditUseCase =
      _auditRepository == null
      ? null
      : SubmitDescriptionAuditUseCase(_auditRepository);
  int _singleAuditDetailsGeneration = 0;
  bool _isDisposed = false;
  CheckInState _state = const CheckInState();
  AuditMainList? _activeMainListCache;
  AuditMainList? _myCheckInMainListCache;
  AuditMainList? _defaultActiveMainListCache;
  AuditMainList? _defaultMyCheckInMainListCache;
  Timer? _mainListSearchDebounceTimer;
  Timer? _teamMembersSearchDebounceTimer;
  String _teamMembersSearchQuery = '';
  final TextEditingController descriptionSearchController =
      TextEditingController();
  String _descriptionSearchQuery = '';
  bool _isSeatProfileFilterLoading = false;
  List<String> _seatProfileOptions = const <String>[];
  Map<String, String> _seatProfileJobUuids = const <String, String>{};
  String? _selectedSeatProfileJobUuid;
  bool _hasPendingMainListSearchRefresh = false;
  bool _hasPendingTeamMembersSearchRefresh = false;
  final Map<String, _CachedCertifiedReportPdfUrl> _certifiedReportPdfUrlCache =
      <String, _CachedCertifiedReportPdfUrl>{};

  CheckInState get state => _state;
  String get descriptionSearchQuery => _descriptionSearchQuery;

  void updateDescriptionSearchQuery(String query) {
    final normalizedQuery = query.trim().toLowerCase();
    if (_descriptionSearchQuery == normalizedQuery) {
      return;
    }

    _descriptionSearchQuery = normalizedQuery;
    notifyListeners();
  }

  List<QuarterlyAuditDescription> searchDescriptions(
    List<QuarterlyAuditDescription> descriptions,
  ) {
    if (_descriptionSearchQuery.isEmpty) {
      return descriptions;
    }

    return descriptions
        .where(
          (description) => description.description.toLowerCase().contains(
            _descriptionSearchQuery,
          ),
        )
        .toList(growable: false);
  }

  PerformanceReportViewData? get performanceReportViewData {
    final report = _state.performanceReport;
    if (report == null) {
      return null;
    }

    final selectedProfilePayload = report.reportSnapshot['selected_profile'];
    final rawCategories = report.reportSnapshot['categories'];
    final rawReportMessage = report.reportSnapshot['message']
        ?.toString()
        .trim();
    final hasSelectedProfile = selectedProfilePayload is Map<String, dynamic>
        ? selectedProfilePayload.isNotEmpty
        : selectedProfilePayload != null;
    final hasCategories = rawCategories is List && rawCategories.isNotEmpty;
    final currentPaygradeIndex = report.paygradePipeline.indexWhere(
      (step) => step.isCurrent,
    );

    return PerformanceReportViewData(
      categorySelectionKey:
          '${report.profile.profileJob}:${report.profile.profileUuid}:${report.categoryTabs.length}:${report.remarkVersion}',
      maxCategoryIndex: report.categoryTabs.isEmpty
          ? 0
          : report.categoryTabs.length - 1,
      reportMessage: rawReportMessage == null || rawReportMessage.isEmpty
          ? null
          : rawReportMessage,
      isOpenSeatView: _isOpenSeatPerformanceReport(report),
      shouldShowCompleteReportUi: hasSelectedProfile && hasCategories,
      shouldShowMessageOnly: hasSelectedProfile && !hasCategories,
      currentPaygradeStep: currentPaygradeIndex >= 0
          ? report.paygradePipeline[currentPaygradeIndex]
          : null,
    );
  }

  int resolvePerformanceReportSelectedCategoryIndex({
    required int selectedCategoryIndex,
    required String? categorySelectionKey,
  }) {
    final viewData = performanceReportViewData;
    if (viewData == null ||
        categorySelectionKey != viewData.categorySelectionKey) {
      return 0;
    }

    if (selectedCategoryIndex > viewData.maxCategoryIndex) {
      return 0;
    }

    return selectedCategoryIndex;
  }

  List<String> buildPerformanceReportPaygradeRequirements(String source) {
    final trimmed = source.trim();
    if (trimmed.isEmpty || trimmed == '-') {
      return const <String>['-'];
    }

    final items = trimmed
        .split(RegExp(r'[\r\n]+'))
        .map(
          (item) => item.replaceFirst(RegExp(r'^[\-\u2022\*]\s*'), '').trim(),
        )
        .where((item) => item.isNotEmpty)
        .toList(growable: false);

    return items.isEmpty ? <String>[trimmed] : items;
  }

  double resolvePerformanceReportPaygradeRate(
    PerformanceReportPaygradeStep step,
  ) {
    try {
      final value = step.payRateAmount;
      if (value <= 0 || value.isNaN || value.isInfinite) {
        return _parsePerformanceReportPayRateDisplay(step.payRateDisplay);
      }
      return value;
    } catch (_) {
      return _parsePerformanceReportPayRateDisplay(step.payRateDisplay);
    }
  }

  String formatPerformanceReportPaygradeDelta({
    required double value,
    required String paygradeUnit,
  }) {
    final safeValue = value <= 0 ? 0.0 : value;
    final normalized = safeValue.toStringAsFixed(2);
    return _performanceReportPaygradeDisplayWithUnit(
      paygradeDisplay: '\$$normalized/hr',
      paygradeUnit: paygradeUnit,
    );
  }

  String formatPerformanceReportPaygradeDisplay({
    required String paygradeDisplay,
    required String paygradeUnit,
  }) {
    return _performanceReportPaygradeDisplayWithUnit(
      paygradeDisplay: paygradeDisplay,
      paygradeUnit: paygradeUnit,
    );
  }

  Color resolvePerformanceReportPaygradeDisplayColor(String value) {
    return _isUnavailablePerformanceReportPaygradeDisplay(value)
        ? AppColors.secondaryColor
        : AppColors.textPrimary;
  }

  double _parsePerformanceReportPayRateDisplay(String value) {
    final match = RegExp(r'(\d+(?:\.\d+)?)').firstMatch(value);
    final parsed = match == null ? null : double.tryParse(match.group(1)!);
    if (parsed == null || parsed <= 0) {
      return 0.0;
    }
    return parsed;
  }

  String _performanceReportPaygradeDisplayWithUnit({
    required String paygradeDisplay,
    required String paygradeUnit,
  }) {
    final display = paygradeDisplay.trim();
    final unit = paygradeUnit.trim();
    if (display.isEmpty ||
        display == AppStrings.paygradesUnavailableDisplay ||
        !_hasPerformanceReportPaygradeUnit(unit)) {
      return display;
    }

    final slashIndex = display.lastIndexOf('/');
    if (slashIndex >= 0) {
      return '${display.substring(0, slashIndex + 1)}$unit';
    }

    return '$display/$unit';
  }

  bool _isUnavailablePerformanceReportPaygradeDisplay(String value) {
    return value.trim() == AppStrings.paygradesUnavailableDisplay;
  }

  bool _hasPerformanceReportPaygradeUnit(String value) {
    final trimmed = value.trim();
    return trimmed.isNotEmpty && trimmed != '--' && trimmed != '-';
  }

  int get selectedAuditYear =>
      _state.selectedAuditYear ?? CustomFunctions.currentYearQuarter().year;

  int get selectedAuditQuarter =>
      _state.selectedAuditQuarter ??
      CustomFunctions.currentYearQuarter().quarter;

  bool get isSelectedAuditPeriodCurrent {
    final currentPeriod = CustomFunctions.currentYearQuarter();
    return selectedAuditYear == currentPeriod.year &&
        selectedAuditQuarter == currentPeriod.quarter;
  }

  PerformanceReportCoreValueVisualSpec
  resolvePerformanceReportCoreValueVisualSpec(
    PerformanceReportCoreValue coreValue,
  ) {
    final normalizedTitle = coreValue.title.trim().toLowerCase();
    final normalizedIconKey = coreValue.iconKey?.trim().toLowerCase() ?? '';
    final accentColor = _resolveCoreValueAccentColor(coreValue);

    for (final config in _performanceReportCoreValueIconConfigs) {
      final matchesExplicitIcon =
          normalizedIconKey.isNotEmpty &&
          (normalizedIconKey == config.key.toLowerCase() ||
              normalizedIconKey == config.label.toLowerCase());
      final matchesTitle =
          normalizedTitle.contains(config.key.toLowerCase()) ||
          normalizedTitle.contains(config.label.toLowerCase()) ||
          config.keywords.any(
            (keyword) => normalizedTitle.contains(keyword.toLowerCase()),
          );

      if (matchesExplicitIcon || matchesTitle) {
        return _coreValueVisualSpecFromConfig(config, accentColor: accentColor);
      }
    }

    if (_performanceReportCoreValueIconConfigs.isEmpty) {
      return PerformanceReportCoreValueVisualSpec(
        key: 'award',
        label: 'Excellence',
        icon: Icons.emoji_events_outlined,
        color: accentColor ?? AppColors.secondaryColor,
      );
    }

    return _coreValueVisualSpecFromConfig(
      _performanceReportCoreValueIconConfigs[_stableCoreValueIconIndex(
        coreValue.title,
      )],
      accentColor: accentColor,
    );
  }

  String? get selectedAuditDetailsProfileUuid =>
      _normalizeProfileUuid(_state.selectedAuditDetailsProfileUuid);

  String get selectedAuditYearQuarterLabel =>
      '$selectedAuditYear - Q$selectedAuditQuarter';

  bool get isSeatProfileFilterLoading => _isSeatProfileFilterLoading;

  String get teamMembersSearchQuery => _teamMembersSearchQuery;

  List<int> get auditYearOptions {
    final currentYear = CustomFunctions.currentYearQuarter().year;
    return <int>[currentYear - 1, currentYear, currentYear + 1];
  }

  List<int> get auditQuarterOptions => const <int>[1, 2, 3, 4];

  bool isFavoriteUpdating(String profileJobId) {
    return _state.favoriteUpdatingProfileJobs.contains(profileJobId);
  }

  List<AuditMember> get visibleMembers {
    final members = _state.mainList?.results ?? const <AuditProfile>[];

    return members
        .where((member) {
          final matchesStatus =
              _state.isActualOwner ||
                  _state.selectedStatus == AuditMemberStatus.active
              ? member.status == _state.selectedStatus
              : true;
          final matchesSeatProfile =
              _state.selectedSeatProfile == null ||
              member.seatProfile == _state.selectedSeatProfile;
          return matchesStatus && matchesSeatProfile;
        })
        .toList(growable: false);
  }

  List<String> get yearQuarterOptions {
    final years = [...auditYearOptions]
      ..sort((left, right) => right.compareTo(left));
    return years
        .expand(
          (year) => List<String>.generate(
            4,
            (index) => '$year - Q${4 - index}',
            growable: false,
          ),
        )
        .toList(growable: false);
  }

  List<String> get seatProfileOptions {
    if (_seatProfileOptions.isNotEmpty) {
      return _seatProfileOptions;
    }

    final members = _state.mainList?.results ?? const <AuditProfile>[];
    final uniqueOptions = members
        .map((member) => member.seatProfile)
        .toSet()
        .toList(growable: false);
    uniqueOptions.sort();
    return uniqueOptions;
  }

  List<AuditMember> get teamMemberOptions {
    final members = _state.mainList?.results ?? const <AuditProfile>[];
    final uniqueOptions = members
        .map((member) => member)
        .toSet()
        .toList(growable: false);
    return uniqueOptions;
  }

  Future<void> ensureSeatProfileOptionsLoaded() async {
    final auditRepository = _auditRepository;
    if (auditRepository == null ||
        _isSeatProfileFilterLoading ||
        _seatProfileOptions.isNotEmpty) {
      return;
    }

    _isSeatProfileFilterLoading = true;
    notifyListeners();

    try {
      final options = await auditRepository.getSubordinateJobOptions();
      _seatProfileOptions = options
          .map((option) => option.title)
          .toList(growable: false);
      _seatProfileJobUuids = <String, String>{
        for (final AuditJobOption option in options) option.title: option.uuid,
      };
    } catch (error) {
      _logRecoverableError('ensureSeatProfileOptionsLoaded', error);
    } finally {
      _isSeatProfileFilterLoading = false;
      notifyListeners();
    }
  }

  Future<void> initialize() async {
    try {
      final user = await AppPreference.getUser();
      final isOwner = _hasTeamMemberTabsAccess(user);
      final isActualOwner = _isActualOwner(user);
      final selectedStatus = isOwner
          ? AuditMemberStatus.active
          : AuditMemberStatus.deactivated;
      final currentYearQuarter = CustomFunctions.currentYearQuarter();

      _clearMainListCaches(clearDefaultCaches: true);
      _resetMainListSearchState();
      _resetTeamMembersSearchState();
      _selectedSeatProfileJobUuid = null;

      _state = _state.copyWith(
        isLoading: true,
        isOwner: isOwner,
        isActualOwner: isActualOwner,
        isSelfAudit: false,
        selectedStatus: selectedStatus,
        searchQuery: '',
        selectedAuditYear: currentYearQuarter.year,
        selectedAuditQuarter: currentYearQuarter.quarter,
        isLoadingMore: false,
        clearMainList: true,
        clearSelectedYearQuarter: true,
        clearSelectedSeatProfile: true,
      );
      notifyListeners();

      final mainList = isOwner && isActualOwner
          ? await _loadTeamMembers(page: 1, pageSize: 12)
          : await _preloadNonOwnerLists(page: 1, pageSize: 12);
      if (isOwner && isActualOwner) {
        _cacheMainList(selectedStatus, mainList, updateDefaultCache: true);
      }
      _state = _state.copyWith(isLoading: false, mainList: mainList);
      notifyListeners();
    } catch (error) {
      _state = _state.copyWith(
        isLoading: false,
        isLoadingMore: false,
        clearMainList: true,
      );
      notifyListeners();
      _logRecoverableError('initialize', error);
    }
  }

  Future<void> refresh() async {
    if (_isDisposed || _state.isLoading || _state.isLoadingMore) {
      return;
    }
    _cancelPendingMainListSearchRefresh();
    await _refreshMainListSearchResults(showLoader: true, forceRefresh: true);
  }

  Future<void> loadNextPage() async {
    final currentList = _state.mainList;
    if (_state.isLoading ||
        _state.isLoadingMore ||
        currentList == null ||
        currentList.next == null) {
      return;
    }

    _state = _state.copyWith(isLoadingMore: true);
    notifyListeners();

    try {
      final nextPage = currentList.current + 1;
      final nextList = await _loadListForSelectedStatus(
        page: nextPage,
        pageSize: 12,
      );
      final mergedList = AuditMainList(
        count: nextList.count,
        next: nextList.next,
        previous: nextList.previous,
        current: nextList.current,
        results: [...currentList.results, ...nextList.results],
      );

      _cacheMainList(
        _state.selectedStatus,
        mergedList,
        updateDefaultCache: !_hasMainListSearchQuery(),
      );

      _state = _state.copyWith(isLoadingMore: false, mainList: mergedList);
      notifyListeners();
    } catch (error) {
      _state = _state.copyWith(isLoadingMore: false);
      notifyListeners();
      _logRecoverableError('loadNextPage', error);
    }
  }

  Future<void> loadNextTeamMembersPage() async {
    final currentList = _state.mainList;
    if (_state.isLoading ||
        _state.isLoadingMore ||
        currentList == null ||
        currentList.next == null) {
      return;
    }

    _state = _state.copyWith(isLoadingMore: true);
    notifyListeners();

    try {
      final nextPage = currentList.current + 1;
      final nextList = await _loadTeamMembers(
        page: nextPage,
        pageSize: _teamMembersScreenPageSize,
        search: _teamMembersSearchQuery,
      );
      final mergedList = AuditMainList(
        count: nextList.count,
        next: nextList.next,
        previous: nextList.previous,
        current: nextList.current,
        results: [...currentList.results, ...nextList.results],
      );

      _cacheList(AuditMemberStatus.active, mergedList);
      _state = _state.copyWith(isLoadingMore: false, mainList: mergedList);
      notifyListeners();
    } catch (error) {
      _state = _state.copyWith(isLoadingMore: false);
      notifyListeners();
      _logRecoverableError('loadNextTeamMembersPage', error);
    } finally {
      _flushPendingTeamMembersSearchRefresh();
    }
  }

  Future<void> initializeDetails(
    String profileJobId, {
    int? year,
    int? quarter,
    bool clearEvaluationCharts = true,
    String? profileUuid,
  }) async {
    try {
      final user = await AppPreference.getUser();
      final isOwner = _hasTeamMemberTabsAccess(user);
      final isActualOwner = _isActualOwner(user);
      final currentYearQuarter = CustomFunctions.currentYearQuarter();
      final resolvedYear = year ?? currentYearQuarter.year;
      final resolvedQuarter = quarter ?? currentYearQuarter.quarter;
      final normalizedSelectedProfileUuid = _normalizeProfileUuid(profileUuid);
      final selectedYearQuarterLabel =
          resolvedYear == currentYearQuarter.year &&
              resolvedQuarter == currentYearQuarter.quarter
          ? null
          : '$resolvedYear - Q$resolvedQuarter';

      _state = _state.copyWith(
        isLoading: true,
        isOwner: isOwner,
        isActualOwner: isActualOwner,
        isSelfAudit: false,
        selectedAuditYear: resolvedYear,
        selectedAuditQuarter: resolvedQuarter,
        selectedYearQuarter: selectedYearQuarterLabel,
        clearSelectedYearQuarter: selectedYearQuarterLabel == null,
        selectedAuditDetailsProfileUuid: normalizedSelectedProfileUuid,
        clearSelectedAuditDetailsProfileUuid:
            normalizedSelectedProfileUuid == null,
        clearDetails: true,
        clearEvaluationCharts: clearEvaluationCharts,
      );
      notifyListeners();

      final getAuditDetailsUseCase = _getAuditDetailsUseCase;
      if (profileJobId.trim().isEmpty || getAuditDetailsUseCase == null) {
        _state = _state.copyWith(isLoading: false);
        notifyListeners();
        return;
      }

      final details = await getAuditDetailsUseCase(
        profileJobId: profileJobId,
        year: resolvedYear,
        quarter: resolvedQuarter,
        profileUuid: profileUuid,
      );
      _state = _state.copyWith(
        isLoading: false,
        details: details,
        isSelfAudit: _isSelfAudit(details, user),
      );
      notifyListeners();
    } catch (error) {
      _state = _state.copyWith(isLoading: false);
      notifyListeners();
      _logRecoverableError('initializeDetails', error);
    }
  }

  Future<void> showEvaluationChart(
    String profileJobId, {
    String? profileUuid,
  }) async {
    showGraph = true;
    if (_state.evaluationCharts.isNotEmpty ||
        _state.isEvaluationChartLoading ||
        profileJobId.trim().isEmpty ||
        _getAuditEvaluationChartUseCase == null) {
      notifyListeners();
      return;
    }

    _state = _state.copyWith(isEvaluationChartLoading: true);
    notifyListeners();

    try {
      final evaluationCharts = await _getAuditEvaluationChartUseCase(
        profileJobId: profileJobId,
        profileUuid: profileUuid,
      );
      _state = _state.copyWith(
        evaluationCharts: evaluationCharts,
        isEvaluationChartLoading: false,
      );
      notifyListeners();
    } catch (error) {
      _state = _state.copyWith(isEvaluationChartLoading: false);
      notifyListeners();
      _logRecoverableError('showEvaluationChart', error);
    }
  }

  Future<void> refreshEvaluationChart(
    String profileJobId, {
    String? profileUuid,
  }) async {
    if (_state.isEvaluationChartLoading ||
        profileJobId.trim().isEmpty ||
        _getAuditEvaluationChartUseCase == null) {
      return;
    }

    _state = _state.copyWith(isEvaluationChartLoading: true);
    notifyListeners();

    try {
      final evaluationCharts = await _getAuditEvaluationChartUseCase(
        profileJobId: profileJobId,
        profileUuid: profileUuid,
      );
      _state = _state.copyWith(
        evaluationCharts: evaluationCharts,
        isEvaluationChartLoading: false,
      );
      notifyListeners();
    } catch (error) {
      _state = _state.copyWith(isEvaluationChartLoading: false);
      notifyListeners();
      _logRecoverableError('refreshEvaluationChart', error);
    }
  }

  Future<void> initializeQuarterlyAudit({
    required String quarterlyAuditId,
    required String date,
  }) async {
    _singleAuditDetailsGeneration += 1;
    _state = _state.copyWith(isLoading: true, clearQuarterlyAudit: true);
    notifyListeners();

    final getQuarterlyAuditUseCase = _getQuarterlyAuditUseCase;
    if (quarterlyAuditId.trim().isEmpty ||
        date.trim().isEmpty ||
        getQuarterlyAuditUseCase == null) {
      _state = _state.copyWith(isLoading: false);
      notifyListeners();
      return;
    }

    final quarterlyAudit = await getQuarterlyAuditUseCase(
      quarterlyAuditId: quarterlyAuditId,
      date: date,
    );
    _state = _state.copyWith(
      isLoading: false,
      quarterlyAudit: quarterlyAudit,
      clearSelectedQuarterlyAuditDescription: true,
    );
    notifyListeners();
  }

  Future<void> initializeSingleAuditDetails({
    required String quarterlyAuditId,
    required String date,
    int? year,
    int? quarter,
  }) async {
    _singleAuditDetailsGeneration += 1;
    descriptionSearchController.clear();
    _descriptionSearchQuery = '';
    try {
      final user = await AppPreference.getUser();
      final isOwner = _hasTeamMemberTabsAccess(user);
      final isActualOwner = _isActualOwner(user);
      final currentYearQuarter = CustomFunctions.currentYearQuarter();
      final resolvedYear = year ?? currentYearQuarter.year;
      final resolvedQuarter = quarter ?? currentYearQuarter.quarter;
      final selectedYearQuarterLabel =
          resolvedYear == currentYearQuarter.year &&
              resolvedQuarter == currentYearQuarter.quarter
          ? null
          : '$resolvedYear - Q$resolvedQuarter';

      _clearMainListCaches(clearDefaultCaches: true);
      _resetMainListSearchState();
      _resetTeamMembersSearchState();

      _state = _state.copyWith(
        isLoading: true,
        isOwner: isOwner,
        isActualOwner: isActualOwner,
        searchQuery: '',
        selectedAuditYear: resolvedYear,
        selectedAuditQuarter: resolvedQuarter,
        selectedYearQuarter: selectedYearQuarterLabel,
        clearSelectedYearQuarter: selectedYearQuarterLabel == null,
        clearMainList: true,
        clearQuarterlyAudit: true,
      );
      notifyListeners();

      final getQuarterlyAuditUseCase = _getQuarterlyAuditUseCase;
      if (quarterlyAuditId.trim().isEmpty ||
          date.trim().isEmpty ||
          getQuarterlyAuditUseCase == null) {
        _state = _state.copyWith(isLoading: false);
        notifyListeners();
        return;
      }

      final teamMembersFuture = isOwner
          ? _loadTeamMembers(page: 1, pageSize: _teamMembersScreenPageSize)
          : null;
      final quarterlyAudit = await getQuarterlyAuditUseCase(
        quarterlyAuditId: quarterlyAuditId,
        date: date,
      );
      AuditMainList? teamMembers;

      if (teamMembersFuture != null) {
        try {
          teamMembers = _sortedMainList(await teamMembersFuture);
          if (teamMembers != null) {
            _cacheMainList(
              _state.selectedStatus,
              teamMembers,
              updateDefaultCache: true,
            );
          }
        } catch (error) {
          _logRecoverableError(
            'initializeSingleAuditDetails.loadTeamMembers',
            error,
          );
        }
      }

      _state = _state.copyWith(
        isLoading: false,
        mainList: teamMembers,
        quarterlyAudit: quarterlyAudit,
        clearSelectedQuarterlyAuditDescription: true,
      );
      notifyListeners();
    } catch (error) {
      _state = _state.copyWith(isLoading: false);
      notifyListeners();
      _logRecoverableError('initializeSingleAuditDetails', error);
    }
  }

  Future<void> refreshSingleAuditDetails({
    required String quarterlyAuditId,
    required String date,
  }) async {
    final getQuarterlyAuditUseCase = _getQuarterlyAuditUseCase;
    if (quarterlyAuditId.trim().isEmpty ||
        date.trim().isEmpty ||
        getQuarterlyAuditUseCase == null) {
      return;
    }

    final quarterlyAudit = await getQuarterlyAuditUseCase(
      quarterlyAuditId: quarterlyAuditId,
      date: date,
    );

    _state = _state.copyWith(
      quarterlyAudit: quarterlyAudit,
      clearSelectedQuarterlyAuditDescription: true,
    );
    notifyListeners();
  }

  Future<QuarterlyAudit?> loadQuarterlyAuditForDate({
    required String quarterlyAuditId,
    required String date,
  }) async {
    final getQuarterlyAuditUseCase = _getQuarterlyAuditUseCase;
    if (quarterlyAuditId.trim().isEmpty ||
        date.trim().isEmpty ||
        getQuarterlyAuditUseCase == null) {
      return null;
    }

    return getQuarterlyAuditUseCase(
      quarterlyAuditId: quarterlyAuditId,
      date: date,
    );
  }

  Future<AuditDescriptionAudit> loadAuditDescription({
    required String quarterlyAuditId,
    required String descriptionId,
    required String date,
  }) async {
    final auditRepository = _auditRepository;
    if (auditRepository == null) {
      throw StateError('AuditRepository is not configured.');
    }

    return auditRepository.getAuditDescriptionAudit(
      quarterlyAuditId: quarterlyAuditId,
      descriptionId: descriptionId,
      date: date,
    );
  }

  Future<AuditDescriptionAudit> submitAuditDescriptionSelection({
    required String quarterlyAuditId,
    required String seatDescriptionId,
    required String descriptionId,
    required Map<String, int> audit,
  }) async {
    final submitDescriptionAudit = _submitDescriptionAuditUseCase;
    if (submitDescriptionAudit == null) {
      throw StateError('AuditRepository is not configured.');
    }

    final generation = _singleAuditDetailsGeneration;
    final savedCounts = Map<String, int>.unmodifiable(audit);
    final response = await submitDescriptionAudit(
      descriptionId: descriptionId,
      audit: savedCounts,
    );
    final currentAudit = _state.quarterlyAudit;
    if (!_isDisposed &&
        generation == _singleAuditDetailsGeneration &&
        currentAudit != null &&
        currentAudit.uuid == quarterlyAuditId) {
      // The PATCH response may omit ratings. Publish its accepted payload so
      // list cards do not depend on a second, potentially stale summary fetch.
      _state = _state.copyWith(
        quarterlyAudit: currentAudit.withDescriptionRatingCounts(
          descriptionId: seatDescriptionId,
          auditId: descriptionId,
          counts: savedCounts,
        ),
      );
      notifyListeners();
    }
    return response;
  }

  Future<List<AuditList>> loadAuditReport({
    required int quarter,
    required int year,
    required String profileJobId,
  }) async {
    final auditRepository = _auditRepository;
    if (auditRepository == null) {
      throw StateError('AuditRepository is not configured.');
    }

    return auditRepository.getAuditReport(
      quarter: quarter,
      year: year,
      profileJobId: profileJobId,
    );
  }

  Future<List<SingleAuditReportCategoryDetails>>
  loadAuditReportCategoryDetails({
    required String categoryId,
    required int quarter,
    required int year,
  }) async {
    final auditRepository = _auditRepository;
    if (auditRepository == null) {
      throw StateError('AuditRepository is not configured.');
    }

    return auditRepository.getAuditReportCategoryDetails(
      categoryId: categoryId,
      quarter: quarter,
      year: year,
    );
  }

  Future<SeatDescriptionFinalAuditReport> loadSeatDescriptionFinalAuditReport({
    required String flowFirstId,
    String? profileUuid,
    required String descriptionId,
    int? quarter,
    int? year,
    String? timeRange,
  }) async {
    final auditRepository = _auditRepository;
    if (auditRepository == null) {
      throw StateError('AuditRepository is not configured.');
    }

    return auditRepository.getSeatDescriptionFinalAuditReport(
      flowFirstId: flowFirstId,
      profileUuid: profileUuid,
      descriptionId: descriptionId,
      quarter: quarter,
      year: year,
      timeRange: timeRange,
    );
  }

  Future<SeatDescriptionAuditReportComments>
  loadSeatDescriptionAuditReportComments({
    required String flowFirstId,
    String? profileUuid,
    required String descriptionId,
    int? quarter,
    int? year,
    String? timeRange,
  }) async {
    final auditRepository = _auditRepository;
    if (auditRepository == null) {
      throw StateError('AuditRepository is not configured.');
    }

    return auditRepository.getSeatDescriptionAuditReportComments(
      flowFirstId: flowFirstId,
      profileUuid: profileUuid,
      descriptionId: descriptionId,
      quarter: quarter,
      year: year,
      timeRange: timeRange,
    );
  }

  Future<List<SeatDescriptionFinalAuditProfile>>
  loadSeatDescriptionAuditReportProfiles({
    required String flowFirstId,
    String? profileUuid,
    required String descriptionId,
    int? quarter,
    int? year,
    String? timeRange,
  }) async {
    final auditRepository = _auditRepository;
    if (auditRepository == null) {
      throw StateError('AuditRepository is not configured.');
    }

    return auditRepository.getSeatDescriptionAuditReportProfiles(
      flowFirstId: flowFirstId,
      profileUuid: profileUuid,
      descriptionId: descriptionId,
      quarter: quarter,
      year: year,
      timeRange: timeRange,
    );
  }

  Future<void> createAuditDescriptionComment({
    required String descriptionId,
    required String comment,
  }) async {
    final auditRepository = _auditRepository;
    if (auditRepository == null) {
      throw StateError('AuditRepository is not configured.');
    }

    await auditRepository.createAuditDescriptionComment(
      descriptionId: descriptionId,
      comment: comment,
    );
  }

  Future<bool> createAuditDescriptionMediaComment({
    required String descriptionId,
    required String comment,
    File? mediaFile,
    String? mediaType,
  }) async {
    final auditRepository = _auditRepository;
    if (auditRepository == null) {
      throw StateError('AuditRepository is not configured.');
    }

    final resolvedMediaType = mediaType?.trim();
    if (mediaFile != null &&
        _shouldUseBackgroundMediaUpload(resolvedMediaType)) {
      final didStart = await CheckInMediaUploadController.instance
          .startUploadForDescriptionMediaComment(
            descriptionId: descriptionId,
            comment: comment,
            sourceFile: mediaFile,
            mediaType: resolvedMediaType!,
          );
      if (!didStart) {
        throw StateError(
          CheckInMediaUploadController.instance.startErrorMessage
                      ?.trim()
                      .isNotEmpty ==
                  true
              ? CheckInMediaUploadController.instance.startErrorMessage!.trim()
              : AppStrings.auditMediaUploadFailed,
        );
      }
      return false;
    }

    String? mediaUrl;
    if (mediaFile != null) {
      final fileName = CustomFunctions.fileNameFromPath(mediaFile.path);
      final uploadUrl = await auditRepository
          .generateAuditDescriptionMediaUploadUrl(fileName: fileName);

      await auditRepository.uploadAuditDescriptionMediaFile(
        uploadUrl: uploadUrl,
        fileName: fileName,
        fileBytes: await mediaFile.readAsBytes(),
        contentType: CustomFunctions.contentTypeFromPath(mediaFile.path),
      );

      final querySeparatorIndex = uploadUrl.indexOf('?');
      mediaUrl = querySeparatorIndex == -1
          ? uploadUrl
          : uploadUrl.substring(0, querySeparatorIndex);
    }

    await auditRepository.createAuditDescriptionMedia(
      descriptionId: descriptionId,
      comment: comment,
      mediaUrl: mediaUrl,
      mediaType: mediaUrl == null ? null : resolvedMediaType,
    );
    return true;
  }

  bool _shouldUseBackgroundMediaUpload(String? mediaType) {
    final normalizedType = mediaType?.trim().toLowerCase();
    return normalizedType == 'video' || normalizedType == 'screen_recording';
  }

  Future<List<AuditProfile>> toggleFavoriteSubordinate({
    required String profileJobId,
    required bool isFavorite,
  }) async {
    final markFavoriteSubordinateUseCase = _markFavoriteSubordinateUseCase;
    final markUnfavoriteSubordinateUseCase = _markUnfavoriteSubordinateUseCase;
    final getAuditTeamMembersUseCase = _getAuditTeamMembersUseCase;
    final auditRepository = _auditRepository;
    if (profileJobId.trim().isEmpty ||
        ((isFavorite
                ? markUnfavoriteSubordinateUseCase == null
                : markFavoriteSubordinateUseCase == null) &&
            auditRepository == null)) {
      return _state.mainList?.results ?? const <AuditProfile>[];
    }

    if (isFavoriteUpdating(profileJobId)) {
      return _state.mainList?.results ?? const <AuditProfile>[];
    }

    _setFavoriteUpdating(profileJobId, true);
    try {
      if (isFavorite) {
        if (markUnfavoriteSubordinateUseCase != null) {
          await markUnfavoriteSubordinateUseCase(profileJobId: profileJobId);
        } else {
          await auditRepository!.markUnfavoriteSubordinate(
            profileJobId: profileJobId,
          );
        }
      } else {
        if (markFavoriteSubordinateUseCase != null) {
          await markFavoriteSubordinateUseCase(profileJobId: profileJobId);
        } else {
          await auditRepository!.markFavoriteSubordinate(
            profileJobId: profileJobId,
          );
        }
      }

      final refreshedMembers = getAuditTeamMembersUseCase != null
          ? await getAuditTeamMembersUseCase(
              page: 1,
              pageSize: _resolvedTeamMembersPageSize(),
              year: selectedAuditYear,
              quarter: selectedAuditQuarter,
              search: _teamMembersSearchQuery,
            )
          : await _loadTeamMembers(
              page: 1,
              pageSize: _resolvedTeamMembersPageSize(),
              search: _teamMembersSearchQuery,
            );
      final sortedMembers =
          _sortedMainList(refreshedMembers) ?? refreshedMembers;
      _state = _state.copyWith(mainList: sortedMembers);
      notifyListeners();
      return sortedMembers.results;
    } finally {
      _setFavoriteUpdating(profileJobId, false);
    }
  }

  void setShowGraph(bool value) {
    if (showGraph == value) {
      return;
    }

    showGraph = value;
    notifyListeners();
  }

  Future<void> selectStatus(AuditMemberStatus status) async {
    if (_state.selectedStatus == status) {
      return;
    }

    _cancelPendingMainListSearchRefresh();

    _state = _state.copyWith(
      selectedStatus: status,
      isLoading: !_state.isActualOwner,
      isLoadingMore: false,
      clearMainList: !_state.isActualOwner,
    );
    notifyListeners();

    if (_state.isActualOwner) {
      return;
    }

    final cachedList =
        _cachedListFor(status) ??
        (!_hasMainListSearchQuery() ? _defaultCachedListFor(status) : null);
    if (cachedList != null) {
      if (!_hasMainListSearchQuery()) {
        _restoreDefaultMainListCaches();
      }
      _state = _state.copyWith(isLoading: false, mainList: cachedList);
      notifyListeners();
      return;
    }

    try {
      final mainList = await _loadListForSelectedStatus(page: 1, pageSize: 12);
      _cacheMainList(
        status,
        mainList,
        updateDefaultCache: !_hasMainListSearchQuery(),
      );
      _state = _state.copyWith(isLoading: false, mainList: mainList);
      notifyListeners();
    } catch (error) {
      _state = _state.copyWith(isLoading: false);
      notifyListeners();
      _logRecoverableError('selectStatus', error);
    }
  }

  void selectQuarterlyAuditDescription(String descriptionUuid) {
    if (_state.selectedQuarterlyAuditDescriptionUuid == descriptionUuid) {
      return;
    }

    _state = _state.copyWith(
      selectedQuarterlyAuditDescriptionUuid: descriptionUuid,
    );
    notifyListeners();
  }

  void updateSearchQuery(String query) {
    final hasSearchQuery = query.trim().isNotEmpty;
    final nextQuery = hasSearchQuery ? query : '';
    if (_state.searchQuery == nextQuery) {
      return;
    }

    _cancelPendingMainListSearchRefresh();

    if (!hasSearchQuery) {
      final restoredMainList = _restoreDefaultMainListCaches();
      _state = _state.copyWith(
        searchQuery: '',
        isLoading: false,
        isLoadingMore: false,
        mainList: restoredMainList ?? _state.mainList,
      );
      notifyListeners();

      if (restoredMainList != null) {
        return;
      }

      _scheduleMainListSearchRefresh(immediate: true);
      return;
    }

    _clearMainListCaches();
    _state = _state.copyWith(searchQuery: nextQuery, isLoadingMore: false);
    notifyListeners();
    _scheduleMainListSearchRefresh();
  }

  Future<void> resetSearch({bool showLoader = true}) async {
    _cancelPendingMainListSearchRefresh();
    final restoredMainList = _restoreDefaultMainListCaches();

    if (_state.searchQuery.trim().isEmpty) {
      if (restoredMainList == null) {
        return;
      }

      _state = _state.copyWith(
        searchQuery: '',
        isLoading: false,
        isLoadingMore: false,
        mainList: restoredMainList,
      );
      notifyListeners();
      return;
    }

    _state = _state.copyWith(
      searchQuery: '',
      isLoading: false,
      isLoadingMore: false,
      mainList: restoredMainList ?? _state.mainList,
    );
    notifyListeners();

    if (restoredMainList != null) {
      return;
    }

    await _refreshMainListSearchResults(showLoader: showLoader);
  }

  void updateTeamMembersSearchQuery(String query) {
    if (_teamMembersSearchQuery == query) {
      return;
    }

    _teamMembersSearchQuery = query;
    _scheduleTeamMembersSearchRefresh();
  }

  Future<void> resetTeamMembersSearch({bool showLoader = false}) async {
    _teamMembersSearchDebounceTimer?.cancel();
    if (_teamMembersSearchQuery.trim().isEmpty) {
      return;
    }

    _teamMembersSearchQuery = '';
    await _refreshTeamMembersSearchResults(showLoader: showLoader);
  }

  Future<void> selectAuditYear(int year) async {
    await _reloadAuditPeriod(year: year);
  }

  Future<void> selectAuditQuarter(int quarter) async {
    await _reloadAuditPeriod(quarter: quarter);
  }

  Future<void> applyFilters({String? yearQuarter, String? seatProfile}) async {
    final shouldClearSeatProfile = seatProfile == null || seatProfile.isEmpty;
    if (!shouldClearSeatProfile && _seatProfileJobUuids.isEmpty) {
      await ensureSeatProfileOptionsLoaded();
    }
    final resolvedSeatProfile = shouldClearSeatProfile ? null : seatProfile;
    final resolvedSeatProfileJobUuid = shouldClearSeatProfile
        ? null
        : _seatProfileJobUuids[resolvedSeatProfile];
    final resolvedYearQuarter = (yearQuarter == null || yearQuarter.isEmpty)
        ? selectedAuditYearQuarterLabel
        : yearQuarter;
    final parsedYearQuarter = _parseYearQuarterLabel(resolvedYearQuarter);
    final currentYearQuarter = CustomFunctions.currentYearQuarter();
    final shouldClearYearQuarterChip =
        parsedYearQuarter == null ||
        (parsedYearQuarter.year == currentYearQuarter.year &&
            parsedYearQuarter.quarter == currentYearQuarter.quarter);
    final resolvedYearQuarterChip = shouldClearYearQuarterChip
        ? null
        : resolvedYearQuarter;
    final isPeriodChanged =
        parsedYearQuarter != null &&
        (parsedYearQuarter.year != selectedAuditYear ||
            parsedYearQuarter.quarter != selectedAuditQuarter);

    final isSeatProfileChanged =
        _state.selectedSeatProfile != resolvedSeatProfile ||
        _selectedSeatProfileJobUuid != resolvedSeatProfileJobUuid;

    if (!isSeatProfileChanged &&
        _state.selectedYearQuarter == resolvedYearQuarterChip &&
        !isPeriodChanged) {
      return;
    }

    if (isPeriodChanged || isSeatProfileChanged) {
      final selectedPeriod = parsedYearQuarter;
      if (selectedPeriod == null) {
        return;
      }

      _cancelPendingMainListSearchRefresh();
      _clearMainListCaches(clearDefaultCaches: true);
      _selectedSeatProfileJobUuid = resolvedSeatProfileJobUuid;

      _state = _state.copyWith(
        selectedSeatProfile: resolvedSeatProfile,
        clearSelectedSeatProfile: shouldClearSeatProfile,
        selectedYearQuarter: resolvedYearQuarterChip,
        clearSelectedYearQuarter: shouldClearYearQuarterChip,
        selectedAuditYear: selectedPeriod.year,
        selectedAuditQuarter: selectedPeriod.quarter,
        isLoading: true,
        isLoadingMore: false,
        clearMainList: true,
      );
      notifyListeners();

      try {
        final mainList = await _loadListForSelectedStatus(
          page: 1,
          pageSize: 12,
        );
        _cacheMainList(
          _state.selectedStatus,
          mainList,
          updateDefaultCache: !_hasMainListSearchQuery(),
        );
        _state = _state.copyWith(isLoading: false, mainList: mainList);
        notifyListeners();
      } catch (error) {
        _state = _state.copyWith(isLoading: false);
        notifyListeners();
        _logRecoverableError('applyFilters', error);
      }
      return;
    }

    _state = _state.copyWith(
      selectedSeatProfile: resolvedSeatProfile,
      clearSelectedSeatProfile: shouldClearSeatProfile,
      selectedYearQuarter: resolvedYearQuarterChip,
      clearSelectedYearQuarter: shouldClearYearQuarterChip,
    );
    notifyListeners();
  }

  Future<void> clearYearQuarterFilter() async {
    final currentYearQuarter = CustomFunctions.currentYearQuarter();
    if (_state.selectedYearQuarter == null &&
        selectedAuditYear == currentYearQuarter.year &&
        selectedAuditQuarter == currentYearQuarter.quarter) {
      return;
    }

    _cancelPendingMainListSearchRefresh();
    _clearMainListCaches(clearDefaultCaches: true);

    _state = _state.copyWith(
      selectedAuditYear: currentYearQuarter.year,
      selectedAuditQuarter: currentYearQuarter.quarter,
      isLoading: true,
      isLoadingMore: false,
      clearMainList: true,
      clearSelectedYearQuarter: true,
    );
    notifyListeners();

    try {
      final mainList = await _loadListForSelectedStatus(page: 1, pageSize: 12);
      _cacheMainList(
        _state.selectedStatus,
        mainList,
        updateDefaultCache: !_hasMainListSearchQuery(),
      );
      _state = _state.copyWith(isLoading: false, mainList: mainList);
      notifyListeners();
    } catch (error) {
      _state = _state.copyWith(isLoading: false);
      notifyListeners();
      _logRecoverableError('clearYearQuarterFilter', error);
    }
  }

  Future<void> clearSeatProfileFilter() {
    if (_state.selectedSeatProfile == null) {
      return Future<void>.value();
    }

    return applyFilters(
      yearQuarter: selectedAuditYearQuarterLabel,
      seatProfile: null,
    );
  }

  void setAuditActionLoading(bool value) {
    if (_state.isAuditActionLoading == value) {
      return;
    }

    _state = _state.copyWith(isAuditActionLoading: value);
    notifyListeners();
  }

  Future<void> initializePerformanceReport(AuditProfile profile) async {
    _state = _state.copyWith(
      isPerformanceReportLoading: true,
      clearPerformanceReport: true,
      performanceReportTimeRange: 'This Quarter',
      clearPerformanceReportStartDate: true,
      clearPerformanceReportEndDate: true,
      clearCertifiedReportOptions: true,
      clearSelectedCertifiedReportUuid: true,
      clearEmployeeSignatureBytes: true,
      clearEmployeeSignatureImageId: true,
      clearFacilitatorSignatureBytes: true,
      clearFacilitatorSignatureImageId: true,
      performanceReportCommitment: '',
    );
    notifyListeners();

    final auditRepository = _auditRepository;
    if (auditRepository == null) {
      _state = _state.copyWith(isPerformanceReportLoading: false);
      notifyListeners();
      return;
    }

    await _loadQuarterPerformanceReport(profile);
  }

  Future<void> selectPerformanceReportTimeRange(String timeRange) async {
    final currentReport = _state.performanceReport;
    if (currentReport == null ||
        _state.performanceReportTimeRange == timeRange) {
      return;
    }

    if (timeRange == 'This Quarter') {
      _state = _state.copyWith(
        isPerformanceReportLoading: true,
        performanceReportTimeRange: timeRange,
        clearPerformanceReportStartDate: true,
        clearPerformanceReportEndDate: true,
      );
      notifyListeners();

      await _loadQuarterPerformanceReport(currentReport.profile);
      return;
    }

    _state = _state.copyWith(
      performanceReportTimeRange: timeRange,
      clearPerformanceReportStartDate: true,
      clearPerformanceReportEndDate: true,
    );
    notifyListeners();
  }

  Future<void> applyPerformanceReportCustomDateRange({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final auditRepository = _auditRepository;
    final currentReport = _state.performanceReport;
    if (auditRepository == null || currentReport == null) {
      return;
    }

    _state = _state.copyWith(
      isPerformanceReportLoading: true,
      performanceReportTimeRange: 'Custom Date Range',
      performanceReportStartDate: startDate,
      performanceReportEndDate: endDate,
    );
    notifyListeners();

    try {
      late final PerformanceReport report;
      try {
        report = await auditRepository.getPerformanceReportOverview(
          profile: currentReport.profile,
          startDate: startDate,
          endDate: endDate,
        );
      } on ApiError catch (error) {
        if (!_shouldUseOpenSeatFallback(error)) {
          _state = _state.copyWith(isPerformanceReportLoading: false);
          notifyListeners();
          _logRecoverableError('applyPerformanceReportCustomDateRange', error);
          return;
        }

        report = _buildOpenSeatPerformanceReport(currentReport.profile);
      }

      final certifiedReports = await _loadCertifiedReportsForPerformanceReport(
        auditRepository: auditRepository,
        profile: currentReport.profile,
        report: report,
        startDate: startDate,
        endDate: endDate,
      );

      _state = _state.copyWith(
        isPerformanceReportLoading: false,
        performanceReport: report,
        certifiedReportOptions: certifiedReports,
        clearSelectedCertifiedReportUuid: true,
      );
      notifyListeners();
    } catch (error) {
      _state = _state.copyWith(isPerformanceReportLoading: false);
      notifyListeners();
      _logRecoverableError('applyPerformanceReportCustomDateRange', error);
    }
  }

  Future<void> generatePerformanceReportRemarks() async {
    final auditRepository = _auditRepository;
    final currentReport = _state.performanceReport;
    if (auditRepository == null ||
        currentReport == null ||
        _state.isGeneratingPerformanceReportRemarks) {
      return;
    }

    _state = _state.copyWith(isGeneratingPerformanceReportRemarks: true);
    notifyListeners();

    try {
      final remarksByDescription =
          _state.performanceReportTimeRange == 'Custom Date Range' &&
              _state.performanceReportStartDate != null &&
              _state.performanceReportEndDate != null
          ? await auditRepository.getPerformanceReportRemarks(
              profile: currentReport.profile,
              startDate: _state.performanceReportStartDate,
              endDate: _state.performanceReportEndDate,
            )
          : await auditRepository.getPerformanceReportRemarks(
              profile: currentReport.profile,
              year: CustomFunctions.currentYearQuarter().year,
              quarter: CustomFunctions.currentYearQuarter().quarter,
            );

      _state = _state.copyWith(
        performanceReport: _applyRemarksToReport(
          currentReport,
          remarksByDescription,
        ),
        isGeneratingPerformanceReportRemarks: false,
      );
      notifyListeners();
    } catch (error) {
      _state = _state.copyWith(isGeneratingPerformanceReportRemarks: false);
      notifyListeners();
      _logRecoverableError('generatePerformanceReportRemarks', error);
    }
  }

  Future<void> _loadQuarterPerformanceReport(AuditProfile profile) async {
    final auditRepository = _auditRepository;
    if (auditRepository == null) {
      _state = _state.copyWith(isPerformanceReportLoading: false);
      notifyListeners();
      return;
    }

    final currentYearQuarter = CustomFunctions.currentYearQuarter();
    try {
      late final PerformanceReport report;
      try {
        report = await auditRepository.getPerformanceReportOverview(
          profile: profile,
          year: currentYearQuarter.year,
          quarter: currentYearQuarter.quarter,
        );
      } on ApiError catch (error) {
        if (!_shouldUseOpenSeatFallback(error)) {
          _state = _state.copyWith(isPerformanceReportLoading: false);
          notifyListeners();
          _logRecoverableError('_loadQuarterPerformanceReport', error);
          return;
        }

        report = _buildOpenSeatPerformanceReport(profile);
      }

      final certifiedReports = await _loadCertifiedReportsForPerformanceReport(
        auditRepository: auditRepository,
        profile: profile,
        report: report,
        year: currentYearQuarter.year,
        quarter: currentYearQuarter.quarter,
      );

      _state = _state.copyWith(
        isPerformanceReportLoading: false,
        performanceReport: report,
        certifiedReportOptions: certifiedReports,
        clearSelectedCertifiedReportUuid: true,
      );
      notifyListeners();
    } catch (error) {
      _state = _state.copyWith(isPerformanceReportLoading: false);
      notifyListeners();
      _logRecoverableError('_loadQuarterPerformanceReport', error);
    }
  }

  Future<void> selectCertifiedReport(String? uuid) async {
    final currentReport = _state.performanceReport;
    final trimmed = uuid?.trim();
    if (currentReport == null) {
      return;
    }

    if ((trimmed == null || trimmed.isEmpty) &&
        _state.selectedCertifiedReportUuid != null) {
      _state = _state.copyWith(
        clearSelectedCertifiedReportUuid: true,
        isPerformanceReportLoading: true,
      );
      notifyListeners();

      if (_state.performanceReportTimeRange == 'Custom Date Range' &&
          _state.performanceReportStartDate != null &&
          _state.performanceReportEndDate != null) {
        await applyPerformanceReportCustomDateRange(
          startDate: _state.performanceReportStartDate!,
          endDate: _state.performanceReportEndDate!,
        );
        return;
      }

      await _loadQuarterPerformanceReport(currentReport.profile);
      return;
    }

    if (trimmed == null ||
        trimmed.isEmpty ||
        trimmed == _state.selectedCertifiedReportUuid) {
      return;
    }

    final auditRepository = _auditRepository;
    if (auditRepository == null) {
      return;
    }

    _state = _state.copyWith(
      selectedCertifiedReportUuid: trimmed,
      isPerformanceReportLoading: true,
    );
    notifyListeners();

    try {
      final detail = await auditRepository.getCertifiedReportDetail(
        certifiedReportUuid: trimmed,
        fallbackProfile: currentReport.profile,
      );
      _state = _state.copyWith(
        isPerformanceReportLoading: false,
        performanceReport: detail.report,
        performanceReportCommitment: detail.commitmentComment,
      );
    } catch (error) {
      _state = _state.copyWith(
        isPerformanceReportLoading: false,
        clearSelectedCertifiedReportUuid: true,
      );
      _logRecoverableError('selectCertifiedReport', error);
    }
    notifyListeners();
  }

  PerformanceReport _applyRemarksToReport(
    PerformanceReport report,
    Map<String, String> remarksByDescription,
  ) {
    List<PerformanceReportRatingRow> updateRows(
      List<PerformanceReportRatingRow> rows,
    ) {
      return rows
          .map(
            (row) => PerformanceReportRatingRow(
              descriptionUuid: row.descriptionUuid,
              title: row.title,
              passCount: row.passCount,
              partialCount: row.partialCount,
              failCount: row.failCount,
              ratingPercent: row.ratingPercent,
              remarks: remarksByDescription[row.descriptionUuid] ?? row.remarks,
            ),
          )
          .toList(growable: false);
    }

    final updatedTabs = report.categoryTabs
        .map(
          (tab) => PerformanceReportCategoryTab(
            label: tab.label,
            score: tab.score,
            rows: updateRows(tab.rows),
          ),
        )
        .toList(growable: false);
    final updatedRatingRows = updateRows(report.ratingRows);
    final updatedReportSnapshot = _applyRemarksToReportSnapshot(
      report.reportSnapshot,
      _collectRemarksByDescription(updatedTabs),
    );

    return PerformanceReport(
      profile: report.profile,
      createdAt: report.createdAt,
      personalityAvatarImagePath: report.personalityAvatarImagePath,
      hasPersonalityData: report.hasPersonalityData,
      isCertified: report.isCertified,
      certifiedAt: report.certifiedAt,
      employeeSignatureName: report.employeeSignatureName,
      selectedProfileSignatureUuid: report.selectedProfileSignatureUuid,
      selectedProfileSignatureUrl: report.selectedProfileSignatureUrl,
      facilitatorSignatureUrl: report.facilitatorSignatureUrl,
      facilitatorName: report.facilitatorName,
      reportSnapshot: updatedReportSnapshot,
      rawPersonalityDescription: report.rawPersonalityDescription,
      overallPerformanceScore: report.overallPerformanceScore,
      confidenceLevel: report.confidenceLevel,
      archetypeTitle: report.archetypeTitle,
      archetypeSubtitle: report.archetypeSubtitle,
      archetypeSummary: report.archetypeSummary,
      guidanceParagraphs: report.guidanceParagraphs,
      categoryTabs: updatedTabs,
      selectedCategoryIndex: report.selectedCategoryIndex,
      ratingRows: updatedRatingRows,
      paygradePipeline: report.paygradePipeline,
      currentPaygrade: report.currentPaygrade,
      paygradeUnit: report.paygradeUnit,
      coreValues: report.coreValues,
      remarkVersion: report.remarkVersion,
    );
  }

  Map<String, String> _collectRemarksByDescription(
    List<PerformanceReportCategoryTab> categoryTabs,
  ) {
    final remarksByDescription = <String, String>{};
    for (final tab in categoryTabs) {
      for (final row in tab.rows) {
        final descriptionUuid = row.descriptionUuid.trim();
        if (descriptionUuid.isEmpty) {
          continue;
        }

        final remarks = row.remarks?.trim();
        if (remarks == null) {
          continue;
        }

        remarksByDescription[descriptionUuid] = remarks;
      }
    }

    return remarksByDescription;
  }

  Map<String, dynamic> _applyRemarksToReportSnapshot(
    Map<String, dynamic> reportSnapshot,
    Map<String, String> remarksByDescription,
  ) {
    if (remarksByDescription.isEmpty) {
      return Map<String, dynamic>.from(reportSnapshot);
    }

    final updatedSnapshot = Map<String, dynamic>.from(reportSnapshot);
    final rawCategories = updatedSnapshot['categories'];
    if (rawCategories is! List) {
      return updatedSnapshot;
    }

    updatedSnapshot['categories'] = rawCategories
        .map((rawCategory) {
          if (rawCategory is! Map) {
            return rawCategory;
          }

          final category = Map<String, dynamic>.from(rawCategory);
          final rawDescriptions = category['descriptions'];
          if (rawDescriptions is! List) {
            return category;
          }

          category['descriptions'] = rawDescriptions
              .map((rawDescription) {
                if (rawDescription is! Map) {
                  return rawDescription;
                }

                final description = Map<String, dynamic>.from(rawDescription);
                final descriptionUuid =
                    description['uuid']?.toString().trim() ??
                    description['description_uuid']?.toString().trim() ??
                    '';
                if (descriptionUuid.isEmpty) {
                  return description;
                }

                if (!remarksByDescription.containsKey(descriptionUuid)) {
                  return description;
                }

                final remarks = remarksByDescription[descriptionUuid] ?? '';
                description.remove('remarks');
                description['remark'] = remarks;
                return description;
              })
              .toList(growable: false);

          return category;
        })
        .toList(growable: false);

    return updatedSnapshot;
  }

  void updatePerformanceReportCommitment(String value) {
    final trimmedValue = value.length > 2000 ? value.substring(0, 2000) : value;
    if (_state.performanceReportCommitment == trimmedValue) {
      return;
    }

    _state = _state.copyWith(performanceReportCommitment: trimmedValue);
    notifyListeners();
  }

  Future<String?> saveEmployeeSignature(Uint8List bytes) async {
    _state = _state.copyWith(
      employeeSignatureBytes: bytes,
      clearEmployeeSignatureImageId: true,
    );
    notifyListeners();

    final auditRepository = _auditRepository;
    if (auditRepository == null) {
      return null;
    }

    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final signatureImageId = await auditRepository
          .uploadPerformanceReportSignatureImage(
            fileName: 'employee-signature-$timestamp.png',
            fileBytes: bytes,
            contentType: 'image/png',
          );

      _state = _state.copyWith(
        employeeSignatureBytes: bytes,
        employeeSignatureImageId: signatureImageId,
      );
      notifyListeners();
      return null;
    } catch (error) {
      debugPrint('Unable to upload employee signature: $error');
      return 'Unable to upload employee signature right now. Please try again.';
    }
  }

  Future<String?> saveFacilitatorSignature(Uint8List bytes) async {
    _state = _state.copyWith(
      facilitatorSignatureBytes: bytes,
      isFacilitatorSignatureUploading: true,
      clearFacilitatorSignatureImageId: true,
    );
    notifyListeners();

    final auditRepository = _auditRepository;
    if (auditRepository == null) {
      _state = _state.copyWith(isFacilitatorSignatureUploading: false);
      notifyListeners();
      return null;
    }

    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final signatureImageId = await auditRepository
          .uploadPerformanceReportSignatureImage(
            fileName: 'facilitator-signature-$timestamp.png',
            fileBytes: bytes,
            contentType: 'image/png',
          );

      _state = _state.copyWith(
        facilitatorSignatureBytes: bytes,
        facilitatorSignatureImageId: signatureImageId,
        isFacilitatorSignatureUploading: false,
      );
      notifyListeners();
      return null;
    } catch (error) {
      debugPrint('Unable to upload facilitator signature: $error');
      _state = _state.copyWith(isFacilitatorSignatureUploading: false);
      notifyListeners();
      return 'Unable to upload facilitator signature right now. Please try again.';
    }
  }

  void clearEmployeeSignature() {
    if (_state.employeeSignatureBytes == null &&
        _state.employeeSignatureImageId == null) {
      return;
    }

    _state = _state.copyWith(
      clearEmployeeSignatureBytes: true,
      clearEmployeeSignatureImageId: true,
    );
    notifyListeners();
  }

  void clearFacilitatorSignature() {
    if (_state.facilitatorSignatureBytes == null &&
        _state.facilitatorSignatureImageId == null) {
      return;
    }

    _state = _state.copyWith(
      clearFacilitatorSignatureBytes: true,
      clearFacilitatorSignatureImageId: true,
      isFacilitatorSignatureUploading: false,
    );
    notifyListeners();
  }

  bool isCertifiedReportPdfDownloading(String certifiedReportUuid) {
    return _state.downloadingCertifiedReportUuids.contains(certifiedReportUuid);
  }

  Future<String> downloadCertifiedReportPdf(String certifiedReportUuid) async {
    final auditRepository = _auditRepository;
    final trimmed = certifiedReportUuid.trim();
    if (auditRepository == null || trimmed.isEmpty) {
      return '';
    }

    final cachedEntry = _certifiedReportPdfUrlCache[trimmed];
    if (cachedEntry != null && !cachedEntry.isExpired) {
      return cachedEntry.url;
    }

    if (_state.downloadingCertifiedReportUuids.contains(trimmed)) {
      return '';
    }

    final downloading = Set<String>.from(_state.downloadingCertifiedReportUuids)
      ..add(trimmed);
    _state = _state.copyWith(downloadingCertifiedReportUuids: downloading);
    notifyListeners();

    try {
      final pdfUrl = await auditRepository.getCertifiedReportPdfUrl(
        certifiedReportUuid: trimmed,
      );
      if (pdfUrl.trim().isNotEmpty) {
        _certifiedReportPdfUrlCache[trimmed] = _CachedCertifiedReportPdfUrl(
          url: pdfUrl,
          expiresAt: DateTime.now().add(_certifiedReportPdfUrlCacheTtl),
        );
      }
      return pdfUrl;
    } catch (error) {
      debugPrint('Unable to download certified report PDF: $error');
      return '';
    } finally {
      final updated = Set<String>.from(_state.downloadingCertifiedReportUuids)
        ..remove(trimmed);
      _state = _state.copyWith(downloadingCertifiedReportUuids: updated);
      notifyListeners();
    }
  }

  Future<String> certifyPerformanceReport() async {
    final currentReport = _state.performanceReport;
    if (currentReport == null) {
      return 'Performance report is not available right now.';
    }

    final hasEmployeeSignature =
        _state.employeeSignatureBytes != null ||
        (_state.employeeSignatureImageId?.trim().isNotEmpty ?? false) ||
        (currentReport.selectedProfileSignatureUuid?.trim().isNotEmpty ??
            false);
    final hasFacilitatorSignature = _state.facilitatorSignatureBytes != null;

    if (!hasEmployeeSignature || !hasFacilitatorSignature) {
      return 'Employee and Facilitator signatures are required before certifying.';
    }

    final employeeSignatureUuid =
        (_state.employeeSignatureImageId?.trim().isNotEmpty ?? false)
        ? _state.employeeSignatureImageId!.trim()
        : currentReport.selectedProfileSignatureUuid?.trim() ?? '';
    if (employeeSignatureUuid.isEmpty) {
      return 'Employee signature UUID is missing from the report data.';
    }

    if (_state.isFacilitatorSignatureUploading) {
      return 'Facilitator signature is still uploading. Please wait a moment.';
    }

    final facilitatorSignatureUuid =
        _state.facilitatorSignatureImageId?.trim() ?? '';
    if (facilitatorSignatureUuid.isEmpty) {
      return 'Facilitator signature upload is required before certifying.';
    }

    final auditRepository = _auditRepository;
    if (auditRepository == null) {
      return 'Unable to certify the performance report right now.';
    }

    final commitmentComment = _state.performanceReportCommitment.trim();

    _state = _state.copyWith(isAuditActionLoading: true);
    notifyListeners();

    try {
      final isCustomRange =
          _state.performanceReportTimeRange == 'Custom Date Range' &&
          _state.performanceReportStartDate != null &&
          _state.performanceReportEndDate != null;
      final currentYearQuarter = CustomFunctions.currentYearQuarter();
      final reportSnapshot = _applyRemarksToReportSnapshot(
        currentReport.reportSnapshot,
        _collectRemarksByDescription(currentReport.categoryTabs),
      );

      final payload = <String, dynamic>{
        'profile_uuid': currentReport.profile.profileUuid,
        'filter_type': isCustomRange ? 'custom_range' : 'quarter',
        'report_snapshot': {'overview': reportSnapshot},
        'commitment_comment': commitmentComment,
        'employee_signature_uuid': employeeSignatureUuid,
        'facilitator_signature_uuid': facilitatorSignatureUuid,
        if (isCustomRange) ...{
          'start': CustomFunctions.apiDateString(
            date: _state.performanceReportStartDate!,
          ),
          'end': CustomFunctions.apiDateString(
            date: _state.performanceReportEndDate!,
          ),
        } else ...{
          'quarter': currentYearQuarter.quarter.toString(),
          'year': currentYearQuarter.year,
        },
      };

      final certifiedReportUuid = await auditRepository
          .certifyPerformanceReport(
            profileJobId: currentReport.profile.profileJob,
            payload: payload,
          );
      final certifiedReports = await _loadCertifiedReportsForPerformanceReport(
        auditRepository: auditRepository,
        profile: currentReport.profile,
        report: currentReport,
        startDate: isCustomRange ? _state.performanceReportStartDate : null,
        endDate: isCustomRange ? _state.performanceReportEndDate : null,
        year: isCustomRange ? null : currentYearQuarter.year,
        quarter: isCustomRange ? null : currentYearQuarter.quarter,
      );

      if (certifiedReportUuid != null &&
          certifiedReportUuid.trim().isNotEmpty) {
        final detail = await auditRepository.getCertifiedReportDetail(
          certifiedReportUuid: certifiedReportUuid.trim(),
          fallbackProfile: currentReport.profile,
        );
        _state = _state.copyWith(
          performanceReport: detail.report,
          performanceReportCommitment: detail.commitmentComment,
          certifiedReportOptions: certifiedReports,
          selectedCertifiedReportUuid: certifiedReportUuid.trim(),
        );
      } else {
        final user = await AppPreference.getUser();
        _state = _state.copyWith(
          performanceReport: PerformanceReport(
            profile: currentReport.profile,
            createdAt: currentReport.createdAt,
            personalityAvatarImagePath:
                currentReport.personalityAvatarImagePath,
            hasPersonalityData: currentReport.hasPersonalityData,
            isCertified: true,
            certifiedAt: DateTime.now().millisecondsSinceEpoch.toString(),
            employeeSignatureName:
                currentReport.employeeSignatureName ??
                currentReport.profile.name,
            selectedProfileSignatureUuid:
                currentReport.selectedProfileSignatureUuid,
            selectedProfileSignatureUrl:
                currentReport.selectedProfileSignatureUrl,
            facilitatorSignatureUrl: currentReport.facilitatorSignatureUrl,
            facilitatorName: user?.name ?? currentReport.facilitatorName,
            reportSnapshot: reportSnapshot,
            rawPersonalityDescription: currentReport.rawPersonalityDescription,
            overallPerformanceScore: currentReport.overallPerformanceScore,
            confidenceLevel: currentReport.confidenceLevel,
            archetypeTitle: currentReport.archetypeTitle,
            archetypeSubtitle: currentReport.archetypeSubtitle,
            archetypeSummary: currentReport.archetypeSummary,
            guidanceParagraphs: currentReport.guidanceParagraphs,
            categoryTabs: currentReport.categoryTabs,
            selectedCategoryIndex: currentReport.selectedCategoryIndex,
            ratingRows: currentReport.ratingRows,
            paygradePipeline: currentReport.paygradePipeline,
            currentPaygrade: currentReport.currentPaygrade,
            paygradeUnit: currentReport.paygradeUnit,
            coreValues: currentReport.coreValues,
            remarkVersion: currentReport.remarkVersion,
          ),
          certifiedReportOptions: certifiedReports,
        );
      }
      return 'Performance report certified successfully.';
    } catch (error) {
      debugPrint('Unable to certify performance report: $error');
      return 'Unable to certify performance report right now. Please try again.';
    } finally {
      _state = _state.copyWith(isAuditActionLoading: false);
      notifyListeners();
    }
  }

  void _setFavoriteUpdating(String profileJobId, bool isUpdating) {
    final updatedProfileJobs = Set<String>.from(
      _state.favoriteUpdatingProfileJobs,
    );
    if (isUpdating) {
      updatedProfileJobs.add(profileJobId);
    } else {
      updatedProfileJobs.remove(profileJobId);
    }

    _state = _state.copyWith(favoriteUpdatingProfileJobs: updatedProfileJobs);
    notifyListeners();
  }

  int _resolvedTeamMembersPageSize() {
    final currentCount = _state.mainList?.results.length ?? 0;
    return currentCount > 0 ? currentCount : 10;
  }

  void _scheduleMainListSearchRefresh({bool immediate = false}) {
    _mainListSearchDebounceTimer?.cancel();

    if (immediate) {
      unawaited(_runDebouncedMainListSearchRefresh());
      return;
    }

    _mainListSearchDebounceTimer = Timer(_mainListSearchDebounceDuration, () {
      unawaited(_runDebouncedMainListSearchRefresh());
    });
  }

  Future<void> _runDebouncedMainListSearchRefresh() async {
    if (_state.isLoading || _state.isLoadingMore) {
      _hasPendingMainListSearchRefresh = true;
      return;
    }

    _hasPendingMainListSearchRefresh = false;
    await _refreshMainListSearchResults(showLoader: true);
  }

  Future<void> _refreshMainListSearchResults({
    required bool showLoader,
    bool forceRefresh = false,
  }) async {
    final requestKey = _mainListRequestKey;
    _clearMainListCaches();

    _state = _state.copyWith(isLoading: showLoader, isLoadingMore: false);
    notifyListeners();

    try {
      final mainList = await _loadListForSelectedStatus(
        page: 1,
        pageSize: 12,
        forceRefresh: forceRefresh,
      );
      if (_isDisposed) {
        return;
      }
      if (requestKey != _mainListRequestKey) {
        _state = _state.copyWith(isLoading: false, isLoadingMore: false);
        notifyListeners();
        return;
      }

      _cacheMainList(
        _state.selectedStatus,
        mainList,
        updateDefaultCache: !_hasMainListSearchQuery(),
      );
      _state = _state.copyWith(
        isLoading: false,
        isLoadingMore: false,
        mainList: mainList,
      );
      notifyListeners();
    } catch (error) {
      if (_isDisposed) {
        return;
      }
      if (requestKey != _mainListRequestKey) {
        _state = _state.copyWith(isLoading: false, isLoadingMore: false);
        notifyListeners();
        return;
      }

      _state = _state.copyWith(isLoading: false, isLoadingMore: false);
      notifyListeners();
      _logRecoverableError('refreshMainListSearchResults', error);
    } finally {
      if (!_isDisposed) {
        _flushPendingMainListSearchRefresh();
      }
    }
  }

  void _flushPendingMainListSearchRefresh() {
    if (!_hasPendingMainListSearchRefresh ||
        _state.isLoading ||
        _state.isLoadingMore) {
      return;
    }

    _hasPendingMainListSearchRefresh = false;
    _scheduleMainListSearchRefresh(immediate: true);
  }

  void _resetMainListSearchState() {
    _mainListSearchDebounceTimer?.cancel();
    _hasPendingMainListSearchRefresh = false;
  }

  void _cancelPendingMainListSearchRefresh() {
    _mainListSearchDebounceTimer?.cancel();
    _hasPendingMainListSearchRefresh = false;
  }

  String get _mainListRequestKey {
    return '${_state.selectedStatus.name}|${_state.searchQuery.trim()}|'
        '$selectedAuditYear|$selectedAuditQuarter|$_selectedSeatProfileJobUuid';
  }

  void _scheduleTeamMembersSearchRefresh({bool immediate = false}) {
    _teamMembersSearchDebounceTimer?.cancel();

    if (immediate) {
      unawaited(_runDebouncedTeamMembersSearchRefresh());
      return;
    }

    _teamMembersSearchDebounceTimer = Timer(
      _teamMembersSearchDebounceDuration,
      () {
        unawaited(_runDebouncedTeamMembersSearchRefresh());
      },
    );
  }

  Future<void> _runDebouncedTeamMembersSearchRefresh() async {
    if (_state.isLoading || _state.isLoadingMore) {
      _hasPendingTeamMembersSearchRefresh = true;
      return;
    }

    _hasPendingTeamMembersSearchRefresh = false;
    await _refreshTeamMembersSearchResults(showLoader: true);
  }

  Future<void> _refreshTeamMembersSearchResults({
    required bool showLoader,
  }) async {
    _activeMainListCache = null;

    _state = _state.copyWith(isLoading: showLoader, isLoadingMore: false);
    notifyListeners();

    try {
      final mainList = await _loadTeamMembers(
        page: 1,
        pageSize: _teamMembersScreenPageSize,
        search: _teamMembersSearchQuery,
      );
      final sortedMainList = _sortedMainList(mainList) ?? mainList;
      _cacheList(AuditMemberStatus.active, sortedMainList);

      _state = _state.copyWith(
        isLoading: false,
        isLoadingMore: false,
        mainList: sortedMainList,
      );
      notifyListeners();
    } catch (error) {
      _state = _state.copyWith(isLoading: false, isLoadingMore: false);
      notifyListeners();
      _logRecoverableError('refreshTeamMembersSearchResults', error);
    } finally {
      _flushPendingTeamMembersSearchRefresh();
    }
  }

  void _flushPendingTeamMembersSearchRefresh() {
    if (!_hasPendingTeamMembersSearchRefresh ||
        _state.isLoading ||
        _state.isLoadingMore) {
      return;
    }

    _hasPendingTeamMembersSearchRefresh = false;
    _scheduleTeamMembersSearchRefresh(immediate: true);
  }

  void _resetTeamMembersSearchState() {
    _teamMembersSearchDebounceTimer?.cancel();
    _teamMembersSearchQuery = '';
    _hasPendingTeamMembersSearchRefresh = false;
  }

  Future<List<CertifiedReportOption>>
  _loadCertifiedReportsForPerformanceReport({
    required AuditRepository auditRepository,
    required AuditProfile profile,
    PerformanceReport? report,
    int? year,
    int? quarter,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final normalizedProfileUuid = _normalizeProfileUuid(profile.profileUuid);
    if (normalizedProfileUuid == null ||
        (report != null && _isOpenSeatPerformanceReport(report))) {
      return const <CertifiedReportOption>[];
    }

    try {
      return await auditRepository.getCertifiedReports(
        profile: profile,
        year: year,
        quarter: quarter,
        startDate: startDate,
        endDate: endDate,
      );
    } catch (error) {
      debugPrint(
        'Unable to load certified reports for performance report: $error',
      );
      return const <CertifiedReportOption>[];
    }
  }

  String? _normalizeProfileUuid(String? profileUuid) {
    final trimmedProfileUuid = profileUuid?.trim();
    if (trimmedProfileUuid == null ||
        trimmedProfileUuid.isEmpty ||
        trimmedProfileUuid.toLowerCase() == 'null') {
      return null;
    }

    return trimmedProfileUuid;
  }

  bool _isOpenSeatPerformanceReport(PerformanceReport report) {
    final selectedProfilePayload = report.reportSnapshot['selected_profile'];
    final hasSelectedProfile = selectedProfilePayload is Map<String, dynamic>
        ? selectedProfilePayload.isNotEmpty
        : selectedProfilePayload != null;

    return !hasSelectedProfile && report.profile.profiles.isEmpty;
  }

  bool _shouldUseOpenSeatFallback(ApiError error) {
    return error.message.trim().toLowerCase() == 'profile uuid is not valid.';
  }

  PerformanceReport _buildOpenSeatPerformanceReport(AuditProfile profile) {
    final openSeatProfile = AuditProfile(
      uuid: profile.uuid,
      profileJob: profile.profileJob,
      profileUuid: '',
      email: '',
      imageUrl: null,
      isFavorite: profile.isFavorite,
      lastAuditDates: profile.lastAuditDates,
      roleTitle: profile.roleTitle,
      name: AppStrings.noProfile,
      lastAuditLabel: profile.lastAuditLabel,
      yearQuarter: profile.yearQuarter,
      seatProfile: 'Open Seat',
      overallScore: profile.overallScore,
      confidenceLevel: profile.confidenceLevel,
      status: profile.status,
      reviewerInitials: profile.reviewerInitials,
      avatarLabel: 'N',
      profiles: const <AuditMemberProfile>[],
      avatarImageUrl: null,
    );

    return PerformanceReport(
      profile: openSeatProfile,
      personalityAvatarImagePath: null,
      hasPersonalityData: false,
      isCertified: false,
      certifiedAt: null,
      employeeSignatureName: null,
      selectedProfileSignatureUuid: null,
      selectedProfileSignatureUrl: null,
      facilitatorSignatureUrl: null,
      facilitatorName: null,
      reportSnapshot: const <String, dynamic>{
        'selected_profile': null,
        'profiles': <dynamic>[],
        'categories': <dynamic>[],
        'message': 'No profile is assigned to this seat yet.',
      },
      rawPersonalityDescription: '',
      overallPerformanceScore: profile.overallScore,
      confidenceLevel: profile.confidenceLevel.toDouble(),
      archetypeTitle: 'Performance Overview',
      archetypeSubtitle: profile.roleTitle,
      archetypeSummary: '',
      guidanceParagraphs: const <String>[],
      categoryTabs: const <PerformanceReportCategoryTab>[],
      selectedCategoryIndex: 0,
      ratingRows: const <PerformanceReportRatingRow>[],
      paygradePipeline: const <PerformanceReportPaygradeStep>[],
      currentPaygrade: '--',
      paygradeUnit: '--',
      coreValues: const <PerformanceReportCoreValue>[],
      remarkVersion: 0,
    );
  }

  Future<AuditMainList> _loadListForSelectedStatus({
    required int page,
    required int pageSize,
    String? search,
    bool forceRefresh = false,
  }) {
    final resolvedSearch = search ?? _state.searchQuery;
    if (!_state.isActualOwner &&
        _state.selectedStatus == AuditMemberStatus.deactivated) {
      return _loadMyCheckIns(
        page: page,
        pageSize: pageSize,
        search: resolvedSearch,
        forceRefresh: forceRefresh,
      );
    }

    return _loadTeamMembers(
      page: page,
      pageSize: pageSize,
      search: resolvedSearch,
      forceRefresh: forceRefresh,
    );
  }

  Future<AuditMainList> _preloadNonOwnerLists({
    required int page,
    required int pageSize,
  }) async {
    final results = await Future.wait<AuditMainList>(<Future<AuditMainList>>[
      _loadTeamMembers(
        page: page,
        pageSize: pageSize,
        search: _state.searchQuery,
      ),
      _loadMyCheckIns(
        page: page,
        pageSize: pageSize,
        search: _state.searchQuery,
      ),
    ]);

    _cacheMainList(
      AuditMemberStatus.active,
      results[0],
      updateDefaultCache: true,
    );
    _cacheMainList(
      AuditMemberStatus.deactivated,
      results[1],
      updateDefaultCache: true,
    );

    return _state.selectedStatus == AuditMemberStatus.deactivated
        ? results[1]
        : results[0];
  }

  Future<AuditMainList> _loadTeamMembers({
    required int page,
    required int pageSize,
    String? search,
    bool forceRefresh = false,
  }) {
    final trimmedSearch = search?.trim();
    return _getAuditOverviewUseCase(
      page: page,
      pageSize: pageSize,
      year: selectedAuditYear,
      quarter: selectedAuditQuarter,
      search: trimmedSearch == null || trimmedSearch.isEmpty
          ? null
          : trimmedSearch,
      jobUuid: _selectedSeatProfileJobUuid,
      forceRefresh: forceRefresh,
    );
  }

  Future<AuditMainList> _loadMyCheckIns({
    required int page,
    required int pageSize,
    String? search,
    bool forceRefresh = false,
  }) {
    final auditRepository = _auditRepository;
    if (auditRepository == null) {
      return _loadTeamMembers(
        page: page,
        pageSize: pageSize,
        search: search,
        forceRefresh: forceRefresh,
      );
    }

    return auditRepository.getMyAudits(
      page: page,
      pageSize: pageSize,
      year: selectedAuditYear,
      quarter: selectedAuditQuarter,
      search: search,
      forceRefresh: forceRefresh,
    );
  }

  Future<void> _reloadAuditPeriod({int? year, int? quarter}) async {
    final resolvedYear = year ?? selectedAuditYear;
    final resolvedQuarter = quarter ?? selectedAuditQuarter;
    if (resolvedYear == selectedAuditYear &&
        resolvedQuarter == selectedAuditQuarter) {
      return;
    }

    _cancelPendingMainListSearchRefresh();
    _clearMainListCaches(clearDefaultCaches: true);

    _state = _state.copyWith(
      selectedAuditYear: resolvedYear,
      selectedAuditQuarter: resolvedQuarter,
      isLoading: true,
      isLoadingMore: false,
      clearMainList: true,
      clearSelectedYearQuarter: true,
    );
    notifyListeners();

    final mainList = await _loadListForSelectedStatus(page: 1, pageSize: 12);
    _cacheMainList(
      _state.selectedStatus,
      mainList,
      updateDefaultCache: !_hasMainListSearchQuery(),
    );
    _state = _state.copyWith(isLoading: false, mainList: mainList);
    notifyListeners();
  }

  AuditMainList? _cachedListFor(AuditMemberStatus status) {
    return status == AuditMemberStatus.deactivated
        ? _myCheckInMainListCache
        : _activeMainListCache;
  }

  AuditMainList? _defaultCachedListFor(AuditMemberStatus status) {
    return status == AuditMemberStatus.deactivated
        ? _defaultMyCheckInMainListCache
        : _defaultActiveMainListCache;
  }

  void _cacheMainList(
    AuditMemberStatus status,
    AuditMainList list, {
    bool updateDefaultCache = false,
  }) {
    _cacheList(status, list);
    if (!updateDefaultCache) {
      return;
    }

    if (status == AuditMemberStatus.deactivated) {
      _defaultMyCheckInMainListCache = list;
      return;
    }

    _defaultActiveMainListCache = list;
  }

  void _cacheList(AuditMemberStatus status, AuditMainList list) {
    if (status == AuditMemberStatus.deactivated) {
      _myCheckInMainListCache = list;
      return;
    }

    _activeMainListCache = list;
  }

  AuditMainList? _restoreDefaultMainListCaches() {
    _activeMainListCache = _defaultActiveMainListCache;
    _myCheckInMainListCache = _defaultMyCheckInMainListCache;
    return _defaultCachedListFor(_state.selectedStatus);
  }

  void _clearMainListCaches({bool clearDefaultCaches = false}) {
    _activeMainListCache = null;
    _myCheckInMainListCache = null;
    if (!clearDefaultCaches) {
      return;
    }

    _defaultActiveMainListCache = null;
    _defaultMyCheckInMainListCache = null;
  }

  bool _hasMainListSearchQuery([String? query]) {
    return (query ?? _state.searchQuery).trim().isNotEmpty;
  }

  _ParsedYearQuarter? _parseYearQuarterLabel(String value) {
    final parts = value.split('-');
    if (parts.length < 2) {
      return null;
    }

    final year = int.tryParse(parts.first.trim());
    final quarter = int.tryParse(
      parts.last.trim().toUpperCase().replaceFirst('Q', ''),
    );
    if (year == null || quarter == null) {
      return null;
    }

    return _ParsedYearQuarter(year: year, quarter: quarter);
  }

  AuditMainList? _sortedMainList(AuditMainList? mainList) {
    if (mainList == null) {
      return null;
    }

    final sortedResults = [...mainList.results]
      ..sort((left, right) {
        if (left.isFavorite == right.isFavorite) {
          return left.name.toLowerCase().compareTo(right.name.toLowerCase());
        }
        return left.isFavorite ? -1 : 1;
      });

    return AuditMainList(
      count: mainList.count,
      next: mainList.next,
      previous: mainList.previous,
      current: mainList.current,
      results: sortedResults,
    );
  }

  void _logRecoverableError(String operation, Object error) {
    debugPrint('CheckInController.$operation failed: $error');
  }

  bool _hasTeamMemberTabsAccess(User? user) {
    return AppPermissionUtils.canAccessAuditTeamMembers(user);
  }

  bool _isActualOwner(User? user) {
    return AppPermissionUtils.hasOwnerOverrideAccess(user);
  }

  bool _isSelfAudit(AuditDetails details, User? user) {
    final currentProfileUuid = user?.uuid?.trim() ?? '';
    if (currentProfileUuid.isEmpty) {
      return false;
    }

    return details.profileUuid.trim() == currentProfileUuid ||
        details.profiles.any(
          (profile) => profile.uuid.trim() == currentProfileUuid,
        );
  }

  @override
  void dispose() {
    _isDisposed = true;
    _mainListSearchDebounceTimer?.cancel();
    _teamMembersSearchDebounceTimer?.cancel();
    descriptionSearchController.dispose();
    super.dispose();
  }

  PerformanceReportCoreValueVisualSpec _coreValueVisualSpecFromConfig(
    _PerformanceReportCoreValueIconConfig config, {
    Color? accentColor,
  }) {
    return PerformanceReportCoreValueVisualSpec(
      key: config.key,
      label: config.label,
      icon: config.icon,
      color: accentColor ?? config.color,
    );
  }

  Color? _resolveCoreValueAccentColor(PerformanceReportCoreValue coreValue) {
    final rawColorValue = _firstNonEmptyCoreValueString(<String?>[
      coreValue.colorHex,
      coreValue.rawData['color_hex']?.toString(),
      coreValue.rawData['colorHex']?.toString(),
      coreValue.rawData['hex_color']?.toString(),
      coreValue.rawData['hexCode']?.toString(),
      coreValue.rawData['hex_code']?.toString(),
    ]);
    final normalizedHex = _normalizeCoreValueHex(rawColorValue);
    if (!_isValidCoreValueHex(normalizedHex)) {
      return null;
    }

    final raw = normalizedHex.substring(1);
    return Color(int.parse(raw, radix: 16) | 0xFF000000);
  }

  String _normalizeCoreValueHex(String? value) {
    final cleaned = value?.trim().toUpperCase().replaceAll(' ', '') ?? '';
    if (cleaned.isEmpty) {
      return '';
    }

    var raw = cleaned;
    if (raw.startsWith('#')) {
      raw = raw.substring(1);
    }
    if (raw.startsWith('0X')) {
      raw = raw.substring(2);
    }
    if (raw.length == 3) {
      raw = raw.split('').map((segment) => '$segment$segment').join();
    } else if (raw.length == 8) {
      raw = raw.substring(2);
    }

    if (raw.isEmpty) {
      return '';
    }

    return '#$raw';
  }

  bool _isValidCoreValueHex(String value) {
    return RegExp(r'^#[0-9A-F]{6}$').hasMatch(value);
  }

  String? _firstNonEmptyCoreValueString(List<String?> values) {
    for (final value in values) {
      final normalizedValue = value?.trim() ?? '';
      if (normalizedValue.isNotEmpty) {
        return value;
      }
    }

    return null;
  }

  int _stableCoreValueIconIndex(String title) {
    final normalizedTitle = title.trim();
    if (normalizedTitle.isEmpty) {
      return 0;
    }

    final seed = normalizedTitle.runes.fold<int>(
      0,
      (currentValue, rune) => currentValue + rune,
    );
    return seed % _performanceReportCoreValueIconConfigs.length;
  }
}

class PerformanceReportViewData {
  const PerformanceReportViewData({
    required this.categorySelectionKey,
    required this.maxCategoryIndex,
    required this.reportMessage,
    required this.isOpenSeatView,
    required this.shouldShowCompleteReportUi,
    required this.shouldShowMessageOnly,
    required this.currentPaygradeStep,
  });

  final String categorySelectionKey;
  final int maxCategoryIndex;
  final String? reportMessage;
  final bool isOpenSeatView;
  final bool shouldShowCompleteReportUi;
  final bool shouldShowMessageOnly;
  final PerformanceReportPaygradeStep? currentPaygradeStep;
}

class PerformanceReportCoreValueVisualSpec {
  const PerformanceReportCoreValueVisualSpec({
    required this.key,
    required this.label,
    required this.icon,
    required this.color,
  });

  final String key;
  final String label;
  final IconData icon;
  final Color color;
}

class _PerformanceReportCoreValueIconConfig {
  const _PerformanceReportCoreValueIconConfig({
    required this.key,
    required this.label,
    required this.icon,
    required this.color,
    required this.keywords,
  });

  final String key;
  final String label;
  final IconData icon;
  final Color color;
  final List<String> keywords;
}

const List<_PerformanceReportCoreValueIconConfig>
_performanceReportCoreValueIconConfigs =
    <_PerformanceReportCoreValueIconConfig>[
      _PerformanceReportCoreValueIconConfig(
        key: 'target',
        label: 'Target',
        icon: Icons.gps_fixed_outlined,
        color: AppColors.hex18c4e8,
        keywords: <String>['target', 'customer', 'customer first', 'focus'],
      ),
      _PerformanceReportCoreValueIconConfig(
        key: 'shield',
        label: 'Shield',
        icon: Icons.shield_outlined,
        color: AppColors.hexb65cff,
        keywords: <String>['shield', 'secure', 'safety', 'protection'],
      ),
      _PerformanceReportCoreValueIconConfig(
        key: 'users',
        label: 'People',
        icon: Icons.groups_outlined,
        color: AppColors.hex1ed9c8,
        keywords: <String>['users', 'people', 'customer care', 'professional'],
      ),
      _PerformanceReportCoreValueIconConfig(
        key: 'lightbulb',
        label: 'Innovation',
        icon: Icons.lightbulb_outlined,
        color: AppColors.hex14c7f3,
        keywords: <String>['lightbulb', 'innovation', 'creative', 'idea'],
      ),
      _PerformanceReportCoreValueIconConfig(
        key: 'handshake',
        label: 'Teamwork',
        icon: Icons.handshake_outlined,
        color: AppColors.hexf08a24,
        keywords: <String>['handshake', 'teamwork', 'team', 'collaboration'],
      ),
      _PerformanceReportCoreValueIconConfig(
        key: 'scale',
        label: 'Integrity',
        icon: Icons.balance_outlined,
        color: AppColors.hexb96cff,
        keywords: <String>['scale', 'integrity', 'ethics', 'honesty'],
      ),
      _PerformanceReportCoreValueIconConfig(
        key: 'award',
        label: 'Excellence',
        icon: Icons.emoji_events_outlined,
        color: AppColors.hexff5e33,
        keywords: <String>['award', 'excellence', 'superb', 'memorable'],
      ),
      _PerformanceReportCoreValueIconConfig(
        key: 'trending_up',
        label: 'Growth',
        icon: Icons.trending_up_outlined,
        color: AppColors.hex4dd17f,
        keywords: <String>['trending_up', 'growth', 'improve', 'learning'],
      ),
      _PerformanceReportCoreValueIconConfig(
        key: 'heart',
        label: 'Care',
        icon: Icons.favorite_border_outlined,
        color: AppColors.hexf46aa8,
        keywords: <String>['heart', 'care', 'compassion', 'empathy'],
      ),
      _PerformanceReportCoreValueIconConfig(
        key: 'check_circle',
        label: 'Accountability',
        icon: Icons.check_circle_outline_outlined,
        color: AppColors.hex2ea8ff,
        keywords: <String>[
          'check_circle',
          'accountability',
          'ownership',
          'responsibility',
        ],
      ),
    ];

AuditRemoteDataSource createAuditRemoteDataSource() => AuditRemoteDataSource();

AuditRepositoryImpl createAuditRepository(
  AuditRemoteDataSource remoteDataSource,
) {
  return AuditRepositoryImpl(remoteDataSource);
}

GetAuditOverviewUseCase createGetAuditOverviewUseCase(
  AuditRepositoryImpl repository,
) {
  return GetAuditOverviewUseCase(repository);
}

GetAuditDetailsUseCase createGetAuditDetailsUseCase(
  AuditRepositoryImpl repository,
) {
  return GetAuditDetailsUseCase(repository);
}

GetAuditEvaluationChartUseCase createGetAuditEvaluationChartUseCase(
  AuditRepositoryImpl repository,
) {
  return GetAuditEvaluationChartUseCase(repository);
}

GetQuarterlyAuditUseCase createGetQuarterlyAuditUseCase(
  AuditRepositoryImpl repository,
) {
  return GetQuarterlyAuditUseCase(repository);
}

MarkFavoriteSubordinateUseCase createMarkFavoriteSubordinateUseCase(
  AuditRepositoryImpl repository,
) {
  return MarkFavoriteSubordinateUseCase(repository);
}

MarkUnfavoriteSubordinateUseCase createMarkUnfavoriteSubordinateUseCase(
  AuditRepositoryImpl repository,
) {
  return MarkUnfavoriteSubordinateUseCase(repository);
}

GetAuditTeamMembersUseCase createGetAuditTeamMembersUseCase(
  AuditRepositoryImpl repository,
) {
  return GetAuditTeamMembersUseCase(repository);
}

class _CachedCertifiedReportPdfUrl {
  const _CachedCertifiedReportPdfUrl({
    required this.url,
    required this.expiresAt,
  });

  final String url;
  final DateTime expiresAt;

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}

class _ParsedYearQuarter {
  const _ParsedYearQuarter({required this.year, required this.quarter});

  final int year;
  final int quarter;
}
