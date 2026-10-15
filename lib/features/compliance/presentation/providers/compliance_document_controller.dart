import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/constants/app_strings.dart';
import '../../domain/entities/compliance_document.dart';
import '../../domain/usecases/get_compliance_documents_usecase.dart';

class ComplianceDocumentController extends ChangeNotifier {
  ComplianceDocumentController(this._getComplianceDocumentsUseCase);

  static const Duration _searchDebounceDuration = Duration(milliseconds: 400);

  final GetComplianceDocumentsUseCase _getComplianceDocumentsUseCase;
  final TextEditingController searchController = TextEditingController();

  bool _isLoading = false;
  List<ComplianceDocument> _documents = const <ComplianceDocument>[];
  List<ComplianceDocument>? _searchResults;
  String _searchQuery = '';
  Set<String> _selectedSeatProfiles = <String>{};
  bool _hasLoaded = false;
  Timer? _searchDebounceTimer;
  int _searchRequestVersion = 0;
  bool _isSearchLoading = false;
  bool _isDisposed = false;
  String? _searchError;

  bool get isLoading => _isLoading;
  bool get isSearchLoading => _isSearchLoading;
  String? get searchError => _searchError;

  List<ComplianceDocument> get filteredDocuments {
    final documents = _searchQuery.isEmpty
        ? _documents
        : _searchResults ?? const <ComplianceDocument>[];

    return documents.where((document) {
      final matchesSeatProfile =
          _selectedSeatProfiles.isEmpty ||
          document.seatProfiles.any(_selectedSeatProfiles.contains) ||
          (_selectedSeatProfiles.contains('All Jobs') &&
              document.seatProfiles.isEmpty);

      return matchesSeatProfile;
    }).toList();
  }

  List<String> get seatProfiles {
    final values = _documents
        .expand((document) => document.seatProfiles)
        .where((profile) => profile.trim().isNotEmpty)
        .toSet()
        .toList();
    values.sort();
    return values;
  }

  Set<String> get selectedSeatProfiles =>
      Set<String>.unmodifiable(_selectedSeatProfiles);

  Future<void> initialize({bool forceRefresh = false}) async {
    if (_isDisposed || _isLoading || (_hasLoaded && !forceRefresh)) {
      return;
    }

    _isLoading = true;
    notifyListeners();

    try {
      final documents = await _getComplianceDocumentsUseCase(
        forceRefresh: forceRefresh,
      );
      if (_isDisposed) {
        return;
      }
      _documents = List<ComplianceDocument>.unmodifiable(documents);
      _hasLoaded = true;
    } catch (_) {
      if (_isDisposed) {
        return;
      }
      _documents = const <ComplianceDocument>[];
      _hasLoaded = true;
    }

    _isLoading = false;
    notifyListeners();
    if (forceRefresh && _searchQuery.isNotEmpty) {
      await refreshSearch(forceRefresh: true);
    }
  }

  Future<void> refresh() {
    return initialize(forceRefresh: true);
  }

  void setDocuments(List<ComplianceDocument> documents) {
    _documents = List<ComplianceDocument>.unmodifiable(documents);
    _hasLoaded = true;
    notifyListeners();
  }

  void updateSearchQuery(String value) {
    final query = value.trim();
    if (_isDisposed || _searchQuery == query) {
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
      final documents = await _getComplianceDocumentsUseCase(
        name: query,
        forceRefresh: forceRefresh,
      );
      if (_isDisposed || requestVersion != _searchRequestVersion) {
        return;
      }
      _searchResults = List<ComplianceDocument>.unmodifiable(documents);
    } catch (_) {
      if (_isDisposed || requestVersion != _searchRequestVersion) {
        return;
      }
      _searchResults = const <ComplianceDocument>[];
      _searchError = AppStrings.complianceDocumentSearchFailed;
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
