// ignore_for_file: depend_on_referenced_packages

import 'package:sparrowkaizen/core/network/api_processor.dart';
import 'package:sparrowkaizen/features/training/data/datasources/training_library_remote_data_source.dart';
import 'package:sparrowkaizen/features/training/data/models/training_library_page_model.dart';
import 'package:sparrowkaizen/features/training/data/models/training_library_module_model.dart';
import 'package:sparrowkaizen/features/training/data/repositories/training_library_repository_impl.dart';
import 'package:sparrowkaizen/features/training/domain/usecases/get_training_library_modules_usecase.dart';
import 'package:test/test.dart';

import '../../fixtures/training_library_fixtures.dart';

void main() {
  group('TrainingLibraryRemoteDataSource.getTrainingLibraryModules', () {
    test(
      'appends lesson search after hierarchy IDs and pagination through all layers',
      () async {
        final executor = _CapturingApiCallExecutor();
        final useCase = GetTrainingLibraryModulesUseCase(
          TrainingLibraryRepositoryImpl(
            TrainingLibraryRemoteDataSource(apiCallExecutor: executor),
          ),
        );
        for (final page in [1, 2]) {
          await useCase(
            view: 'list',
            page: page,
            jobId: ' b8a99b8b-6a6a-46ed-9bd7-3408b1edf09b ',
            jobCategoryId: '54760b19-1b8f-4f1c-bfdf-935b88f2d861',
            jobCategoryDescriptionId: '30f1c014-c7ec-41ee-8414-f0009c6e53f8',
            searchText: ' Lesson ',
          );
          expect(executor.capturedParameters, {
            'job': 'b8a99b8b-6a6a-46ed-9bd7-3408b1edf09b',
            'job_category': '54760b19-1b8f-4f1c-bfdf-935b88f2d861',
            'job_category_description': '30f1c014-c7ec-41ee-8414-f0009c6e53f8',
            'module_type': 'job_based',
            'page': page,
            'page_size': 10,
            'view': 'list',
            'searchType': 'category',
            'search': 'Lesson',
          });
          expect(executor.capturedParameters!.keys.last, 'search');
          expect(executor.capturedParameters, isNot(contains('searchText')));
        }
      },
    );

    test('omits cleared and blank hierarchy IDs from the query', () async {
      final executor = _CapturingApiCallExecutor();
      await TrainingLibraryRemoteDataSource(
        apiCallExecutor: executor,
      ).getTrainingLibraryModules(
        view: 'list',
        page: 1,
        jobId: 'seat',
        jobCategoryId: ' ',
        searchText: '  ',
      );
      expect(executor.capturedParameters!['job'], 'seat');
      expect(executor.capturedParameters, isNot(contains('job_category')));
      expect(
        executor.capturedParameters,
        isNot(contains('job_category_description')),
      );
      expect(executor.capturedParameters, isNot(contains('searchText')));
      expect(executor.capturedParameters, isNot(contains('search')));
    });

    test(
      'sends page and page_size alongside the current search filters',
      () async {
        final apiCallExecutor = _CapturingApiCallExecutor();
        final dataSource = TrainingLibraryRemoteDataSource(
          apiCallExecutor: apiCallExecutor,
        );

        await dataSource.getTrainingLibraryModules(
          view: 'list',
          page: 2,
          pageSize: 10,
          searchType: 'category',
          searchText: ' safety ',
        );

        expect(apiCallExecutor.capturedParameters, <String, dynamic>{
          'module_type': 'job_based',
          'page': 2,
          'page_size': 10,
          'view': 'list',
          'searchType': 'category',
          'search': 'safety',
        });
      },
    );

    test('attaches department when a department filter is selected', () async {
      final apiCallExecutor = _CapturingApiCallExecutor();
      final dataSource = TrainingLibraryRemoteDataSource(
        apiCallExecutor: apiCallExecutor,
      );

      await dataSource.getTrainingLibraryModules(
        view: 'list',
        page: 1,
        pageSize: 10,
        searchType: 'category',
        departmentId: 'department-42',
      );

      expect(apiCallExecutor.capturedParameters, <String, dynamic>{
        'module_type': 'job_based',
        'page': 1,
        'page_size': 10,
        'view': 'list',
        'searchType': 'category',
        'department': 'department-42',
      });
    });

    test(
      'decodes the supplied flat lesson response without losing related IDs',
      () async {
        final dataSource = TrainingLibraryRemoteDataSource(
          apiCallExecutor: _CapturingApiCallExecutor(
            response: {
              'count': 30,
              'current': 1,
              'results': [lessonListingJson()],
            },
          ),
        );
        final page = await dataSource.getTrainingLibraryModules(
          view: 'list',
          page: 1,
        );
        final module = page.items.single;
        expect(page.hasNextPage, isTrue);
        expect(module.id, 'c22bec4b-e69b-4387-9b75-2ccba55991a0');
        expect(module.title, '2');
        expect(module.description, 'Controls Financial Records');
        expect(
          module.trainingDescriptionId,
          '53a7288c-576d-45e4-a7b4-a0398336bb6c',
        );
        expect(module.isLessonListing, isTrue);
        expect(module.totalDuration, 706);
        expect(module.seat.id, '2a685b4e-5642-4faa-8201-20e2896b2c5b');
        expect(module.seat.title, 'Admin Controller');
        expect(module.category.id, '482c6a85-3169-4430-b95f-1fc8306d49c9');
        expect(module.category.title, 'Financial Management');
        expect(module.department.id, isEmpty);
        final lesson = module.lessons.single;
        expect(lesson.id, module.id);
        expect(lesson.description, module.description);
        expect(lesson.thumbnailLink, lessonListingJson()['thumbnail_link']);
        expect(module.thumbnailLink, lesson.thumbnailLink);
        expect(lesson.duration, 706);
        expect(lesson.isPubliclyAvailable, isTrue);
        expect(lesson.fromSandbox, isFalse);
        expect(lesson.sopExists, isFalse);
        expect(lesson.quizExists, isFalse);
      },
    );
  });

  group('TrainingLibraryPageModel.fromApiJson', () {
    test('uses count and current to stop at the final page', () {
      for (final current in [1, 2, 3]) {
        final page = TrainingLibraryPageModel.fromApiJson({
          'count': 30,
          'current': current,
          'results': [lessonListingJson()],
        }, pageSize: 10);
        expect(page.hasNextPage, current < 3);
      }
    });

    test('treats list-style responses as non-paginated without metadata', () {
      final page = TrainingLibraryPageModel.fromApiJson(<String, dynamic>{
        'results': <Map<String, dynamic>>[
          _moduleJson(id: '1'),
          _moduleJson(id: '2'),
          _moduleJson(id: '3'),
          _moduleJson(id: '4'),
          _moduleJson(id: '5'),
          _moduleJson(id: '6'),
          _moduleJson(id: '7'),
          _moduleJson(id: '8'),
          _moduleJson(id: '9'),
          _moduleJson(id: '10'),
        ],
      }, pageSize: 10);

      expect(page.items, hasLength(10));
      expect(page.hasNextPage, isFalse);
    });

    test('keeps honoring explicit next-page metadata', () {
      final page = TrainingLibraryPageModel.fromApiJson(<String, dynamic>{
        'results': <Map<String, dynamic>>[_moduleJson(id: '1')],
        'next':
            'https://dev-api.kaizenteams.ai/api/v1/training_modules/all/?view=list&searchType=category',
      }, pageSize: 10);

      expect(page.hasNextPage, isTrue);
    });
  });

  group('TrainingLibraryModuleModel.fromApiJson', () {
    test(
      'retains enabled lesson flags and parses numeric duration strings',
      () {
        final module = TrainingLibraryModuleModel.fromApiJson({
          ...lessonListingJson(),
          'duration': '706',
          'from_sandbox': true,
          'sop_exists': true,
          'quiz_exists': true,
          'is_publicly_available': false,
        });
        expect(module.totalDuration, 706);
        expect(module.lessons.single.fromSandbox, isTrue);
        expect(module.lessons.single.sopExists, isTrue);
        expect(module.lessons.single.quizExists, isTrue);
        expect(module.lessons.single.isPubliclyAvailable, isFalse);
      },
    );

    test('preserves legacy grouped lessons and their description UUID', () {
      final module = TrainingLibraryModuleModel.fromApiJson({
        'uuid': 'description-id',
        'description': 'Description title',
        'total_duration': 100,
        'training_modules': [
          {
            'uuid': 'lesson-one',
            'title': 'First',
            'description': 'Introduction',
          },
          {'uuid': 'lesson-two', 'title': 'Second'},
        ],
      });
      expect(module.isLessonListing, isFalse);
      expect(module.trainingDescriptionId, 'description-id');
      expect(module.title, 'Description title');
      expect(module.totalDuration, 100);
      expect(module.lessons.map((lesson) => lesson.id), [
        'lesson-one',
        'lesson-two',
      ]);
      expect(module.lessons.first.description, 'Introduction');
    });

    test(
      'does not substitute the lesson UUID when its description is absent',
      () {
        final module = TrainingLibraryModuleModel.fromApiJson({
          ...lessonListingJson(),
          'description': null,
          'job': null,
          'category': null,
        });
        expect(module.isLessonListing, isTrue);
        expect(module.trainingDescriptionId, isEmpty);
        expect(module.description, isEmpty);
        expect(module.seat.id, isEmpty);
        expect(module.category.id, isEmpty);
        expect(module.lessons, hasLength(1));
      },
    );
  });
}

class _CapturingApiCallExecutor extends ApiCallExecutor {
  _CapturingApiCallExecutor({this.response});

  final Map<String, dynamic>? response;
  Map<String, dynamic>? capturedParameters;

  @override
  Future<Response> processApi<Response>({
    required ApiCallType apiCallType,
    required String endpoint,
    required Response Function(dynamic json) decoder,
    Map<String, dynamic>? parameters,
    Map<String, String>? headers,
    String? authToken,
    bool allowAutoRefresh = true,
    bool allowConflictRetry = true,
    bool invalidateCacheBeforeRequest = false,
  }) async {
    capturedParameters = parameters;
    return decoder(
      response ?? <String, dynamic>{'results': const <Map<String, dynamic>>[]},
    );
  }
}

Map<String, dynamic> _moduleJson({required String id}) {
  return <String, dynamic>{
    'id': id,
    'title': 'Module $id',
    'description': 'Description $id',
    'department': <String, dynamic>{'id': 'dep-1', 'name': 'Operations'},
    'seat': <String, dynamic>{'id': 'seat-1', 'title': 'Lead'},
    'category': <String, dynamic>{'id': 'cat-1', 'name': 'Safety'},
    'lessons': const <Map<String, dynamic>>[],
  };
}
