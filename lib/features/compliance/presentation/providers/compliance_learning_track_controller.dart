import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/constants/app_strings.dart';
import '../../domain/entities/learning_module_detail_track.dart';
import '../../domain/usecases/get_compliance_overview_usecase.dart';

class ComplianceLearningTrackController extends ChangeNotifier {
  ComplianceLearningTrackController(this._getComplianceOverviewUseCase);

  static const Duration _searchDebounceDuration = Duration(milliseconds: 400);

  GetComplianceOverviewUseCase _getComplianceOverviewUseCase;
  final TextEditingController searchController = TextEditingController();

  List<LearningTrackModuleDetail> _tracks = const <LearningTrackModuleDetail>[];
  List<LearningTrackModuleDetail>? _searchResults;
  String _searchQuery = '';
  Set<String> _selectedSeatProfiles = <String>{};
  Timer? _searchDebounceTimer;
  int _searchRequestVersion = 0;
  bool _isSearchLoading = false;
  bool _isDisposed = false;
  String? _searchError;

  bool get isSearchLoading => _isSearchLoading;
  String? get searchError => _searchError;

  List<LearningTrackModuleDetail> get filteredTracks {
    final tracks = _searchQuery.isEmpty
        ? _tracks
        : _searchResults ?? const <LearningTrackModuleDetail>[];
    return tracks
        .where(
          (track) =>
              _selectedSeatProfiles.isEmpty ||
              _selectedSeatProfiles.contains(track.displayJob),
        )
        .toList();
  }

  List<String> get seatProfiles {
    final values = _tracks.map((track) => track.displayJob).toSet().toList();
    values.sort();
    return values;
  }

  Set<String> get selectedSeatProfiles =>
      Set<String>.unmodifiable(_selectedSeatProfiles);

  void updateDependencies(GetComplianceOverviewUseCase useCase) {
    _getComplianceOverviewUseCase = useCase;
  }

  void setTracks(List<LearningTrackModuleDetail> tracks) {
    _tracks = List<LearningTrackModuleDetail>.unmodifiable(tracks);
    notifyListeners();
  }

  void updateSearchQuery(String value) {
    final query = value.trim();
    if (_searchQuery == query) {
      return;
    }

    _searchDebounceTimer?.cancel();
    final requestVersion = ++_searchRequestVersion;
    _searchQuery = query;
    _searchResults = null;
    _searchError = null;
    _isSearchLoading = query.isNotEmpty;
    notifyListeners();

    if (query.isNotEmpty) {
      _searchDebounceTimer = Timer(_searchDebounceDuration, () {
        unawaited(_loadSearch(query, requestVersion, forceRefresh: true));
      });
    }
  }

  void clearSearch() {
    searchController.clear();
    updateSearchQuery('');
  }

  Future<void> refreshSearch({bool forceRefresh = false}) async {
    if (_isDisposed || _searchQuery.isEmpty) {
      return;
    }

    _searchDebounceTimer?.cancel();
    final requestVersion = ++_searchRequestVersion;
    _isSearchLoading = true;
    _searchError = null;
    notifyListeners();
    await _loadSearch(_searchQuery, requestVersion, forceRefresh: forceRefresh);
  }

  Future<void> _loadSearch(
    String query,
    int requestVersion, {
    bool forceRefresh = false,
  }) async {
    try {
      final overview = await _getComplianceOverviewUseCase(
        name: query,
        forceRefresh: forceRefresh,
      );
      if (_isDisposed || requestVersion != _searchRequestVersion) {
        return;
      }
      _searchResults = List<LearningTrackModuleDetail>.unmodifiable(
        overview.learningTracks,
      );
    } catch (_) {
      if (_isDisposed || requestVersion != _searchRequestVersion) {
        return;
      }
      _searchResults = const <LearningTrackModuleDetail>[];
      _searchError = AppStrings.complianceTrackSearchFailed;
    }

    _isSearchLoading = false;
    notifyListeners();
  }

  void updateSelectedSeatProfiles(Set<String> seatProfiles) {
    _selectedSeatProfiles = Set<String>.from(seatProfiles);
    notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _searchDebounceTimer?.cancel();
    _searchRequestVersion++;
    searchController.dispose();
    super.dispose();
  }
}
