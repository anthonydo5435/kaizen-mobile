import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sparrowkaizen/core/managers/app_manager.dart';
import 'package:sparrowkaizen/core/network/api_endpoints.dart';
import 'package:sparrowkaizen/core/network/api_error.dart';
import 'package:sparrowkaizen/core/network/api_processor.dart';
import 'package:sparrowkaizen/core/preference/app_preference.dart';
import 'package:sparrowkaizen/features/login/data/datasources/auth_remote_data_source.dart';
import 'package:sparrowkaizen/features/login/data/repositories/auth_repository_impl.dart';
import 'package:sparrowkaizen/features/login/domain/entities/login_response.dart';
import 'package:sparrowkaizen/features/login/domain/usecases/login_session_usecase.dart';
import 'package:sparrowkaizen/features/onboarding/presentation/providers/onboarding_controller.dart';

import '../../support/user_detail_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppPreference.init();
    AppManager.instance.resetSessionState();
  });
  tearDown(() async {
    await AppPreference.clearUserSession();
    AppManager.instance.resetSessionState();
  });

  test('the API decoder keeps account fields outside profile', () async {
    final api = _UserApi(userDetailResponse);
    final user = await AuthRemoteDataSource(
      apiCallExecutor: api,
    ).fetchUserDetail(accessToken: 'access');
    expect(user.uuid, userDetailResponse['profile']['uuid']);
    expect(user.userUuid, userDetailResponse['uuid']);
    expect(user.email, 'owner@kaizen.com');
    expect(user.isOwner, isTrue);
    expect(user.signature!.image, userDetailResponse['signature']['url']);
    expect(user.imageUrl, userDetailResponse['image']['url']);
    expect(user.hierarchyMemberships, isEmpty);
    AppManager.instance.updateCurrentUser(user);
    expect(AppManager.instance.currentUserHasOwnerOverrideAccess, isTrue);
  });

  for (final matchingField in ['uuid', 'user_uuid', 'email']) {
    test(
      'hierarchy scope resolves through $matchingField after parsing the new response',
      () async {
        final identifier = switch (matchingField) {
          'uuid' => userDetailResponse['profile']['uuid'],
          'user_uuid' => userDetailResponse['uuid'],
          _ => 'OWNER@KAIZEN.COM',
        };
        final api = _UserApi(userDetailResponse)
          ..hierarchy = [
            {
              'uuid': 'manager',
              'role': 'team_lead',
              'department_uuid': 'department',
              'profile': {'uuid': 'other-profile', matchingField: identifier},
              'children': [
                {
                  'uuid': 'direct-child',
                  'role': 'team_member',
                  'job': {'uuid': 'managed-seat'},
                  'children': [
                    {
                      'uuid': 'grandchild',
                      'role': 'team_member',
                      'job': {'uuid': 'nested-seat'},
                    },
                  ],
                },
              ],
            },
            {
              'uuid': 'unrelated-manager',
              'role': 'team_lead',
              'profile': {'uuid': 'unrelated'},
              'children': [
                {
                  'uuid': 'unrelated-child',
                  'job': {'uuid': 'unrelated-seat'},
                },
              ],
            },
          ];
        final user = await AuthRemoteDataSource(
          apiCallExecutor: api,
        ).fetchUserDetail(accessToken: 'access');
        final membership = user.hierarchyMemberships!.single;
        expect(membership.nodeUuid, 'manager');
        expect(membership.departmentUuid, 'department');
        expect(membership.manageableSeatProfileIds, ['managed-seat']);
      },
    );
  }

  test(
    'the login session saves the new response and retains owner access with empty roles',
    () async {
      final repository = AuthRepositoryImpl(
        AuthRemoteDataSource(apiCallExecutor: _UserApi(userDetailResponse)),
      );
      final session = LoginSessionUseCase(
        repository,
        initializeOrganizations: () async {},
        initializeWorkspace: (_) async {},
      );
      final signedIn = await session(
        const LoginResponse(access: 'access', refresh: 'refresh'),
      );
      expect(signedIn.email, 'owner@kaizen.com');
      expect(signedIn.displayName, 'Owner .');
      final saved = await AppPreference.getUser();
      expect(saved!.userUuid, userDetailResponse['uuid']);
      expect(saved.isOwner, isTrue);
      expect(saved.roles, isEmpty);
      expect(AppManager.instance.currentUserHasOwnerOverrideAccess, isTrue);
    },
  );

  test(
    'onboarding uses the complete response for identity, email, and avatar',
    () async {
      await AppPreference.setAuthToken('access');
      final controller = OnboardingController(
        apiCallExecutor: _UserApi(userDetailResponse),
      );
      addTearDown(controller.dispose);
      final user = await controller.ensureOnboardingSessionReady();
      expect(user!.uuid, userDetailResponse['profile']['uuid']);
      expect(user.userUuid, userDetailResponse['uuid']);
      expect(controller.email, 'owner@kaizen.com');
      expect(controller.profileImagePath, userDetailResponse['image']['url']);
      expect((await AppPreference.getUser())!.isOwner, isTrue);
    },
  );

  for (final invalid in <Object?>[
    null,
    [],
    {},
    {'profile': null},
    {'profile': 'invalid'},
  ]) {
    test(
      'invalid user details are rejected (${invalid.runtimeType}: $invalid)',
      () async {
        await expectLater(
          AuthRemoteDataSource(
            apiCallExecutor: _UserApi(invalid),
          ).fetchUserDetail(accessToken: 'access'),
          throwsA(isA<ApiError>()),
        );
      },
    );
  }
}

class _UserApi extends ApiCallExecutor {
  _UserApi(this.user);

  final Object? user;
  Object hierarchy = <Object>[];

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
    if (endpoint == ApiEndPoints.userDetail) return decoder(user);
    if (endpoint == ApiEndPoints.companyImportStatus) {
      return decoder({'ready': true, 'job': null});
    }
    if (endpoint == ApiEndPoints.organizationHierarchy) {
      return decoder(hierarchy);
    }
    throw StateError('Unexpected endpoint: $endpoint');
  }
}
