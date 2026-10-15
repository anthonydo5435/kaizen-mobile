import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sparrowkaizen/core/constants/app_strings.dart';
import 'package:sparrowkaizen/features/check_in/domain/repositories/audit_repository.dart';
import 'package:sparrowkaizen/features/training/data/models/training_library_module_model.dart';
import 'package:sparrowkaizen/features/training/domain/entities/training_library_module.dart';
import 'package:sparrowkaizen/features/training/domain/entities/training_library_page.dart';
import 'package:sparrowkaizen/features/training/domain/repositories/training_library_repository.dart';
import 'package:sparrowkaizen/features/training/domain/usecases/get_training_library_modules_usecase.dart';
import 'package:sparrowkaizen/features/training/presentation/controllers/training_library_detail_controller.dart';
import 'package:sparrowkaizen/features/training/presentation/models/training_library_lesson_action.dart';

import '../../fixtures/training_library_fixtures.dart';

void main() {
  late _LibraryRepository repository;
  late TrainingLibraryDetailController controller;
  late _AuditRepository auditRepository;
  late bool canManage;

  setUp(() {
    repository = _LibraryRepository();
    auditRepository = _AuditRepository();
    canManage = true;
    controller = TrainingLibraryDetailController(
      initialModule: _module([
        _lesson('one', 'Dental Care'),
        _lesson('two', 'Patient Safety'),
      ]),
      getTrainingLibraryModules: GetTrainingLibraryModulesUseCase(repository),
      auditRepository: auditRepository,
      canManageSeatTraining: (_) => canManage,
      view: 'list',
    );
  });

  tearDown(() => controller.dispose());

  group('flat lesson listings', () {
    setUp(() {
      controller.dispose();
      controller = TrainingLibraryDetailController(
        initialModule: TrainingLibraryModuleModel.fromApiJson(
          lessonListingJson(),
        ),
        getTrainingLibraryModules: GetTrainingLibraryModulesUseCase(repository),
        auditRepository: auditRepository,
        canManageSeatTraining: (_) => canManage,
        view: 'list',
      );
    });

    test(
      'viewer and editor use the related description ID and selected lesson ID',
      () async {
        final module = controller.module;
        final lesson = module.lessons.single;
        final route = controller.viewerRouteForLesson(lesson)!;
        expect(route.job, module.seat.id);
        expect(route.category, module.category.id);
        expect(route.description, '53a7288c-576d-45e4-a7b4-a0398336bb6c');
        expect(route.initialModuleId, 'c22bec4b-e69b-4387-9b75-2ccba55991a0');

        repository.module = TrainingLibraryModuleModel.fromApiJson({
          ...lessonListingJson(),
          'title': 'Updated lesson',
        });
        var editorOpened = false;
        await controller.openLessonEditor(
          lesson,
          openEditor: (editorRoute, lessonId, canManageTraining) async {
            editorOpened = true;
            expect(editorRoute.description, route.description);
            expect(lessonId, route.initialModuleId);
            expect(canManageTraining, isTrue);
          },
          showMessage: (message) => fail(message),
        );
        expect(editorOpened, isTrue);
        expect(controller.module.title, 'Updated lesson');
        expect(controller.navigationResult, isTrue);
      },
    );

    test('visibility and delete target the lesson UUID', () async {
      final lesson = controller.module.lessons.single;
      expect(
        controller.visibilityController.isLessonPubliclyAvailable(lesson),
        isTrue,
      );
      expect(
        await controller.updateLessonVisibility(
          lesson: lesson,
          isPubliclyAvailable: false,
        ),
        isTrue,
      );
      expect(auditRepository.visibilityIds, [lesson.id]);
      expect(await controller.deleteLesson(lesson.id), isTrue);
      expect(auditRepository.deletedIds, [lesson.id]);
      expect(controller.module.lessons, isEmpty);
      expect(
        controller.module.trainingDescriptionId,
        '53a7288c-576d-45e4-a7b4-a0398336bb6c',
      );
    });

    test(
      'missing description does not route the lesson UUID as a description',
      () async {
        repository.module = TrainingLibraryModuleModel.fromApiJson({
          ...lessonListingJson(),
          'description': null,
        });
        expect(await controller.refreshModule(), isTrue);
        final lesson = controller.module.lessons.single;
        expect(controller.viewerRouteForLesson(lesson), isNull);
        await controller.openLessonEditor(
          lesson,
          openEditor: (_, __, ___) async =>
              fail('An editor requires a description ID.'),
          showMessage: (message) => fail(message),
        );
      },
    );
  });

  test(
    'the lesson picker opens the selected filtered lesson for read-only users',
    () async {
      canManage = false;
      controller.updateSearchQuery('patient');
      var viewerOpened = false;
      await controller.selectLesson(
        select: (lessons) async {
          expect(lessons.map((lesson) => lesson.id), ['two']);
          return lessons.single;
        },
        openViewer: (route) async {
          viewerOpened = true;
          expect(route.job, 'seat');
          expect(route.category, 'category');
          expect(route.description, 'module');
          expect(route.initialModuleId, 'two');
        },
      );
      expect(viewerOpened, isTrue);
      expect(repository.requests, 0);
      expect(controller.navigationResult, isNull);

      await controller.selectLesson(
        select: (_) async => null,
        openViewer: (_) async =>
            fail('A cancelled selection must not open a lesson.'),
      );
    },
  );

  test(
    'editing refreshes after the editor closes and keeps the active search',
    () async {
      controller.updateSearchQuery('dental');
      final editorClosed = Completer<void>();
      repository.module = _module([_lesson('new', 'Dental Equipment')]);
      final editing = controller.openLessonEditor(
        controller.module.lessons.first,
        openEditor: (route, lessonId, canManageTraining) {
          expect(route.job, 'seat');
          expect(route.category, 'category');
          expect(route.description, 'module');
          expect(route.initialModuleId, isNull);
          expect(lessonId, 'one');
          expect(canManageTraining, isTrue);
          return editorClosed.future;
        },
        showMessage: (message) => fail(message),
      );
      expect(repository.requests, 0);
      expect(controller.navigationResult, isNull);
      editorClosed.complete();
      await editing;
      expect(repository.requests, 1);
      expect(controller.navigationResult, isTrue);
      expect(controller.searchQuery, 'dental');
      expect(controller.visibleLessons.map((lesson) => lesson.id), ['new']);
    },
  );

  test(
    'failed editor refresh keeps existing lessons and reports the error',
    () async {
      repository.error = Exception('Refresh failed');
      final messages = <String>[];
      await controller.openLessonEditor(
        controller.module.lessons.first,
        openEditor: (_, __, ___) async {},
        showMessage: messages.add,
      );
      expect(messages, [controller.errorMessage]);
      expect(controller.module.lessons, hasLength(2));
      expect(controller.navigationResult, isTrue);
      expect(controller.isBusy, isFalse);
    },
  );

  test('read-only users cannot open the lesson actions sheet', () async {
    canManage = false;
    await controller.showLessonActions(
      controller.module.lessons.first,
      selectAction: (_, __) async =>
          fail('The actions sheet must not open without edit permission.'),
      openEditor: (_, __, ___) async => fail('Editing must remain restricted.'),
      showVisibility: (_) async => fail('Visibility must remain restricted.'),
      confirmDelete: (_) async => fail('Deletion must remain restricted.'),
      showMessage: (message) => fail(message),
    );
    expect(auditRepository.visibilityIds, isEmpty);
    expect(auditRepository.deletedIds, isEmpty);
    expect(controller.navigationResult, isNull);
  });

  test(
    'lesson actions recheck permission when the actions sheet returns',
    () async {
      for (final action in TrainingLibraryLessonAction.values) {
        canManage = true;
        await controller.showLessonActions(
          controller.module.lessons.first,
          selectAction: (canEdit, isPubliclyAvailable) async {
            expect(canEdit, isTrue);
            expect(isPubliclyAvailable, isFalse);
            canManage = false;
            return action;
          },
          openEditor: (_, __, ___) async =>
              fail('Editing must remain restricted.'),
          showVisibility: (_) async =>
              fail('Visibility must remain restricted.'),
          confirmDelete: (_) async =>
              throw StateError('Deletion must remain restricted.'),
          showMessage: (message) => fail(message),
        );
      }
      expect(auditRepository.deletedIds, isEmpty);
      expect(controller.navigationResult, isNull);
    },
  );

  test(
    'visibility success marks data changed while failures and denied writes do not',
    () async {
      final lesson = controller.module.lessons.first;
      canManage = false;
      expect(
        await controller.updateLessonVisibility(
          lesson: lesson,
          isPubliclyAvailable: true,
        ),
        isFalse,
      );
      expect(auditRepository.visibilityIds, isEmpty);

      canManage = true;
      auditRepository.onVisibility = () =>
          Future.error(Exception('API failure'));
      expect(
        await controller.updateLessonVisibility(
          lesson: lesson,
          isPubliclyAvailable: true,
        ),
        isFalse,
      );
      expect(controller.navigationResult, isNull);
      expect(
        controller.visibilityController.isLessonPubliclyAvailable(lesson),
        isFalse,
      );
      expect(
        controller.visibilityController.errorForLesson(lesson.id),
        AppStrings.trainingLibraryUnableToUpdateVisibility,
      );

      auditRepository.onVisibility = null;
      expect(
        await controller.updateLessonVisibility(
          lesson: lesson,
          isPubliclyAvailable: true,
        ),
        isTrue,
      );
      expect(controller.navigationResult, isTrue);
      expect(
        controller.visibilityController.isLessonPubliclyAvailable(lesson),
        isTrue,
      );
      expect(controller.isBusy, isFalse);
    },
  );

  test(
    'delete checks current permission and rejects lessons outside this module',
    () async {
      canManage = false;
      expect(await controller.deleteLesson('one'), isFalse);
      canManage = true;
      expect(await controller.deleteLesson('unknown'), isFalse);
      expect(auditRepository.deletedIds, isEmpty);
      expect(controller.module.lessons, hasLength(2));
    },
  );

  test(
    'delete removes only the saved lesson and prevents duplicate requests',
    () async {
      final deletion = Completer<void>();
      auditRepository.onDelete = () => deletion.future;
      final result = controller.deleteLesson(' one ');
      expect(controller.isDeletingLesson, isTrue);
      expect(controller.module.lessons, hasLength(2));
      expect(await controller.deleteLesson('one'), isFalse);

      deletion.complete();
      expect(await result, isTrue);
      expect(auditRepository.deletedIds, ['one']);
      expect(controller.module.lessons.map((lesson) => lesson.id), ['two']);
      expect(controller.isDeletingLesson, isFalse);
      expect(controller.navigationResult, isTrue);

      auditRepository.onDelete = null;
      expect(await controller.deleteLesson('two'), isTrue);
      expect(controller.module.lessons, isEmpty);
      expect(controller.visibleLessons, isEmpty);
    },
  );

  test('failed deletes retain the lesson and can be retried', () async {
    auditRepository.onDelete = () => Future.error(Exception('API failure'));
    expect(await controller.deleteLesson('one'), isFalse);
    expect(controller.errorMessage, isNotNull);
    expect(controller.module.lessons, hasLength(2));
    expect(controller.isDeletingLesson, isFalse);
    expect(controller.navigationResult, isNull);

    auditRepository.onDelete = null;
    expect(await controller.deleteLesson('one'), isTrue);
    expect(controller.errorMessage, isNull);
    expect(controller.visibleLessons.map((lesson) => lesson.id), ['two']);
  });

  test(
    'lesson search ignores case and surrounding spaces without changing source lessons',
    () {
      controller.updateSearchQuery('  DENTAL  ');

      expect(controller.visibleLessons.map((lesson) => lesson.id), ['one']);
      expect(controller.module.lessons, hasLength(2));
      expect(repository.requests, 0);

      controller.updateSearchQuery('no match');
      expect(controller.visibleLessons, isEmpty);

      controller.updateSearchQuery(' ');
      expect(controller.visibleLessons.map((lesson) => lesson.id), [
        'one',
        'two',
      ]);
    },
  );

  test(
    'refresh after editing re-applies the search to the latest lessons',
    () async {
      controller.updateSearchQuery('dental');
      repository.module = _module([
        _lesson('one', 'Patient Care'),
        _lesson('three', 'Dental Equipment'),
      ]);

      expect(await controller.refreshModule(), isTrue);
      expect(controller.searchQuery, 'dental');
      expect(controller.visibleLessons.map((lesson) => lesson.id), ['three']);
    },
  );
}

