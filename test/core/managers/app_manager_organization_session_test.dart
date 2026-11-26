import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sparrowkaizen/core/managers/app_manager.dart';
import 'package:sparrowkaizen/core/managers/models/company_details.dart';
import 'package:sparrowkaizen/core/network/api_endpoints.dart';
import 'package:sparrowkaizen/core/network/api_error.dart';
import 'package:sparrowkaizen/core/network/api_processor.dart';
import 'package:sparrowkaizen/core/preference/app_preference.dart';
import 'package:sparrowkaizen/core/utils/auth_controller.dart';
import 'package:sparrowkaizen/features/login/domain/entities/user.dart';
import 'package:sparrowkaizen/features/login/domain/entities/user_hierarchy_membership.dart';
import 'package:sparrowkaizen/features/organizations/presentation/pages/organizations_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final manager = AppManager.instance;
  final requests = <String>[];
  late Future<http.Response> Function(http.Request) respond;
  final client = MockClient((request) {
    requests.add(request.url.path);
    return respond(request);
  });
  tearDownAll(client.close);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppPreference.init();
    manager.resetSessionState();
    await AppPreference.setAuthToken('access');
    await AppPreference.setRefreshToken('refresh');
    ApiCallExecutor.clearGetCache();
    requests.clear();
    respond = (request) async {
      final path = request.url.path;
      Object body;
      if (path.endsWith(ApiEndPoints.organizations)) {
        body = [_first, _second];
      } else if (path.endsWith(ApiEndPoints.userDetail)) {
        expect(AppPreference.getSelectedOrganization()?.id, 'first');
        body = {
          'profile': User(uuid: 'user', organizationUuid: 'second').toJson(),
        };
      } else if (path.endsWith(ApiEndPoints.organizationHierarchy)) {
        body = [];
      } else if (path.endsWith(ApiEndPoints.companyDetail)) {
        body = {'uuid': 'second', 'name': 'Other Company'};
      } else {
        throw StateError('Unexpected request: $path');
      }
      return http.Response(jsonEncode(body), 200);
    };
  });
  tearDown(() async {
    await AppPreference.clearUserSession();
    manager.resetSessionState();
    ApiCallExecutor.clearGetCache();
  });

  test(
    'startup persists the first complete organisation and hydrates it',
    () async {
      await http.runWithClient(() async {
        await manager.initialize(requireSuccess: true);
        expect(AppPreference.getSelectedOrganization()?.toJson(), _first);
        expect(AppPreference.getSelectedOrganizationId(), 'first');
        manager.updateCurrentUser(
          User(uuid: 'user', organizationUuid: 'second'),
        );
        expect(manager.currentOrganizationId, 'first');
        await AppPreference.saveUser(manager.currentUser!);
        manager.resetSessionState();
        await AppPreference.init();
        await manager.hydrateCurrentUser();
        expect(manager.currentOrganization?.toJson(), _first);
        expect(manager.isCurrentOrganizationChild, isTrue);
        expect(manager.currentOrganizationId, 'first');
      }, () => client);
    },
  );

  test(
    'each startup fetches again and replaces the saved first instance',
    () async {
      await http.runWithClient(() async {
        await manager.initialize(requireSuccess: true);
        respond = (_) async =>
            http.Response(jsonEncode([_second, _first]), 200);
        await manager.initialize(requireSuccess: true);
        expect(
          requests.where((path) => path.endsWith(ApiEndPoints.organizations)),
          hasLength(2),
        );
        expect(AppPreference.getSelectedOrganization()?.toJson(), _second);
        expect(manager.currentOrganizationId, 'second');
      }, () => client);
    },
  );

  test(
    'resume fetches organisations before profile, hierarchy, and company',
    () async {
      manager.updateCurrentUser(User(uuid: 'user', organizationUuid: 'second'));
      await http.runWithClient(() async {
        await manager.refreshSessionContext();
        expect(
          requests.map((path) => path.replaceFirst(ApiEndPoints.version, '')),
          [
            ApiEndPoints.organizations,
            ApiEndPoints.userDetail,
            ApiEndPoints.organizationHierarchy,
            ApiEndPoints.companyDetail,
          ],
        );
        expect(manager.currentOrganizationId, 'first');
        expect(AppPreference.getSelectedOrganization()?.toJson(), _first);
        await manager.refreshSessionContext();
        expect(
          requests.where((path) => path.endsWith(ApiEndPoints.organizations)),
          hasLength(2),
        );
      }, () => client);
    },
  );

  test(
    'concurrent resume refreshes share the same organisations request',
    () async {
      final pending = Completer<http.Response>();
      final started = Completer<void>();
      final defaultRespond = respond;
      respond = (request) {
        if (request.url.path.endsWith(ApiEndPoints.organizations)) {
          started.complete();
          return pending.future;
        }
        return defaultRespond(request);
      };
      await http.runWithClient(() async {
        final first = manager.refreshSessionContext();
        final second = manager.refreshSessionContext();
        await started.future;
        expect(requests, hasLength(1));
        pending.complete(http.Response(jsonEncode([_first, _second]), 200));
        await Future.wait([first, second]);
        expect(
          requests.where((path) => path.endsWith(ApiEndPoints.organizations)),
          hasLength(1),
        );
      }, () => client);
    },
  );

  test(
    'a failed company refresh after a switch clears old billing access',
    () async {
      final defaultRespond = respond;
      respond = (request) async {
        final path = request.url.path;
        if (path.endsWith(ApiEndPoints.setActiveOrganization)) {
          return http.Response('{}', 200);
        }
        if (path.endsWith(ApiEndPoints.companyDetail)) {
          return http.Response('{}', 503);
        }
        return defaultRespond(request);
      };
      await http.runWithClient(() async {
        await manager.initialize(requireSuccess: true);
        final company = CompanyDetails.fromApiJson({
          'uuid': 'first',
          'billing': {'can_use_paid_features': true},
        });
        await AppPreference.saveActiveCompany(company);
        manager.saveActiveCompany(company);
        expect(manager.canUsePaidFeatures, isTrue);

        expect(
          await manager.setActiveOrganization(
            'second',
            resetNavigationStack: false,
          ),
          isTrue,
        );
        expect(manager.currentOrganizationId, 'second');
        expect(manager.canUsePaidFeatures, isFalse);
        expect(await AppPreference.getActiveCompany(), isNull);
      }, () => client);
    },
  );

  test(
    'switching organisations refreshes managed-seat access before returning',
    () async {
      final defaultRespond = respond;
      respond = (request) async {
        final path = request.url.path;
        if (path.endsWith(ApiEndPoints.organizations)) {
          return http.Response(jsonEncode([_second, _first]), 200);
        }
        if (path.endsWith(ApiEndPoints.setActiveOrganization)) {
          return http.Response('{}', 200);
        }
        if (path.endsWith(ApiEndPoints.userDetail)) {
          return http.Response(
            jsonEncode({
              'uuid': 'account',
              'profile': {
                'uuid': 'child-profile',
                'organization_uuid': 'first',
                'roles': ['supervisor'],
              },
            }),
            200,
          );
        }
        if (path.endsWith(ApiEndPoints.organizationHierarchy)) {
          expect(request.headers['organization-uuid'], 'first');
          return http.Response(
            jsonEncode([
              {
                'uuid': 'child-supervisor',
                'role': 'supervisor',
                'profile': {'uuid': 'child-profile'},
                'children': [
                  {
                    'job': {'uuid': 'child-seat'},
                  },
                ],
              },
            ]),
            200,
          );
        }
        return defaultRespond(request);
      };

      await http.runWithClient(() async {
        await manager.initialize(requireSuccess: true);
        manager.updateCurrentUser(
          User(
            uuid: 'parent-profile',
            userUuid: 'account',
            organizationUuid: 'second',
            hasSandboxAccess: false,
            hierarchyMemberships: const [
              UserHierarchyMembership(
                nodeUuid: 'parent-supervisor',
                role: 'supervisor',
                manageableSeatProfileIds: ['parent-seat'],
              ),
            ],
          ),
        );
        expect(
          manager.canCurrentUserViewTrainingQuizAndAssignment(
            seatProfileId: 'parent-seat',
          ),
          isTrue,
        );

        expect(
          await manager.setActiveOrganization(
            'first',
            resetNavigationStack: false,
          ),
          isTrue,
        );
        expect(manager.isCurrentOrganizationChild, isTrue);
        expect(
          manager.canCurrentUserViewTrainingQuizAndAssignment(
            seatProfileId: 'child-seat',
          ),
          isTrue,
        );
        expect(
          manager.canCurrentUserViewTrainingQuizAndAssignment(
            seatProfileId: 'parent-seat',
          ),
          isFalse,
        );
        expect(
          manager.canCurrentUserManageTrainingForSeatProfile(
            seatProfileId: 'child-seat',
          ),
          isFalse,
        );
      }, () => client);
    },
  );

  test(
    'logout clears the instance and ignores an outstanding resume response',
    () async {
      await http.runWithClient(() async {
        await manager.initialize(requireSuccess: true);
        final pending = Completer<http.Response>();
        final started = Completer<void>();
        respond = (_) {
          started.complete();
          return pending.future;
        };
        final refreshing = manager.refreshSessionContext();
        await started.future;
        await AuthController.logout();
        expect(AppPreference.getSelectedOrganization(), isNull);
        expect(AppPreference.getSelectedOrganizationId(), isNull);
        expect(manager.currentOrganization, isNull);
        pending.complete(http.Response(jsonEncode([_first, _second]), 200));
        await refreshing;
        expect(AppPreference.getSelectedOrganization(), isNull);
        expect(AppPreference.getSelectedOrganizationId(), isNull);
        expect(manager.currentOrganization, isNull);
        expect(manager.currentUser, isNull);
      }, () => client);
    },
  );

  test('empty lists clear a previous selection', () async {
    await http.runWithClient(() async {
      await manager.initialize(requireSuccess: true);
      respond = (_) async => http.Response('[]', 200);
      await manager.initialize(requireSuccess: true);
      expect(AppPreference.getSelectedOrganization(), isNull);
      expect(AppPreference.getSelectedOrganizationId(), isNull);
    }, () => client);
  });

  test(
    'an organisation conflict fails without recursively fetching its list',
    () async {
      respond = (_) async => http.Response('{}', 409);
      await http.runWithClient(() async {
        await expectLater(
          manager.initialize(requireSuccess: true),
          throwsA(isA<ApiError>()),
        );
        expect(requests, hasLength(1));
      }, () => client);
    },
  );

  test(
    'a first sandbox instance retains its UUID and selects parent endpoints',
    () async {
      respond = (_) async => http.Response(
        jsonEncode([
          {..._first, 'type': 'sandbox', 'name': 'Sandbox'},
          _second,
        ]),
        200,
      );
      await http.runWithClient(() async {
        await manager.initialize(requireSuccess: true);
        expect(AppPreference.getSelectedOrganization()?.id, 'first');
        expect(AppPreference.getSelectedOrganizationId(), '');
        expect(manager.currentOrganizationId, 'first');
        expect(AppPreference.getUseParentApiEndpoints(), isTrue);
      }, () => client);
    },
  );

  testWidgets(
    'the picker uses the server list when the sandbox flag is false',
    (tester) async {
      final sandbox = {..._second, 'type': 'sandbox', 'name': 'Sandbox'};
      var includeSandbox = true;
      var allowSwitch = false;
      final defaultRespond = respond;
      respond = (request) async {
        final path = request.url.path;
        if (path.endsWith(ApiEndPoints.organizations)) {
          return http.Response(
            jsonEncode([_first, if (includeSandbox) sandbox]),
            200,
          );
        }
        if (path.endsWith(ApiEndPoints.setActiveOrganization)) {
          expect(jsonDecode(request.body), {
            'type': 'sandbox',
            'uuid': 'second',
          });
          return http.Response('{}', allowSwitch ? 200 : 403);
        }
        if (path.endsWith(ApiEndPoints.userDetail)) {
          return http.Response(
            jsonEncode({
              'profile': {
                'uuid': 'user',
                'roles': ['team_member'],
              },
            }),
            200,
          );
        }
        return defaultRespond(request);
      };

      await http.runWithClient(() async {
        await manager.initialize(requireSuccess: true);
        manager.updateCurrentUser(
          User(organizationUuid: 'first', hasSandboxAccess: false),
        );
        await tester.pumpWidget(
          ChangeNotifierProvider.value(
            value: manager,
            child: const MaterialApp(home: OrganizationsScreen()),
          ),
        );
        expect(find.text('Sandbox'), findsOneWidget);
        expect(manager.usesParentApiEndpoints, isFalse);
        Future<bool> selectSandbox() => manager.setActiveOrganization(
          'second',
          resetNavigationStack: false,
        );
        expect(await selectSandbox(), isFalse);
        expect(manager.currentOrganizationId, 'first');
        allowSwitch = true;
        expect(await selectSandbox(), isTrue);
        expect(manager.currentOrganizationId, 'second');
        expect(manager.usesParentApiEndpoints, isTrue);

        includeSandbox = false;
        await manager.fetchOrganizations(requireSuccess: true);
        await tester.pump();
        expect(find.text('Sandbox'), findsNothing);
        expect(manager.usesParentApiEndpoints, isFalse);
      }, () => client);
    },
  );
}

const _first = {
  'uuid': 'first',
  'name': 'First Organisation',
  'website': 'https://example.com',
  'contact_no': '+123',
  'address': 'First Address',
  'created_at': '2026-01-01',
  'type': 'child',
  'logo_url': 'https://example.com/logo.png',
};
final _second = {
  ..._first,
  'uuid': 'second',
  'name': 'Second Organisation',
  'type': 'organization',
};
