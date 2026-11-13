import 'package:flutter_test/flutter_test.dart';
import 'package:sparrowkaizen/core/network/api_processor.dart';
import 'package:sparrowkaizen/features/seat_profile/data/datasources/seat_profile_remote_data_source.dart';

void main() {
  test('shared seat profile uses the public content endpoint', () async {
    final executor = _RecordingApiCallExecutor();
    final source = SeatProfileRemoteDataSource(apiCallExecutor: executor);

    final detail = await source.getSharedSeatProfileDetail('link-id');

    expect(executor.endpoint, 'shared/content/link-id/');
    expect(executor.authToken, '');
    expect(executor.allowAutoRefresh, isFalse);
    expect(detail.title, 'Admin Controller');
  });
}

class _RecordingApiCallExecutor extends ApiCallExecutor {
  String? endpoint;
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
    this.authToken = authToken;
    this.allowAutoRefresh = allowAutoRefresh;
    return decoder({
      'view_type': 'seat_profile',
      'content': {
        'title': 'Admin Controller',
        'department_name': 'Engineering Departments',
        'categories': <Object>[],
      },
    });
  }
}
