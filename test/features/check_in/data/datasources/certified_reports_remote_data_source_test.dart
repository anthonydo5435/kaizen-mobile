import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sparrowkaizen/core/network/api_endpoints.dart';
import 'package:sparrowkaizen/core/network/api_error.dart';
import 'package:sparrowkaizen/core/network/api_processor.dart';
import 'package:sparrowkaizen/core/preference/app_preference.dart';
import 'package:sparrowkaizen/features/check_in/data/datasources/audit_remote_data_source.dart';
import 'package:sparrowkaizen/features/check_in/domain/entities/performance_report.dart';

import '../../support/performance_report_fixtures.dart';

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

  Future<List<CertifiedReportOption>> fetch(
    Future<http.Response> Function(http.Request) handler, {
    DateTime? start,
    DateTime? end,
    bool forceRefresh = false,
  }) async {
    requestHandler = handler;
    return http.runWithClient(
      () => AuditRemoteDataSource().getCertifiedReports(
        profile: reportProfile,
        startDate: start,
        endDate: end,
        forceRefresh: forceRefresh,
      ),
      () => client,
    );
  }

  test(
    'the reported paginated response preserves the ID, range and creation date',
    () async {
      final options = await fetch((request) async {
        expect(
          request.url.path,
          endsWith(ApiEndPoints.auditReportCertifiedReports('profile-job')),
        );
        expect(request.url.queryParameters, {
          'profile_uuid': 'employee',
          'page': '1',
        });
        return http.Response(
          jsonEncode({
            'count': 1,
            'next': null,
            'previous': null,
            'current': 1,
            'results': [_reportedReport],
          }),
          200,
        );
      });
      expect(options, hasLength(1));
      expect(options.single.uuid, '684668fc-6fad-417e-adfe-82e6bdd702f4');
      expect(options.single.displayName, 'Oct 01, 2026 - Oct 16, 2026');
      expect(options.single.createdAt, 'Oct 16, 2026 08:06 PM');
    },
  );

  test('all pages retain the selected employee and date filters', () async {
    final requests = <http.Request>[];
    final options = await fetch(
      (request) async {
        requests.add(request);
        final page = request.url.queryParameters['page'];
        return http.Response(
          jsonEncode({
            'count': 2,
            'current': page == '1' ? 1 : 2,
            'next': page == '1'
                ? 'https://dev-api.kaizenteams.ai/api/v1/ignored/?profile_uuid=other&page=2'
                : null,
            'results': [
              {..._reportedReport, if (page == '2') 'uuid': 'second-report'},
            ],
          }),
          200,
        );
      },
      start: DateTime(2026, 10, 1),
      end: DateTime(2026, 10, 16),
    );

    expect(options.map((option) => option.uuid), [
      '684668fc-6fad-417e-adfe-82e6bdd702f4',
      'second-report',
    ]);
    expect(requests, hasLength(2));
    for (final request in requests) {
      expect(
        request.url.path,
        endsWith(ApiEndPoints.auditReportCertifiedReports('profile-job')),
      );
      expect(request.url.queryParameters['profile_uuid'], 'employee');
      expect(request.url.queryParameters['from_date'], '2026-10-01');
      expect(request.url.queryParameters['to_date'], '2026-10-16');
      expect(request.url.queryParameters.containsKey('start'), isFalse);
      expect(request.url.queryParameters.containsKey('end'), isFalse);
      expect(
        request.url.query.indexOf('to_date='),
        lessThan(request.url.query.indexOf('page=')),
      );
    }
    expect(requests.first.url.queryParameters['page'], '1');
    expect(requests.last.url.queryParameters['page'], '2');
  });

  test('empty paginated responses produce an empty history list', () async {
    final options = await fetch(
      (_) async => http.Response(
        jsonEncode({
          'count': 0,
          'next': null,
          'previous': null,
          'current': 1,
          'results': [],
        }),
        200,
      ),
    );
    expect(options, isEmpty);
  });

  test('legacy list responses retain their display names', () async {
    final options = await fetch(
      (_) async => http.Response(
        jsonEncode([
          {'uuid': 'legacy', 'display_name': 'Certified Quarter'},
        ]),
        200,
      ),
    );
    expect(options.single.uuid, 'legacy');
    expect(options.single.displayName, 'Certified Quarter');
    expect(options.single.createdAt, isNull);
  });

  test('invalid result containers are reported as response errors', () async {
    await expectLater(
      fetch((_) async => http.Response(jsonEncode({'results': {}}), 200)),
      throwsA(isA<ApiError>()),
    );
  });

  test('opening history can bypass the cached list on every request', () async {
    var requests = 0;
    Future<http.Response> respond(http.Request request) async {
      requests++;
      return http.Response(
        jsonEncode({
          'count': 1,
          'current': 1,
          'next': null,
          'results': [
            {..._reportedReport, 'uuid': 'report-$requests'},
          ],
        }),
        200,
      );
    }

    final initial = await fetch(respond);
    final reopened = await fetch(respond, forceRefresh: true);
    final nextOpen = await fetch(respond, forceRefresh: true);
    expect(requests, 3);
    expect(initial.single.uuid, 'report-1');
    expect(reopened.single.uuid, 'report-2');
    expect(nextOpen.single.uuid, 'report-3');
  });
}

const _reportedReport = {
  'uuid': '684668fc-6fad-417e-adfe-82e6bdd702f4',
  'created_at': 'Oct 16, 2026 08:06 PM',
  'date_range': 'Oct 01, 2026 - Oct 16, 2026',
};
