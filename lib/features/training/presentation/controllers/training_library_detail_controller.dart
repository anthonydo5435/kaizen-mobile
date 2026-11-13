import 'package:flutter/material.dart';

import '../../../../core/constants/app_strings.dart';
import '../../domain/repositories/training_library_repository.dart';
import '../../domain/entities/seat_description_training_route.dart';
import '../../domain/entities/training_library_module.dart';
import '../../domain/usecases/get_training_library_modules_usecase.dart';
import '../models/training_library_lesson_action.dart';
import 'training_library_lesson_visibility_controller.dart';

typedef TrainingLibraryOpenViewer =
    Future<void> Function(SeatDescriptionTrainingRoute route);
typedef TrainingLibraryOpenEditor =
    Future<void> Function(
      SeatDescriptionTrainingRoute route,
      String lessonId,
      bool canManageTraining,
    );

class TrainingLibraryDetailController extends ChangeNotifier {
  TrainingLibraryDetailController({
    required TrainingLibraryModule initialModule,
    required GetTrainingLibraryModulesUseCase getTrainingLibraryModules,
    required TrainingLibraryRepository trainingRepository,
    required bool Function(String seatProfileId) canManageSeatTraining,
    required String view,
  }) : _module = initialModule,
       _getTrainingLibraryModules = getTrainingLibraryModules,
       _trainingRepository = trainingRepository,
       _canManageSeatTraining = canManageSeatTraining,
       _view = view.trim().isEmpty ? 'list' : view.trim(),
       visibilityController = TrainingLibraryLessonVisibilityController(
         trainingRepository,
       ) {
    visibilityController.addListener(_handleVisibilityChanged);
  }

  static const int _pageSize = 25;

  final GetTrainingLibraryModulesUseCase _getTrainingLibraryModules;
  final TrainingLibraryRepository _trainingRepository;
  final bool Function(String seatProfileId) _canManageSeatTraining;
  final String _view;
  final TrainingLibraryLessonVisibilityController visibilityController;

  TrainingLibraryModule _module;
  bool _isRefreshing = false;
  bool _isDeletingLesson = false;
  String? _errorMessage;
  String _searchQuery = '';
  bool _shouldRefreshOnExit = false;
  bool _isDisposed = false;

  TrainingLibraryModule get module => _module;
  bool get isRefreshing => _isRefreshing;
  bool get isDeletingLesson => _isDeletingLesson;
  String? get errorMessage => _errorMessage;
  String get searchQuery => _searchQuery;
  bool get isBusy => _isRefreshing || _isDeletingLesson;
  bool get canManageTraining =>
      _module.id.trim().isNotEmpty && _canManageSeatTraining(_module.seat.id);
  bool? get navigationResult => _shouldRefreshOnExit ? true : null;
  String get emptyMessage => _module.lessons.isEmpty
      ? AppStrings.trainingLibraryNoLessonsFound
      : AppStrings.trainingLibraryNoMatchingLessons;

  static String displayLessonTitle(TrainingLibraryLesson lesson) {
    final title = lesson.title.trim();
    return title.isEmpty ? AppStrings.trainingLibraryUntitledModule : title;
  }

  static String displayLessonSelectionTitle(TrainingLibraryLesson lesson) {
    final title = lesson.title.trim();
    return title.isEmpty ? AppStrings.trainingUntitledLesson : title;
  }

  static String displayLessonDescription(TrainingLibraryLesson lesson) =>
      lesson.description.trim();

  SeatDescriptionTrainingRoute? viewerRouteForLesson(
    TrainingLibraryLesson lesson,
  ) {
    final lessonId = lesson.id.trim();
    if (lessonId.isEmpty || _module.trainingDescriptionId.trim().isEmpty) {
      return null;
    }
    return SeatDescriptionTrainingRoute(
      job: _module.seat.id,
      category: _module.category.id,
      description: _module.trainingDescriptionId,
      initialModuleId: lessonId,
    );
  }

  Future<void> openLessonViewer(
    TrainingLibraryLesson lesson, {
    required TrainingLibraryOpenViewer openViewer,
  }) async {
    final route = viewerRouteForLesson(lesson);
    if (!_isDisposed && route != null) {
      await openViewer(route);
    }
  }

  Future<void> selectLesson({
    required Future<TrainingLibraryLesson?> Function(
      List<TrainingLibraryLesson> lessons,
    )
    select,
    required TrainingLibraryOpenViewer openViewer,
  }) async {
    final lesson = await select(visibleLessons);
    if (!_isDisposed && lesson != null) {
      await openLessonViewer(lesson, openViewer: openViewer);
    }
  }

  Future<void> showLessonActions(
    TrainingLibraryLesson lesson, {
    required Future<TrainingLibraryLessonAction?> Function(
      bool canEdit,
      bool isPubliclyAvailable,
    )
    selectAction,
    required TrainingLibraryOpenEditor openEditor,
    required Future<void> Function(TrainingLibraryLesson lesson) showVisibility,
    required Future<bool?> Function(TrainingLibraryLesson lesson) confirmDelete,
    required ValueChanged<String> showMessage,
  }) async {
    if (_isDisposed || !canManageTraining) {
      return;
    }
    final action = await selectAction(
      canManageTraining,
      visibilityController.isLessonPubliclyAvailable(lesson),
    );
    if (_isDisposed || action == null) {
      return;
    }
    switch (action) {
      case TrainingLibraryLessonAction.edit:
        await openLessonEditor(
          lesson,
          openEditor: openEditor,
          showMessage: showMessage,
        );
      case TrainingLibraryLessonAction.visibility:
        if (canManageTraining) {
          await showVisibility(lesson);
        }
      case TrainingLibraryLessonAction.delete:
        await confirmLessonDeletion(
          lesson,
          confirmDelete: confirmDelete,
          showMessage: showMessage,
        );
    }
  }

