import 'package:flutter_test/flutter_test.dart';
import 'package:sparrowkaizen/core/network/api_error.dart';
import 'package:sparrowkaizen/core/network/api_processor.dart';
import 'package:sparrowkaizen/features/paygrades/data/datasources/paygrade_remote_data_source.dart';
import 'package:sparrowkaizen/features/paygrades/data/models/shared_paygrades_content_model.dart';
import 'package:sparrowkaizen/features/paygrades/data/repositories/paygrade_repository_impl.dart';
import 'package:sparrowkaizen/features/paygrades/domain/usecases/get_paygrades_usecase.dart';

import 'shared_paygrades_fixture.dart';

void main() {
  test(
    'shared request uses the public endpoint and maps both tab lists',
    () async {
      final executor = _RecordingExecutor();
      final useCase = GetPaygradesUseCase(
        PaygradeRepositoryImpl(
          PaygradeRemoteDataSource(apiCallExecutor: executor),
        ),
      );

      final content = await useCase.getSharedPaygrades('Link-123');

      expect(executor.endpoint, 'shared/content/Link-123/');
      expect(executor.method, ApiCallType.get);
      expect(executor.parameters, isNull);
      expect(executor.authToken, '');
      expect(executor.allowAutoRefresh, isFalse);
      expect(content.primary.title, 'P-ORG Dept Lead (Copy)-1');
      expect(content.primary.department, 'P-ORG-DEPT');
      expect(content.primary.paygradeUnit, 'hr');
      expect(content.primary.payGrades.map((entry) => entry.level), [1, 2, 3]);
      expect(
        content.primary.payGrades.first.description,
        'Primary responsibilities',
      );
      expect(
        content.primary.payGrades.first.promotionRequirement,
        'Complete training',
      );
      expect(content.primary.payGrades.first.payRate, '90.00');
      expect(content.ancillary.payGrades.single.type, 'ancillary');
      expect(content.ancillary.payGrades.single.payRate, '50.00');
      expect(content.includesPayRates, isTrue);
    },
  );

  test('excluded pay rates are discarded even when supplied', () {
    final content = SharedPaygradesContentModel.fromApiJson(
      sharedPaygradesJson(includesPayRates: false),
    );
    expect(content.includesPayRates, isFalse);
    expect(
      content.primary.payGrades.every((entry) => entry.payRate.isEmpty),
      isTrue,
    );
    expect(content.ancillary.payGrades.single.payRate, isEmpty);
  });

  test('wrong content types and malformed lists are rejected', () {
    for (final json in <Map<String, dynamic>>[
      {'view_type': 'lms', 'content': {}},
      {'view_type': 'paygrades', 'content': null},
      {
        'view_type': 'paygrades',
        'content': {'primary': 'invalid'},
      },
      {
        'view_type': 'paygrades',
        'content': {
          'ancillary': [42],
        },
      },
    ]) {
      expect(
        () => SharedPaygradesContentModel.fromApiJson(json),
        throwsA(isA<ApiError>()),
      );
    }
  });
}

class _RecordingExecutor extends ApiCallExecutor {
  String? endpoint;
  ApiCallType? method;
  Map<String, dynamic>? parameters;
  String? authToken;
  bool? allowAutoRefresh;

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
    method = apiCallType;
    this.parameters = parameters;
    this.authToken = authToken;
    this.allowAutoRefresh = allowAutoRefresh;
    return decoder(sharedPaygradesJson());
  }
}
