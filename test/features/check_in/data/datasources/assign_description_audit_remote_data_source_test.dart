import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sparrowkaizen/core/network/api_error.dart';
import 'package:sparrowkaizen/core/preference/app_preference.dart';
import 'package:sparrowkaizen/features/check_in/data/datasources/audit_remote_data_source.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Future<http.Response> Function(http.Request) requestHandler;
  final client = MockClient((request) => requestHandler(request));
  tearDownAll(client.close);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppPreference.init();
    await AppPreference.setAuthToken('test-token');
  });

  for (final ids in <List<String>>[
    ['profile-job-one', 'profile-job-two'],
    [],
  ]) {
    test(
      'assigns profile jobs $ids using PUT and accepts an empty response',
      () async {
        requestHandler = (request) async {
          expect(request.method, 'PUT');
          expect(request.url.path, endsWith('/audit/resolved-audit/assign/'));
          expect(jsonDecode(request.body), {'profile_jobs': ids});
          expect(request.headers['authorization'], 'Bearer test-token');
          return http.Response('', 204);
        };
        await http.runWithClient(
          () => AuditRemoteDataSource().assignDescriptionAudit(
            descriptionId: 'resolved-audit',
            profileJobIds: ids,
          ),
          () => client,
        );
      },
    );
  }

  test('assignment errors propagate to the controller', () async {
    requestHandler = (_) async =>
        http.Response('{"detail":"Unable to assign"}', 400);
    await http.runWithClient(
      () => expectLater(
        AuditRemoteDataSource().assignDescriptionAudit(
          descriptionId: 'resolved-audit',
          profileJobIds: ['profile-job-one'],
        ),
        throwsA(isA<ApiError>()),
      ),
      () => client,
    );
  });
}