  Future<void> confirmLessonDeletion(
    TrainingLibraryLesson lesson, {
    required Future<bool?> Function(TrainingLibraryLesson lesson) confirmDelete,
    required ValueChanged<String> showMessage,
  }) async {
    if (_isDisposed || !canManageTraining) {
      return;
    }
    final didDelete = await confirmDelete(lesson);
    if (_isDisposed || didDelete != false) {
      return;
    }
    final message = _errorMessage;
    if (message != null) {
      showMessage(message);
    }
  }

  Future<void> openLessonEditor(
    TrainingLibraryLesson lesson, {
    required TrainingLibraryOpenEditor openEditor,
    required ValueChanged<String> showMessage,
  }) async {
    final lessonId = lesson.id.trim();
    if (_isDisposed ||
        !canManageTraining ||
        lessonId.isEmpty ||
        _module.trainingDescriptionId.trim().isEmpty) {
      return;
    }
    await openEditor(
      SeatDescriptionTrainingRoute(
        job: _module.seat.id,
        category: _module.category.id,
        description: _module.trainingDescriptionId,
      ),
      lessonId,
      canManageTraining,
    );
    if (_isDisposed) {
      return;
    }
    _shouldRefreshOnExit = true;
    final didRefresh = await refreshModule();
    if (!_isDisposed && !didRefresh) {
      showMessage(_errorMessage ?? AppStrings.loginSomethingWentWrong);
    }
  }

  Future<bool> updateLessonVisibility({
    required TrainingLibraryLesson lesson,
    required bool isPubliclyAvailable,
  }) async {
    if (_isDisposed || !canManageTraining) {
      return false;
    }
    final didUpdate = await visibilityController.updateLessonVisibility(
      lesson: lesson,
      isPubliclyAvailable: isPubliclyAvailable,
    );
    if (!_isDisposed && didUpdate) {
      _shouldRefreshOnExit = true;
    }
    return didUpdate;
  }

  void _handleVisibilityChanged() {
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  List<TrainingLibraryLesson> get visibleLessons {
    final query = _searchQuery.trim().toLowerCase();
    return List<TrainingLibraryLesson>.unmodifiable(
      _module.lessons.where(
        (lesson) => lesson.title.toLowerCase().contains(query),
      ),
    );
  }

  void updateSearchQuery(String query) {
    if (_searchQuery == query) {
      return;
    }
    _searchQuery = query;
    notifyListeners();
  }

  Future<bool> refreshModule() async {
    final moduleId = _module.id.trim();
    if (_isDisposed || isBusy || moduleId.isEmpty) {
      return false;
    }

    _isRefreshing = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final refreshedModule = await _findModuleById(moduleId);
      if (_isDisposed) {
        return false;
      }
      if (refreshedModule == null) {
        _errorMessage = AppStrings.loginSomethingWentWrong;
        return false;
      }

      _module = refreshedModule;
      visibilityController.syncWithLessons(_module.lessons);
      return true;
    } catch (error) {
      final resolvedMessage = error.toString().trim();
      _errorMessage = resolvedMessage.isEmpty
          ? AppStrings.loginSomethingWentWrong
          : resolvedMessage;
      return false;
    } finally {
      _isRefreshing = false;
      if (!_isDisposed) {
        notifyListeners();
      }
    }
  }

  Future<bool> deleteLesson(String lessonId) async {
    final resolvedId = lessonId.trim();
    if (_isDisposed ||
        !canManageTraining ||
        resolvedId.isEmpty ||
        _module.id.trim().isEmpty ||
        _isDeletingLesson ||
        _isRefreshing ||
        !_module.lessons.any((lesson) => lesson.id.trim() == resolvedId)) {
      return false;
    }

    _isDeletingLesson = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await _trainingRepository.deleteSeatDescriptionTrainingModule(
        moduleId: resolvedId,
      );
      if (_isDisposed) {
        return false;
      }
      _module = TrainingLibraryModule(
        id: _module.id,
        title: _module.title,
        description: _module.description,
        department: _module.department,
        totalDuration: _module.totalDuration,
        seat: _module.seat,
        lessons: List<TrainingLibraryLesson>.unmodifiable(
          _module.lessons.where((lesson) => lesson.id.trim() != resolvedId),
        ),
        thumbnailLink: _module.thumbnailLink,
        category: _module.category,
        descriptionId: _module.descriptionId,
      );
      _shouldRefreshOnExit = true;
      visibilityController.syncWithLessons(_module.lessons);
      return true;
    } catch (error) {
      final message = error.toString().trim();
      _errorMessage = message.isEmpty
          ? AppStrings.loginSomethingWentWrong
          : message;
      return false;
    } finally {
      _isDeletingLesson = false;
      if (!_isDisposed) {
        notifyListeners();
      }
    }
  }

  Future<TrainingLibraryModule?> _findModuleById(String moduleId) async {
    var page = 1;
    var hasNextPage = true;

    while (!_isDisposed && hasNextPage) {
      final response = await _getTrainingLibraryModules(
        view: _view,
        page: page,
        pageSize: _pageSize,
        searchType: 'category',
        searchText: '',
      );

      for (final module in response.items) {
        if (module.id.trim() == moduleId) {
          return module;
        }
      }

      hasNextPage = response.hasNextPage;
      page += 1;
    }

    return null;
  }

  @override
  void dispose() {
    _isDisposed = true;
    visibilityController
      ..removeListener(_handleVisibilityChanged)
      ..dispose();
    super.dispose();
  }
}