class _LibraryRepository extends Fake implements TrainingLibraryRepository {
  TrainingLibraryModule module = _module([]);
  int requests = 0;
  Object? error;

  @override
  Future<TrainingLibraryPage> getTrainingLibraryModules({
    required String view,
    required int page,
    int pageSize = 10,
    String searchType = 'category',
    String searchText = '',
    String? departmentId,
    String? jobId,
    String? jobCategoryId,
    String? jobCategoryDescriptionId,
    bool forceRefresh = false,
  }) async {
    requests++;
    if (error != null) {
      throw error!;
    }
    return TrainingLibraryPage(items: [module], hasNextPage: false);
  }
}

class _AuditRepository extends Fake implements AuditRepository {
  final List<String> deletedIds = [];
  Future<void> Function()? onDelete;
  final List<String> visibilityIds = [];
  Future<void> Function()? onVisibility;

  @override
  Future<void> updateSeatDescriptionTrainingModuleVisibility({
    required String moduleId,
    required bool isPubliclyAvailable,
  }) async {
    visibilityIds.add(moduleId);
    await onVisibility?.call();
  }

  @override
  Future<void> deleteSeatDescriptionTrainingModule({
    required String moduleId,
  }) async {
    deletedIds.add(moduleId);
    await onDelete?.call();
  }
}

TrainingLibraryLesson _lesson(String id, String title) => TrainingLibraryLesson(
  id: id,
  title: title,
  description: '',
  thumbnailLink: null,
  isPubliclyAvailable: false,
);

TrainingLibraryModule _module(List<TrainingLibraryLesson> lessons) =>
    TrainingLibraryModule(
      id: 'module',
      title: 'Training',
      description: '',
      department: const TrainingLibraryDepartment(
        id: 'department',
        name: 'Department',
      ),
      totalDuration: 0,
      seat: const TrainingLibrarySeat(id: 'seat', title: 'Seat'),
      lessons: lessons,
      thumbnailLink: null,
      category: const TrainingLibraryCategory(
        id: 'category',
        title: 'Category',
      ),
    );
