import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sparrowkaizen/core/network/api_error.dart';
import 'package:sparrowkaizen/core/network/api_processor.dart';
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
    ApiCallExecutor.clearGetCache();
  });

  test(
    'requests the clicked seat and preserves the complete straight-list response',
    () async {
      requestHandler = (request) async {
        expect(request.method, 'GET');
        expect(
          request.url.path,
          endsWith('job/seat-id/subordinate_profile_jobs/'),
        );
        expect(request.url.queryParameters, isEmpty);
        return http.Response(jsonEncode([_profileJob]), 200);
      };
      final profiles = await http.runWithClient(
        () => AuditRemoteDataSource().getSubordinateProfileJobs(
          seatId: 'seat-id',
        ),
        () => client,
      );
      final profileJob = profiles.single;
      expect(profileJob.uuid, '5b9e5005-cb6a-4bd5-b287-f9267d3ebfa3');
      expect(profileJob.title, 'Backend Dev');
      expect(profileJob.isPrimary, isFalse);
      expect(profileJob.createdAt, '1778063413000');
      final profile = profileJob.profile;
      expect(profile.uuid, 'bcc954e5-6072-4a7b-b5ff-76d60ae4ad80');
      expect(profile.name, 'Gretchen Bradford');
      expect(profile.userUuid, '287827f8-86d2-48f8-99ce-8c05ce5040b1');
      expect(profile.email, 'paze@mailinator.com');
      expect(profile.image, isNull);
      expect(profile.onboarded, isTrue);
    },
  );

  test('accepts an empty list', () async {
    requestHandler = (_) async => http.Response('[]', 200);
    final profiles = await http.runWithClient(
      () => AuditRemoteDataSource().getSubordinateProfileJobs(
        seatId: 'empty-seat',
      ),
      () => client,
    );
    expect(profiles, isEmpty);
  });

  test(
    'rejects a paginated envelope instead of treating it as an empty list',
    () async {
      requestHandler = (_) async => http.Response('{"results": []}', 200);
      await http.runWithClient(
        () => expectLater(
          AuditRemoteDataSource().getSubordinateProfileJobs(
            seatId: 'invalid-seat',
          ),
          throwsA(isA<ApiError>()),
        ),
        () => client,
      );
    },
  );
}

const _profileJob = {
  'uuid': '5b9e5005-cb6a-4bd5-b287-f9267d3ebfa3',
  'title': 'Backend Dev',
  'is_primary': false,
  'profile': {
    'uuid': 'bcc954e5-6072-4a7b-b5ff-76d60ae4ad80',
    'name': 'Gretchen Bradford',
    'user_uuid': '287827f8-86d2-48f8-99ce-8c05ce5040b1',
    'email': 'paze@mailinator.com',
    'image': null,
    'onboarded': true,
  },
  'created_at': '1778063413000',
};
