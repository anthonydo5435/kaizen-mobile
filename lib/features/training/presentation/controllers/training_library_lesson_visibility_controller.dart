import 'package:flutter/foundation.dart';

import '../../../../core/constants/app_strings.dart';
import '../../domain/repositories/training_library_repository.dart';
import '../../domain/entities/training_library_module.dart';

class TrainingLibraryLessonVisibilityController extends ChangeNotifier {
  TrainingLibraryLessonVisibilityController(this._trainingRepository);

  final TrainingLibraryRepository _trainingRepository;
  final Map<String, bool> _visibilityOverrides = <String, bool>{};
  final Set<String> _updatingLessonIds = <String>{};
  final Map<String, bool> _pendingVisibility = {};
  final Map<String, String> _errors = {};

  bool get isUpdatingAnyLesson => _updatingLessonIds.isNotEmpty;

  bool? pendingVisibilityForLesson(String lessonId) =>
      _pendingVisibility[lessonId.trim()];
  String? errorForLesson(String lessonId) => _errors[lessonId.trim()];

  void clearError(String lessonId) {
    _errors.remove(lessonId.trim());
  }

  bool isLessonPubliclyAvailable(TrainingLibraryLesson lesson) {
    return _visibilityOverrides[lesson.id.trim()] ?? lesson.isPubliclyAvailable;
  }

  bool isUpdatingLesson(String lessonId) {
    return _updatingLessonIds.contains(lessonId.trim());
  }

  void syncWithLessons(List<TrainingLibraryLesson> lessons) {
    final resolvedVisibilityByLessonId = <String, bool>{
      for (final lesson in lessons)
        lesson.id.trim(): lesson.isPubliclyAvailable,
    };
    var didChange = false;

    _visibilityOverrides.removeWhere((lessonId, visibility) {
      final resolvedVisibility = resolvedVisibilityByLessonId[lessonId];
      final shouldRemove =
          resolvedVisibility == null || resolvedVisibility == visibility;
      if (shouldRemove) {
        didChange = true;
      }
      return shouldRemove;
    });

    if (didChange) {
      notifyListeners();
    }
  }

  Future<bool> updateLessonVisibility({
    required TrainingLibraryLesson lesson,
    required bool isPubliclyAvailable,
  }) async {
    final lessonId = lesson.id.trim();
    if (lessonId.isEmpty || _updatingLessonIds.contains(lessonId)) {
      return false;
    }
    if (isLessonPubliclyAvailable(lesson) == isPubliclyAvailable) {
      return true;
    }

    _updatingLessonIds.add(lessonId);
    _pendingVisibility[lessonId] = isPubliclyAvailable;
    _errors.remove(lessonId);
    notifyListeners();

    try {
      await _trainingRepository.updateSeatDescriptionTrainingModuleVisibility(
        moduleId: lessonId,
        isPubliclyAvailable: isPubliclyAvailable,
      );

      if (lesson.isPubliclyAvailable == isPubliclyAvailable) {
        _visibilityOverrides.remove(lessonId);
      } else {
        _visibilityOverrides[lessonId] = isPubliclyAvailable;
      }
      return true;
    } catch (_) {
      _errors[lessonId] = AppStrings.trainingLibraryUnableToUpdateVisibility;
      return false;
    } finally {
      _updatingLessonIds.remove(lessonId);
      _pendingVisibility.remove(lessonId);
      notifyListeners();
    }
  }
}
