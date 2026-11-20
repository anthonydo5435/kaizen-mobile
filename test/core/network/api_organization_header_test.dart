import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sparrowkaizen/core/managers/app_manager.dart';
import 'package:sparrowkaizen/core/network/api_endpoints.dart';
import 'package:sparrowkaizen/core/network/api_http_client.dart';
import 'package:sparrowkaizen/core/network/api_processor.dart';
import 'package:sparrowkaizen/core/preference/app_preference.dart';
import 'package:sparrowkaizen/core/services/file_uploader.dart';
import 'package:sparrowkaizen/features/check_in/data/datasources/audit_remote_data_source.dart';
import 'package:sparrowkaizen/features/organizations/domain/entities/organization.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final requests = <http.Request>[];
  late Future<http.Response> Function(http.Request) respond;
  final client = MockClient((request) {
    requests.add(request);
    return respond(request);
  });
  tearDownAll(client.close);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppPreference.init();
    await AppPreference.setAuthToken('access');
    AppManager.instance.resetSessionState();
    ApiCallExecutor.clearGetCache();
    requests.clear();
    respond = (request) async {
      Object body;
      if (request.url.path.endsWith(ApiEndPoints.organizations)) {
        body = [
          {'uuid': 'first', 'name': 'First', 'type': 'organization'},
          {'uuid': 'second', 'name': 'Second', 'type': 'organization'},
        ];
      } else if (request.url.path.endsWith(ApiEndPoints.images)) {
        body = {'uuid': 'image', 'image': 'https://example.com/image.png'};
      } else {
        body = {'organization': request.headers['organization-uuid']};
      }
      return http.Response(jsonEncode(body), 200);
    };
  });
  tearDown(() async {
    await AppPreference.clearUserSession();
    AppManager.instance.resetSessionState();
    ApiCallExecutor.clearGetCache();
  });

  for (final method in ApiCallType.values) {
    test(
      '${method.value} adds the saved organisation and preserves other headers',
      () async {
        await _select('first');
        await http.runWithClient(() async {
          await const ApiCallExecutor().processApi<Object?>(
            apiCallType: method,
            endpoint: 'header-test/',
            parameters: {'value': 'example'},
            headers: {'X-Request-Id': 'request', 'ORGANIZATION-UUID': 'stale'},
            decoder: (json) => json,
          );
          final request = requests.single;
          expect(request.headers['organization-uuid'], 'first');
          expect(request.headers['authorization'], 'Bearer access');
          expect(request.headers['x-request-id'], 'request');
          expect(request.headers['content-type'], 'application/json');
          if (method != ApiCallType.get) {
            expect(jsonDecode(request.body), {'value': 'example'});
          }
        }, () => client);
      },
    );
  }

  test(
    'one client reads preference changes and removes the header after logout',
    () async {
      final apiClient = ApiHttpClient(inner: client);
      final uri = ApiEndPoints.resolveUri('header-test/');
      await _select('first');
      await apiClient.get(uri);
      await _select('second');
      await apiClient.get(uri);
      await AppPreference.clearUserSession();
      await apiClient.get(uri, headers: {'organization-uuid': 'stale'});
      expect(requests.map((request) => request.headers['organization-uuid']), [
        'first',
        'second',
        null,
      ]);
    },
  );

  test(
    'the initial organisations request omits an unavailable organisation',
    () async {
      await http.runWithClient(() async {
        await AppManager.instance.initialize(requireSuccess: true);
        expect(
          requests.single.headers.containsKey('organization-uuid'),
          isFalse,
        );
        expect(AppPreference.getSelectedOrganization()?.id, 'first');
        await _get();
        expect(requests.last.headers['organization-uuid'], 'first');
      }, () => client);
    },
  );

  test('Sandbox uses the standard API path and sends its UUID', () async {
    await _select('sandbox-id', sandbox: true);
    await AppPreference.setUseParentApiEndpoints(true);
    expect(AppPreference.getSelectedOrganizationId(), '');
    expect(ApiEndPoints.resolveUri('header-test/').path, '/api/v1/header-test/');
    await http.runWithClient(() async {
      await _get();
      expect(requests.single.url.path, '/api/v1/header-test/');
      expect(requests.single.headers['organization-uuid'], 'sandbox-id');
    }, () => client);
  });

  test(
    'an existing saved ID works before an instance has been persisted',
    () async {
      await AppPreference.setSelectedOrganizationId(' legacy-id ');
      await http.runWithClient(() async {
        await _get();
        expect(requests.single.headers['organization-uuid'], 'legacy-id');
      }, () => client);
    },
  );

  test('GET caches are separate for different organisations', () async {
    await http.runWithClient(() async {
      await _select('first');
      expect(await _get(), {'organization': 'first'});
      await _select('second');
      expect(await _get(), {'organization': 'second'});
      expect(await _get(), {'organization': 'second'});
      await _select('first');
      expect(await _get(), {'organization': 'first'});
      expect(requests, hasLength(2));
    }, () => client);
  });

  test(
    'multipart API uploads include the header and preserve their form data',
    () async {
      await _select('first');
      await http.runWithClient(() async {
        await const FileUploader().uploadOnboardingImage(
          fileName: 'image.png',
          fileBytes: [1, 2, 3],
          contentType: 'image/png',
        );
        await AuditRemoteDataSource().uploadPerformanceReportSignatureImage(
          fileName: 'signature.png',
          fileBytes: [4, 5, 6],
          contentType: 'image/png',
        );
        expect(requests, hasLength(2));
        for (final request in requests) {
          expect(request.headers['organization-uuid'], 'first');
          expect(request.headers['authorization'], 'Bearer access');
          expect(
            request.headers['content-type'],
            startsWith('multipart/form-data; boundary='),
          );
          expect(request.body, contains('name="image"'));
        }
      }, () => client);
    },
  );

  test('organisation switching uses the same sender header', () async {
    await http.runWithClient(() async {
      final manager = AppManager.instance;
      await manager.initialize(requireSuccess: true);
      expect(
        await manager.setActiveOrganization(
          'second',
          resetNavigationStack: false,
        ),
        isTrue,
      );
      final switchRequest = requests.singleWhere(
        (request) => request.method == 'POST',
      );
      expect(switchRequest.headers['organization-uuid'], 'first');
      expect(requests.last.headers['organization-uuid'], 'second');
    }, () => client);
  });

  test(
    'presigned uploads keep their existing headers without the organisation UUID',
    () async {
      await _select('first');
      await http.runWithClient(() async {
        await const FileUploader().uploadBinaryFile(
          uploadUrl: 'https://uploads.example.com/file?signature=example',
          fileBytes: [1, 2, 3],
          contentType: 'image/png',
        );
        expect(
          requests.single.headers.containsKey('organization-uuid'),
          isFalse,
        );
        expect(requests.single.headers['content-type'], 'image/png');
        expect(requests.single.bodyBytes, [1, 2, 3]);
      }, () => client);
    },
  );

  test(
    'token refresh and its retry both include the organisation header',
    () async {
      await _select('first');
      await AppPreference.setRefreshToken('refresh');
      respond = (request) async {
        if (request.url.path.endsWith(ApiEndPoints.refreshToken)) {
          return http.Response(
            '{"access":"rotated","refresh":"rotated-refresh"}',
            200,
          );
        }
        return http.Response(
          '{}',
          request.headers['authorization'] == 'Bearer rotated' ? 200 : 401,
        );
      };
      await http.runWithClient(() async {
        await _get();
        expect(requests, hasLength(3));
        expect(
          requests.map((request) => request.headers['organization-uuid']),
          everyElement('first'),
        );
      }, () => client);
    },
  );
}

Future<Object?> _get() => const ApiCallExecutor().processApi<Object?>(
  apiCallType: ApiCallType.get,
  endpoint: 'header-test/',
  decoder: (json) => json,
);

Future<void> _select(String id, {bool sandbox = false}) async {
  await AppPreference.setSelectedOrganizationId(sandbox ? '' : id);
  await AppPreference.saveSelectedOrganization(
    Organization.fromJson({
      'uuid': id,
      'name': id,
      'type': sandbox ? 'sandbox' : 'organization',
    }),
  );
}
