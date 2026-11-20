import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sparrowkaizen/core/managers/app_manager.dart';
import 'package:sparrowkaizen/core/network/api_endpoints.dart';
import 'package:sparrowkaizen/core/network/api_error.dart';
import 'package:sparrowkaizen/core/network/api_processor.dart';
import 'package:sparrowkaizen/core/preference/app_preference.dart';
import 'package:sparrowkaizen/features/login/domain/entities/login_response.dart';
import 'package:sparrowkaizen/features/login/domain/entities/app_user.dart';
import 'package:sparrowkaizen/features/login/domain/entities/user.dart';
import 'package:sparrowkaizen/features/login/domain/repositories/auth_repository.dart';
import 'package:sparrowkaizen/features/login/domain/usecases/login_session_usecase.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final events = <String>[];
  var failOrganizations = false;
  final client = MockClient((request) async {
    if (request.url.path.endsWith(ApiEndPoints.organizations)) {
      events.add('organisations');
      expect(request.headers['authorization'], 'Bearer access');
      expect(AppPreference.getAuthToken(), isEmpty);
      expect(AppPreference.getRefreshToken(), isEmpty);
      if (failOrganizations) return http.Response('{}', 409);
      return http.Response(
        jsonEncode([
          {'uuid': 'first', 'name': 'First Organisation', 'type': 'child'},
          {
            'uuid': 'second',
            'name': 'Other Organisation',
            'type': 'organization',
          },
        ]),
        200,
      );
    }
    if (request.url.path.endsWith(ApiEndPoints.companyDetail)) {
      events.add('company');
      return http.Response(
        '{"uuid":"second","name":"Other Organisation"}',
        200,
      );
    }
    throw StateError('Unexpected request: ${request.url}');
  });
  tearDownAll(client.close);
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppPreference.init();
    AppManager.instance.resetSessionState();
    ApiCallExecutor.clearGetCache();
    events.clear();
    failOrganizations = false;
  });
  tearDown(() async {
    await AppPreference.clearUserSession();
    AppManager.instance.resetSessionState();
  });

  test(
    'tokens are saved only after verification and workspace readiness',
    () async {
      final repository = _Repository(events)..verified = false;
      final session = LoginSessionUseCase(repository);
      await http.runWithClient(() async {
        final pending = await session(
          const LoginResponse(access: 'access', refresh: 'refresh'),
        );
        expect(pending.setupStep, LoginSetupStep.emailVerification);
        expect(events, ['organisations', 'user']);
        expect(AppPreference.getAuthToken(), isEmpty);
        expect(AppPreference.getRefreshToken(), isEmpty);

        repository.verified = true;
        final ready = await session.continueAuthenticatedSession();
        expect(ready.setupStep, LoginSetupStep.ready);
        expect(AppPreference.getAuthToken(), 'access');
        expect(AppPreference.getRefreshToken(), 'refresh');
        expect(events, [
          'organisations',
          'user',
          'user',
          'import',
          'hierarchy',
          'company',
        ]);
      }, () => client);
    },
  );

  test(
    'login saves the first organisation before loading user and company',
    () async {
      final session = LoginSessionUseCase(_Repository(events));
      await http.runWithClient(() async {
        final user = await session(
          const LoginResponse(access: 'access', refresh: 'refresh'),
        );
        expect(events, [
          'organisations',
          'user',
          'import',
          'hierarchy',
          'company',
        ]);
        expect(user.email, 'user@example.com');
        expect(user.setupStep, LoginSetupStep.ready);
        expect(AppPreference.getSelectedOrganization()?.id, 'first');
        expect(AppManager.instance.currentOrganizationId, 'first');
        expect(AppManager.instance.isCurrentOrganizationChild, isTrue);
      }, () => client);
    },
  );

  test(
    'failed organisation bootstrap does not leave a partial login',
    () async {
      failOrganizations = true;
      final session = LoginSessionUseCase(_Repository(events));
      await http.runWithClient(() async {
        await expectLater(
          session(const LoginResponse(access: 'access', refresh: 'refresh')),
          throwsA(isA<ApiError>()),
        );
        expect(events, ['organisations']);
        expect(AppPreference.getAuthToken(), isEmpty);
        expect(AppPreference.getRefreshToken(), isEmpty);
        expect(AppPreference.getSelectedOrganization(), isNull);
        expect(AppManager.instance.currentOrganization, isNull);
      }, () => client);
    },
  );
}

class _Repository extends Fake implements AuthRepository {
  _Repository(this.events);
  final List<String> events;
  bool verified = true;

  @override
  Future<User> fetchUserDetail({
    required String accessToken,
    bool includeHierarchy = true,
  }) async {
    events.add('user');
    expect(accessToken, 'access');
    expect(AppPreference.getAuthToken(), isEmpty);
    expect(AppPreference.getRefreshToken(), isEmpty);
    expect(AppPreference.getSelectedOrganization()?.id, 'first');
    expect(AppPreference.getSelectedOrganizationId(), 'first');
    return User(
      uuid: 'user',
      email: 'user@example.com',
      organizationUuid: 'second',
      isEmailVerified: verified,
    );
  }

  @override
  Future<bool> isCompanyImportReady(String accessToken) async {
    events.add('import');
    expect(accessToken, 'access');
    expect(AppPreference.getAuthToken(), isEmpty);
    return true;
  }

  @override
  Future<User> enrichUserWithHierarchy({
    required String accessToken,
    required User user,
  }) async {
    events.add('hierarchy');
    return user;
  }

  @override
  Future<void> saveUserProfile(User user) => AppPreference.saveUser(user);
}
