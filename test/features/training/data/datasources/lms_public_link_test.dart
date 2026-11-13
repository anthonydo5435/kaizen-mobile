import 'package:flutter_test/flutter_test.dart';
import 'package:sparrowkaizen/core/network/api_endpoints.dart';
import 'package:sparrowkaizen/core/network/api_error.dart';
import 'package:sparrowkaizen/core/network/api_processor.dart';
import 'package:sparrowkaizen/features/training/data/datasources/training_library_remote_data_source.dart';
import 'package:sparrowkaizen/features/training/data/repositories/training_library_repository_impl.dart';

void main() {
  late _Executor executor;
  late TrainingLibraryRepositoryImpl repository;
  setUp(() {
    executor = _Executor();
    repository = TrainingLibraryRepositoryImpl(
      TrainingLibraryRemoteDataSource(apiCallExecutor: executor),
    );
  });

  test(
    'POSTs the exact contract and resolves the returned website path',
    () async {
      final result = await repository.createLmsPublicLink(
        descriptionId: 'description-id',
        trainingModuleUuids: ['lesson-a', 'lesson-b'],
      );
      expect(executor.type, ApiCallType.post);
      expect(
        executor.endpoint,
        'job_category_description/description-id/public-links/lms/',
      );
      expect(executor.authToken, isNull);
      expect(executor.parameters, {
        'view_type': 'lms',
        'public_path': '',
        'training_module_uuids': ['lesson-a', 'lesson-b'],
      });
      expect(
        result.url,
        '${ApiEndPoints.publicWebBaseUrl}/shared/lms/public-id',
      );
      expect(result.trainingModuleUuids, ['lesson-a', 'lesson-b']);
    },
  );

  test(
    'GET fetches a fresh public link and retains the shared lesson IDs',
    () async {
      final result = await repository.getLmsPublicLink('description-id');
      expect(executor.type, ApiCallType.get);
      expect(
        executor.endpoint,
        'job_category_description/description-id/public-links/lms/',
      );
      expect(executor.parameters, isNull);
      expect(executor.fresh, isTrue);
      expect(
        result?.url,
        '${ApiEndPoints.publicWebBaseUrl}/shared/lms/public-id',
      );
      expect(result?.trainingModuleUuids, ['lesson-a', 'lesson-b']);
    },
  );

  test(
    'inactive and 404 links are absent; other failures allow retry',
    () async {
      executor.response = {'active': false};
      expect(await repository.getLmsPublicLink('id'), isNull);
      executor.error = ApiError.requestFailed(404);
      expect(await repository.getLmsPublicLink('id'), isNull);
      executor.error = ApiError.requestFailed(403);
      await expectLater(
        repository.getLmsPublicLink('id'),
        throwsA(isA<ApiError>()),
      );
    },
  );

  test('invalid or inactive responses never produce a usable link', () async {
    for (final change in <Map<String, dynamic>>[
      {'active': false},
      {'view_type': 'seat_profile'},
      {'public_path': ''},
      {'public_path': '/shared/lms/'},
      {'public_path': 'https://other.example/shared/lms/id'},
      {'training_module_uuids': []},
      {
        'training_module_uuids': [null],
      },
    ]) {
      executor.response = {..._response, ...change};
      await expectLater(
        repository.createLmsPublicLink(
          descriptionId: 'id',
          trainingModuleUuids: ['lesson-a'],
        ),
        throwsA(isA<ApiError>()),
      );
    }
  });

  test('API failures remain failures through the repository', () async {
    executor.error = ApiError.requestFailed(403);
    await expectLater(
      repository.createLmsPublicLink(
        descriptionId: 'id',
        trainingModuleUuids: ['lesson-a'],
      ),
      throwsA(isA<ApiError>()),
    );
  });

  test(
    'DELETE uses the description endpoint and accepts an empty response',
    () async {
      executor.response = null;
      await repository.deleteLmsPublicLink('description-id');
      expect(executor.type, ApiCallType.delete);
      expect(
        executor.endpoint,
        'job_category_description/description-id/public-links/lms/',
      );
      expect(executor.parameters, isNull);
      executor.error = ApiError.requestFailed(403);
      await expectLater(
        repository.deleteLmsPublicLink('description-id'),
        throwsA(isA<ApiError>()),
      );
    },
  );
}

const _response = {
  'active': true,
  'view_type': 'lms',
  'public_path': '/shared/lms/public-id',
  'training_module_uuids': ['lesson-a', 'lesson-b'],
};

class _Executor extends ApiCallExecutor {
  Object? response = _response;
  ApiError? error;
  ApiCallType? type;
  String? endpoint;
  String? authToken;
  Map<String, dynamic>? parameters;
  bool? fresh;

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
    type = apiCallType;
    this.endpoint = endpoint;
    this.authToken = authToken;
    this.parameters = parameters;
    fresh = invalidateCacheBeforeRequest;
    if (error != null) throw error!;
    return decoder(response);
  }
}
