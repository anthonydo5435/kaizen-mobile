import 'package:flutter/material.dart';

import '../../../../core/constants/app_strings.dart';
import '../../domain/entities/shared_lms_content.dart';
import '../../domain/repositories/shared_lms_repository.dart';

class SharedLmsController extends ChangeNotifier {
  SharedLmsController(this._repository);

  final SharedLmsRepository _repository;
  final TextEditingController searchController = TextEditingController();
  SharedLmsContent? _content;
  String? _errorMessage;
  String _searchQuery = '';
  String _publicId = '';
  bool _isLoading = false;
  bool _isDisposed = false;
  int _requestVersion = 0;

  SharedLmsContent? get content => _content;
  String get publicId => _publicId;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _isLoading;
  List<SharedLmsLesson> get visibleLessons {
    final lessons = _content?.lessons ?? const <SharedLmsLesson>[];
    if (_searchQuery.isEmpty) {
      return lessons;
    }
    return lessons
        .where((lesson) => lesson.title.toLowerCase().contains(_searchQuery))
        .toList(growable: false);
  }

  Future<void> load(String publicId) async {
    _publicId = publicId.trim();
    final requestVersion = ++_requestVersion;
    _isLoading = true;
    _errorMessage = null;
    _content = null;
    notifyListeners();

    if (_publicId.isEmpty) {
      _isLoading = false;
      _errorMessage = AppStrings.sharedLmsUnableToLoad;
      notifyListeners();
      return;
    }

    try {
      final content = await _repository.getSharedLms(_publicId);
      if (_isDisposed || requestVersion != _requestVersion) {
        return;
      }
      _content = content;
    } catch (_) {
      if (_isDisposed || requestVersion != _requestVersion) {
        return;
      }
      _errorMessage = AppStrings.sharedLmsUnableToLoad;
    } finally {
      if (!_isDisposed && requestVersion == _requestVersion) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  Future<void> retry() => load(_publicId);

  void updateSearchQuery(String value) {
    final query = value.trim().toLowerCase();
    if (query == _searchQuery) {
      return;
    }
    _searchQuery = query;
    notifyListeners();
  }

  void clearSearch() {
    searchController.clear();
    updateSearchQuery('');
  }

  @override
  void dispose() {
    _isDisposed = true;
    _requestVersion++;
    searchController.dispose();
    super.dispose();
  }
}
