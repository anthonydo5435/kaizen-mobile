import 'package:flutter_test/flutter_test.dart';
import 'package:sparrowkaizen/core/network/api_endpoints.dart';
import 'package:sparrowkaizen/core/network/api_error.dart';
import 'package:sparrowkaizen/core/network/api_processor.dart';
import 'package:sparrowkaizen/features/paygrades/data/datasources/paygrade_remote_data_source.dart';
import 'package:sparrowkaizen/features/paygrades/data/repositories/paygrade_repository_impl.dart';
import 'package:sparrowkaizen/features/paygrades/domain/usecases/get_paygrades_usecase.dart';

void main() {
  late _Executor executor;
  late GetPaygradesUseCase useCase;
  setUp(() {
    executor = _Executor();
    useCase = GetPaygradesUseCase(
      PaygradeRepositoryImpl(
        PaygradeRemoteDataSource(apiCallExecutor: executor),
      ),
    );
  });

  test(
    'GET and POST resolve the server path against the website origin',
    () async {
      expect(
        await useCase.getPaygradesPublicLink('job-id'),
        '${ApiEndPoints.publicWebBaseUrl}/shared/paygrades/public-id',
      );
      expect(executor.type, ApiCallType.get);
      expect(executor.fresh, isTrue);
      expect(executor.endpoint, 'job/job-id/public-links/paygrades/');
      expect(executor.authToken, isNull);
      expect(
        await useCase.createPaygradesPublicLink('job-id'),
        '${ApiEndPoints.publicWebBaseUrl}/shared/paygrades/public-id',
      );
      expect(executor.type, ApiCallType.post);
      expect(executor.parameters, isNull);
    },
  );

  test('DELETE accepts a successful empty response', () async {
    executor.response = null;
    await useCase.deletePaygradesPublicLink('job-id');
    expect(executor.type, ApiCallType.delete);
    expect(executor.endpoint, 'job/job-id/public-links/paygrades/');
  });

  test('inactive and absent links produce the creation state', () async {
    executor.response = {'active': false};
    expect(await useCase.getPaygradesPublicLink('job-id'), isNull);
    executor.error = ApiError.requestFailed(404);
    expect(await useCase.getPaygradesPublicLink('job-id'), isNull);
    executor.error = ApiError.requestFailed(403);
    await expectLater(
      useCase.getPaygradesPublicLink('job-id'),
      throwsA(isA<ApiError>()),
    );
  });

  test(
    'POST does not treat inactive or invalid data as a created link',
    () async {
      for (final response in [
        {'active': false},
        {
          'active': true,
          'view_type': 'wrong_type',
          'public_path': '/shared/paygrades/id',
        },
        {'active': true, 'view_type': 'paygrades', 'public_path': ''},
      ]) {
        executor.response = response;
        await expectLater(
          useCase.createPaygradesPublicLink('job-id'),
          throwsA(isA<ApiError>()),
        );
      }
    },
  );
}

class _Executor extends ApiCallExecutor {
  Object? response = {
    'active': true,
    'view_type': 'paygrades',
    'public_path': '/shared/paygrades/public-id',
  };
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
