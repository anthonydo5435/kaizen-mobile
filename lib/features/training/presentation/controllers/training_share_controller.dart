import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/managers/app_manager.dart';
import '../../domain/entities/lms_public_link.dart';
import '../../domain/entities/seat_description_training.dart';
import '../../domain/repositories/training_library_repository.dart';

class TrainingShareController extends ChangeNotifier {
  TrainingShareController(
    this._repository, {
    required this.seatProfileId,
    required this.descriptionId,
    Iterable<SeatDescriptionTrainingModule> lessons = const [],
  }) {
    _setLessons(lessons);
  }

  void _setLessons(Iterable<SeatDescriptionTrainingModule> lessons) {
    final uniqueLessons = <String, SeatDescriptionTrainingModule>{};
    for (final lesson in lessons) {
      final id = lesson.uuid.trim();
      if (id.isNotEmpty) uniqueLessons.putIfAbsent(id, () => lesson);
    }
    _lessons = List.unmodifiable(uniqueLessons.values);
    _selectedIds.clear();
    _selectedIds.addAll(uniqueLessons.keys);
  }

  final TrainingLibraryRepository _repository;
  final String seatProfileId;
  final String descriptionId;
  late List<SeatDescriptionTrainingModule> _lessons;
  final Set<String> _selectedIds = {};
  LmsPublicLink? _publicLink;
  String? _errorMessage;
  bool _isWorking = false;
  bool _isLoading = false;
  bool _hasLoaded = false;
  bool _isDisposed = false;

  List<SeatDescriptionTrainingModule> get lessons => _lessons;
  String? get link => _publicLink?.url;
  String? get errorMessage => _errorMessage;
  bool get isWorking => _isWorking;
  bool get isLoading => _isLoading;
  bool get hasLoaded => _hasLoaded;
  int get selectedCount => _selectedIds.length;
  bool get allSelected => lessons.isNotEmpty && selectedCount == lessons.length;
  bool isSelected(String id) => _selectedIds.contains(id.trim());
  bool get canManage =>
      descriptionId.trim().isNotEmpty &&
      seatProfileId.trim().isNotEmpty &&
      AppManager.instance.currentUserCanManagePublicLinks;
  bool get canSelect =>
      canManage &&
      _hasLoaded &&
      !_isLoading &&
      !_isWorking &&
      _publicLink == null;
  bool get canCreate => canSelect && _selectedIds.isNotEmpty;
  bool get canRevoke =>
      canManage &&
      _hasLoaded &&
      !_isLoading &&
      !_isWorking &&
      _publicLink != null;

  void prepareLessons(Iterable<SeatDescriptionTrainingModule> lessons) {
    if (_isDisposed || _isWorking) return;
    _setLessons(lessons);
    notifyListeners();
  }

  Future<void> loadLink() async {
    if (_isDisposed || _isLoading || _isWorking || !canManage) return;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final result = await _repository.getLmsPublicLink(descriptionId.trim());
      if (_isDisposed) return;
      _publicLink = result;
      _hasLoaded = true;
    } catch (_) {
      if (_isDisposed) return;
      _hasLoaded = false;
      _errorMessage = AppStrings.shareLoadLinkFailed;
    } finally {
      if (!_isDisposed) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  void selectAll(bool selected) {
    if (_isDisposed || !canSelect) return;
    _selectedIds.clear();
    if (selected) {
      _selectedIds.addAll(lessons.map((lesson) => lesson.uuid.trim()));
    }
    _errorMessage = null;
    notifyListeners();
  }

  void selectLesson(String id, bool selected) {
    final resolvedId = id.trim();
    if (_isDisposed ||
        !canSelect ||
        !lessons.any((lesson) => lesson.uuid.trim() == resolvedId)) {
      return;
    }
    if (selected) {
      _selectedIds.add(resolvedId);
    } else {
      _selectedIds.remove(resolvedId);
    }
    _errorMessage = null;
    notifyListeners();
  }

  Future<void> createLink() async {
    if (_isDisposed || !canCreate) return;
    _isWorking = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final result = await _repository.createLmsPublicLink(
        descriptionId: descriptionId.trim(),
        trainingModuleUuids: lessons
            .map((lesson) => lesson.uuid.trim())
            .where(_selectedIds.contains)
            .toList(growable: false),
      );
      if (!_isDisposed) _publicLink = result;
    } catch (_) {
      if (!_isDisposed) _errorMessage = AppStrings.shareCreateLinkFailed;
    } finally {
      if (!_isDisposed) {
        _isWorking = false;
        notifyListeners();
      }
    }
  }

  Future<bool> copyLink() async {
    final publicLink = link;
    if (_isDisposed ||
        publicLink == null ||
        _isLoading ||
        _isWorking ||
        !canManage) {
      return false;
    }
    try {
      await Clipboard.setData(ClipboardData(text: publicLink));
      return true;
    } catch (_) {
      if (!_isDisposed) {
        _errorMessage = AppStrings.shareCopyLinkFailed;
        notifyListeners();
      }
      return false;
    }
  }

  Future<void> revokeLink() async {
    if (_isDisposed || !canRevoke) return;
    _isWorking = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await _repository.deleteLmsPublicLink(descriptionId.trim());
      if (_isDisposed) return;
      _publicLink = null;
      _setLessons(_lessons);
    } catch (_) {
      if (!_isDisposed) _errorMessage = AppStrings.shareRevokeLinkFailed;
    } finally {
      if (!_isDisposed) {
        _isWorking = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }
}
