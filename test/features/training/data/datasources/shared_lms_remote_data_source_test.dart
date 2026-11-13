import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sparrowkaizen/core/network/api_endpoints.dart';
import 'package:sparrowkaizen/core/network/api_processor.dart';
import 'package:sparrowkaizen/core/preference/app_preference.dart';
import 'package:sparrowkaizen/features/training/data/datasources/shared_lms_remote_data_source.dart';

void main() {
  test('shared content bypasses the parent API prefix', () async {
    SharedPreferences.setMockInitialValues({});
    await AppPreference.init();
    await AppPreference.setUseParentApiEndpoints(true);
    addTearDown(() => AppPreference.setUseParentApiEndpoints(false));

    expect(
      ApiEndPoints.resolveEndpoint(ApiEndPoints.sharedContent('shared-id')),
      'shared/content/shared-id/',
    );
    expect(
      ApiEndPoints.resolveEndpoint(
        ApiEndPoints.sharedLesson('shared-id', 'lesson-id'),
      ),
      'shared/content/shared-id/modules/lesson-id/',
    );
  });

  test('shared list calls the public content endpoint', () async {
    final executor = _RecordingApiCallExecutor({
      'view_type': 'lms',
      'content': {
        'title': 'Shared training',
        'category_title': 'Category',
        'description': 'Description',
        'modules': [
          {'public_id': 'lesson-public-id', 'title': 'Lesson'},
        ],
      },
    });
    final dataSource = SharedLmsRemoteDataSource(apiCallExecutor: executor);

    final content = await dataSource.getSharedLms('link-public-id');

    expect(executor.endpoint, 'shared/content/link-public-id/');
    expect(content.lessons.single.publicId, 'lesson-public-id');
  });

  test('shared lesson uses both IDs and decodes the module payload', () async {
    final executor = _RecordingApiCallExecutor({
      'view_type': 'lms',
      'module': {
        'public_id': 'lesson-public-id',
        'title': 'Shared lesson',
        'summary': 'Lesson summary',
        'thumbnail_url': 'https://example.com/thumbnail.jpg',
        'video': {'title': 'video.mp4', 'url': 'https://example.com/video.mp4'},
        'document': {'text': '<p>Shared SOP</p>'},
        'questions': [
          {
            'question': 'Question?',
            'image_url': null,
            'options': [
              {'text': 'First answer'},
              {'text': 'Second answer'},
            ],
          },
        ],
        'assignment': null,
      },
    });
    final dataSource = SharedLmsRemoteDataSource(apiCallExecutor: executor);

    final detail = await dataSource.getSharedLesson(
      'list-public-id',
      'lesson-public-id',
    );

    expect(
      executor.endpoint,
      'shared/content/list-public-id/modules/lesson-public-id/',
    );
    expect(detail.module.uuid, 'lesson-public-id');
    expect(detail.module.title, 'Shared lesson');
    expect(detail.module.description, 'Lesson summary');
    expect(detail.module.trainingVideo?.url, 'https://example.com/video.mp4');
    expect(detail.document.text, '<p>Shared SOP</p>');
    expect(detail.module.questions.single.options, hasLength(2));
    expect(detail.assignment.title, isNull);
  });
}

class _RecordingApiCallExecutor extends ApiCallExecutor {
  _RecordingApiCallExecutor(this.response);

  final Object response;
  String? endpoint;

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
    this.endpoint = endpoint;
    return decoder(response);
  }
}
