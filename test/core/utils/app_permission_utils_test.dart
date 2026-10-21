// ignore_for_file: depend_on_referenced_packages

import 'package:test/test.dart';
import 'package:sparrowkaizen/core/utils/app_permission_utils.dart';
import 'package:sparrowkaizen/features/login/domain/entities/organization_hierarchy_job.dart';
import 'package:sparrowkaizen/features/login/domain/entities/organization_hierarchy_node.dart';
import 'package:sparrowkaizen/features/login/domain/entities/organization_hierarchy_profile.dart';
import 'package:sparrowkaizen/features/login/domain/entities/user.dart';
import 'package:sparrowkaizen/features/login/domain/entities/user_hierarchy_membership.dart';
import 'package:sparrowkaizen/features/organizations/domain/entities/organization.dart';

void main() {
  group('AppPermissionUtils.canEditDepartments', () {
    test('allows explicit owners to edit in child organisations', () {
      for (final type in ['child', ' ChIlD ']) {
        expect(
          AppPermissionUtils.canEditDepartments(
            user: User(isOwner: true, roles: const ['team_member']),
            currentOrganization: _organization(type),
          ),
          isTrue,
        );
      }
    });

    test('keeps child departments read-only without the owner flag', () {
      for (final user in <User?>[
        null,
        User(isOwner: false, roles: const ['owner']),
        User(roles: const ['owner', 'csuite']),
        User(hasSandboxAccess: true),
      ]) {
        expect(
          AppPermissionUtils.canEditDepartments(
            user: user,
            currentOrganization: _organization('child'),
          ),
          isFalse,
        );
      }
    });

    test('preserves existing access outside child organisations', () {
      for (final type in ['parent', 'sandbox']) {
        for (final user in <User?>[null, User(), User(isOwner: true)]) {
          expect(
            AppPermissionUtils.canEditDepartments(
              user: user,
              currentOrganization: _organization(type),
            ),
            isTrue,
          );
        }
      }
    });
  });

  group('AppPermissionUtils.canManagePublicLinks', () {
    test('requires the explicit owner flag regardless of role names', () {
      for (final isOwner in <bool?>[null, false, true]) {
        for (final role in [
          'owner',
          'csuite',
          'c_suite',
          'dept_lead',
          'team_lead',
          'team_member',
        ]) {
          expect(
            AppPermissionUtils.canManagePublicLinks(
              user: User(isOwner: isOwner, roles: [role]),
              currentOrganization: _organization('parent'),
            ),
            isOwner == true,
            reason: '$role with isOwner=$isOwner',
          );
        }
      }
      expect(
        AppPermissionUtils.canManagePublicLinks(
          user: null,
          currentOrganization: null,
        ),
        isFalse,
      );
    });

    test('keeps child organisations read-only even for explicit owners', () {
      expect(
        AppPermissionUtils.canManagePublicLinks(
          user: User(isOwner: true, roles: ['owner']),
          currentOrganization: _organization('child'),
        ),
        isFalse,
      );
    });
  });

  group('AppPermissionUtils.canAccessScopedCreateEntry', () {
    test('allows owner accounts to open scoped create flows', () {
      final canAccess = AppPermissionUtils.canAccessScopedCreateEntry(
        User(isOwner: true),
        currentOrganization: _organization('parent'),
      );

      expect(canAccess, isTrue);
    });

    test('does not allow accounts with an empty roles list', () {
      final canAccess = AppPermissionUtils.canAccessScopedCreateEntry(
        User(roles: const <String>[]),
        currentOrganization: _organization('parent'),
      );

      expect(canAccess, isFalse);
    });

    test('does not allow accounts that are only team members', () {
      final canAccess = AppPermissionUtils.canAccessScopedCreateEntry(
        User(roles: const <String>['team_member']),
        currentOrganization: _organization('parent'),
      );

      expect(canAccess, isFalse);
    });

    test('prefers elevated roles when team member is also present', () {
      final canAccess = AppPermissionUtils.canAccessScopedCreateEntry(
        User(roles: const <String>['team_member', 'team_lead']),
        currentOrganization: _organization('parent'),
      );

      expect(canAccess, isTrue);
    });

    test('allows any non-team-member role to open scoped create flows', () {
      final canAccess = AppPermissionUtils.canAccessScopedCreateEntry(
        User(roles: const <String>['dept_lead']),
        currentOrganization: _organization('parent'),
      );

      expect(canAccess, isTrue);
    });
  });

  group('child organisation content permissions', () {
    final accounts = <String, User?>{
      'owner flag': User(isOwner: true),
      'owner flag with team member role': User(
        isOwner: true,
        roles: const <String>['team_member'],
      ),
      'owner role': User(roles: const <String>['owner']),
      'sandbox access': User(hasSandboxAccess: true),
      'owner with sandbox access': User(isOwner: true, hasSandboxAccess: true),
      'csuite': User(roles: const <String>['csuite']),
      'c_suite alias': User(roles: const <String>['c_suite']),
      for (final role in <String>['dept_lead', 'team_lead'])
        role: User(
          roles: <String>[role],
          hierarchyMemberships: <UserHierarchyMembership>[
            UserHierarchyMembership(
              nodeUuid: 'node-1',
              role: role,
              departmentUuid: 'dept-1',
              manageableSeatProfileIds: const <String>['seat-1'],
            ),
          ],
        ),
      'supervisor': User(roles: const <String>['supervisor']),
      'team member': User(roles: const <String>['team_member']),
      'mixed roles': User(roles: const <String>['team_member', 'owner']),
      'empty roles': User(roles: const <String>[]),
      'no user': null,
    };

    for (final type in <String>['child', ' ChIlD ']) {
      for (final account in accounts.entries) {
        test('blocks ${account.key} in organisation type "$type"', () {
          final permissions = _contentPermissions(
            account.value,
            _organization(type),
          );

          for (final permission in permissions.entries) {
            expect(permission.value, isFalse, reason: permission.key);
          }
        });
      }
    }

    for (final type in <String>['parent', 'sandbox']) {
      for (final account in <User>[
        User(isOwner: true),
        User(roles: const <String>['owner']),
      ]) {
        test('preserves owner content access in $type organisations', () {
          final permissions = _contentPermissions(account, _organization(type));

          for (final permission in permissions.entries) {
            expect(permission.value, isTrue, reason: permission.key);
          }
        });
      }
    }

    test('keeps owner sandbox and team viewing access', () {
      final owner = User(isOwner: true);

      expect(AppPermissionUtils.canAccessSandbox(owner), isTrue);
      expect(AppPermissionUtils.canAccessAuditTeamMembers(owner), isTrue);
    });
  });

  group('sandbox training permissions', () {
    for (final type in ['parent', 'sandbox', 'child', ' ChIlD ']) {
      for (final hasSandboxAccess in <bool?>[null, false, true]) {
        test('sandbox access $hasSandboxAccess in $type organisations', () {
          final user = User(
            isOwner: false,
            roles: const ['team_member'],
            hasSandboxAccess: hasSandboxAccess,
          );
          final organization = _organization(type);
          expect(
            AppPermissionUtils.canManageAnyTrainingModules(
              user: user,
              currentOrganization: organization,
            ),
            isFalse,
          );
          for (final seatProfileId in ['seat-1', '']) {
            expect(
              AppPermissionUtils.canManageTrainingForSeatProfile(
                user: user,
                currentOrganization: organization,
                seatProfileId: seatProfileId,
              ),
              isFalse,
            );
            expect(
              AppPermissionUtils.canViewTrainingQuizAndAssignment(
                user: user,
                currentOrganization: organization,
                seatProfileId: seatProfileId,
              ),
              isFalse,
            );
          }
          expect(
            AppPermissionUtils.canManagePublicLinks(
              user: user,
              currentOrganization: organization,
            ),
            isFalse,
          );
          expect(
            AppPermissionUtils.canManagePaygrades(
              user: user,
              currentOrganization: organization,
            ),
            isFalse,
          );
        });
      }
    }

    test('owner access remains unchanged across sandbox flags', () {
      for (final type in ['parent', 'sandbox', 'child']) {
        for (final hasSandboxAccess in <bool?>[null, false, true]) {
          final user = User(
            isOwner: true,
            roles: const ['team_member'],
            hasSandboxAccess: hasSandboxAccess,
          );
          expect(
            AppPermissionUtils.canManageAnyTrainingModules(
              user: user,
              currentOrganization: _organization(type),
            ),
            type != 'child',
          );
          expect(
            AppPermissionUtils.canManageTrainingForSeatProfile(
              user: user,
              currentOrganization: _organization(type),
              seatProfileId: '',
            ),
            type != 'child',
          );
          expect(
            AppPermissionUtils.canViewTrainingQuizAndAssignment(
              user: user,
              currentOrganization: _organization(type),
              seatProfileId: '',
            ),
            hasSandboxAccess == true || type != 'child',
          );
        }
      }
    });

    test('sandbox tab access preserves department lead editing scope', () {
      for (final hasSandboxAccess in [false, true]) {
        final user = User(
          roles: const ['dept_lead'],
          hasSandboxAccess: hasSandboxAccess,
          hierarchyMemberships: const [
            UserHierarchyMembership(
              nodeUuid: 'node',
              role: 'dept_lead',
              manageableSeatProfileIds: ['managed-seat'],
            ),
          ],
        );
        for (final type in ['parent', 'child']) {
          for (final seat in ['managed-seat', 'other-seat']) {
            final canEdit = type != 'child' && seat == 'managed-seat';
            expect(
              AppPermissionUtils.canManageTrainingForSeatProfile(
                user: user,
                currentOrganization: _organization(type),
                seatProfileId: seat,
              ),
              canEdit,
            );
            expect(
              AppPermissionUtils.canViewTrainingQuizAndAssignment(
                user: user,
                currentOrganization: _organization(type),
                seatProfileId: seat,
              ),
              (hasSandboxAccess && seat == 'managed-seat') || canEdit,
            );
          }
        }
      }
    });

    test(
      'sandbox viewing requires a managed seat without granting editing',
      () {
        for (final type in ['parent', 'sandbox', 'child']) {
          for (final hasSandboxAccess in <bool?>[null, false, true]) {
            final user = User(
              roles: const ['team_member'],
              hasSandboxAccess: hasSandboxAccess,
              hierarchyMemberships: const [
                UserHierarchyMembership(
                  nodeUuid: 'node',
                  role: 'team_member',
                  job: OrganizationHierarchyJob(
                    uuid: 'own-seat',
                    title: 'Own Seat',
                  ),
                  manageableSeatProfileIds: ['managed-seat'],
                ),
              ],
            );
            for (final seat in [
              'managed-seat',
              ' MANAGED-SEAT ',
              'own-seat',
              'other-seat',
              '',
            ]) {
              expect(
                AppPermissionUtils.canViewTrainingQuizAndAssignment(
                  user: user,
                  currentOrganization: _organization(type),
                  seatProfileId: seat,
                ),
                hasSandboxAccess == true &&
                    seat.trim().toLowerCase() == 'managed-seat',
                reason: '$type sandbox=$hasSandboxAccess seat=$seat',
              );
              expect(
                AppPermissionUtils.canManageTrainingForSeatProfile(
                  user: user,
                  currentOrganization: _organization(type),
                  seatProfileId: seat,
                ),
                isFalse,
              );
            }
          }
        }
      },
    );
  });

  group('AppPermissionUtils.canManageTrainingForSeatProfile', () {
    const parentOrganization = Organization(
      id: 'org-1',
      name: 'Parent Org',
      website: null,
      contactNo: null,
      address: null,
      createdAt: '2026-08-28T00:00:00.000Z',
      type: 'parent',
      logoUrl: null,
    );

    test('allows managers to edit explicitly managed child seat profiles', () {
      final user = User(
        roles: const <String>['dept_lead'],
        hierarchyMemberships: const <UserHierarchyMembership>[
          UserHierarchyMembership(
            nodeUuid: 'node-1',
            role: 'dept_lead',
            manageableSeatProfileIds: <String>['seat-42'],
          ),
        ],
      );

      final canManage = AppPermissionUtils.canManageTrainingForSeatProfile(
        user: user,
        currentOrganization: parentOrganization,
        seatProfileId: 'seat-42',
      );

      expect(canManage, isTrue);
    });

    test('does not allow unlisted seat profiles for lead accounts', () {
      final user = User(
        roles: const <String>['dept_lead'],
        hierarchyMemberships: const <UserHierarchyMembership>[
          UserHierarchyMembership(
            nodeUuid: 'node-1',
            role: 'dept_lead',
            job: OrganizationHierarchyJob(uuid: 'seat-1', title: 'Lead Seat'),
            manageableSeatProfileIds: <String>['seat-managed'],
          ),
        ],
      );

      final canManage = AppPermissionUtils.canManageTrainingForSeatProfile(
        user: user,
        currentOrganization: parentOrganization,
        seatProfileId: 'seat-1',
      );

      expect(canManage, isFalse);
    });

    test('matches manageable seat ids across normalized alternate ids', () {
      final user = User(
        roles: const <String>['team_lead'],
        hierarchyMemberships: const <UserHierarchyMembership>[
          UserHierarchyMembership(
            nodeUuid: 'node-1',
            role: 'team_lead',
            manageableSeatProfileIds: <String>[' seat-managed '],
          ),
        ],
      );

      final canManage = AppPermissionUtils.canManageTrainingForSeatProfile(
        user: user,
        currentOrganization: parentOrganization,
        seatProfileId: 'seat-public-id',
        additionalSeatProfileIds: const <String>['SEAT-MANAGED'],
      );

      expect(canManage, isTrue);
    });

    test(
      'prefers team lead access when another membership is only team member',
      () {
        final user = User(
          roles: const <String>['team_lead', 'team_member'],
          hierarchyMemberships: const <UserHierarchyMembership>[
            UserHierarchyMembership(
              nodeUuid: 'node-member',
              role: 'team_member',
              job: OrganizationHierarchyJob(
                uuid: 'seat-own',
                title: 'Own Seat',
              ),
            ),
            UserHierarchyMembership(
              nodeUuid: 'node-lead',
              role: 'team_lead',
              job: OrganizationHierarchyJob(
                uuid: 'seat-own',
                title: 'Own Seat',
              ),
              manageableSeatProfileIds: <String>['seat-managed'],
            ),
          ],
        );

        final canManage = AppPermissionUtils.canManageTrainingForSeatProfile(
          user: user,
          currentOrganization: parentOrganization,
          seatProfileId: 'seat-own',
          additionalSeatProfileIds: const <String>['seat-managed'],
        );

        expect(canManage, isTrue);
      },
    );

    test('does not allow training management when the roles list is empty', () {
      final user = User(
        roles: const <String>[],
        hierarchyMemberships: const <UserHierarchyMembership>[
          UserHierarchyMembership(
            nodeUuid: 'node-1',
            role: 'team_lead',
            manageableSeatProfileIds: <String>['seat-managed'],
          ),
        ],
      );

      final canManage = AppPermissionUtils.canManageTrainingForSeatProfile(
        user: user,
        currentOrganization: parentOrganization,
        seatProfileId: 'seat-managed',
      );

      expect(canManage, isFalse);
    });

    test(
      'allows csuite users to manage training without explicit seat mappings',
      () {
        final user = User(roles: const <String>['c_suite']);

        final canManage = AppPermissionUtils.canManageTrainingForSeatProfile(
          user: user,
          currentOrganization: parentOrganization,
          seatProfileId: 'seat-99',
        );

        expect(canManage, isTrue);
      },
    );
  });

  group('AppPermissionUtils seat profile permissions', () {
    const parentOrganization = Organization(
      id: 'org-1',
      name: 'Parent Org',
      website: null,
      contactNo: null,
      address: null,
      createdAt: '2026-08-28T00:00:00.000Z',
      type: 'parent',
      logoUrl: null,
    );

    test(
      'allows department leads to manage seat profiles in their department',
      () {
        final user = User(
          roles: const <String>['dept_lead'],
          hierarchyMemberships: const <UserHierarchyMembership>[
            UserHierarchyMembership(
              nodeUuid: 'node-1',
              role: 'dept_lead',
              departmentUuid: 'dept-1',
            ),
          ],
        );

        final canManage = AppPermissionUtils.canManageSeatProfileDepartment(
          user: user,
          currentOrganization: parentOrganization,
          departmentId: 'dept-1',
        );

        expect(canManage, isTrue);
      },
    );

    test(
      'does not allow seat profile edits outside the managed department',
      () {
        final user = User(
          roles: const <String>['team_lead'],
          hierarchyMemberships: const <UserHierarchyMembership>[
            UserHierarchyMembership(
              nodeUuid: 'node-1',
              role: 'team_lead',
              departmentUuid: 'dept-1',
            ),
          ],
        );

        final canManage = AppPermissionUtils.canManageSeatProfileDepartment(
          user: user,
          currentOrganization: parentOrganization,
          departmentId: 'dept-2',
        );

        expect(canManage, isFalse);
      },
    );

    test(
      'does not allow seat profile creation when a lead account has no department scope',
      () {
        final user = User(roles: const <String>['team_lead']);

        final canCreate = AppPermissionUtils.canCreateSeatProfiles(
          user: user,
          currentOrganization: parentOrganization,
        );

        expect(canCreate, isFalse);
      },
    );

    test(
      'allows c_suite aliases to manage seat profiles across departments',
      () {
        final user = User(roles: const <String>['c_suite']);

        final canManage = AppPermissionUtils.canManageSeatProfileDepartment(
          user: user,
          currentOrganization: parentOrganization,
          departmentId: 'dept-9',
        );

        expect(canManage, isTrue);
      },
    );
  });

  group('AppPermissionUtils.canManagePaygrades', () {
    const parentOrganization = Organization(
      id: 'org-1',
      name: 'Parent Org',
      website: null,
      contactNo: null,
      address: null,
      createdAt: '2026-08-28T00:00:00.000Z',
      type: 'parent',
      logoUrl: null,
    );

    test('allows owners to manage paygrades', () {
      final user = User(isOwner: true);

      final canManage = AppPermissionUtils.canManagePaygrades(
        user: user,
        currentOrganization: parentOrganization,
      );

      expect(canManage, isTrue);
    });

    test('allows c_suite accounts to manage paygrades', () {
      final user = User(roles: const <String>['c_suite']);

      final canManage = AppPermissionUtils.canManagePaygrades(
        user: user,
        currentOrganization: parentOrganization,
      );

      expect(canManage, isTrue);
    });

    test('does not allow team leads to manage paygrades', () {
      final user = User(roles: const <String>['team_lead']);

      final canManage = AppPermissionUtils.canManagePaygrades(
        user: user,
        currentOrganization: parentOrganization,
      );

      expect(canManage, isFalse);
    });
  });

  group('OrganizationHierarchyNode.collectMembershipsForUser', () {
    test(
      'uses only the matched user node children as managed seat profiles',
      () {
        const loggedInProfileUuid = '2095f56d-0917-403a-b3aa-b98405460dcd';
        final rootNode = OrganizationHierarchyNode(
          uuid: '8b131d82-b6ab-452b-9fa8-b88755843e52',
          role: 'team_lead',
          job: const OrganizationHierarchyJob(
            uuid: '48b7e158-c1d8-4c4f-aa7b-cf28928c82e3',
            title: 'Frontend dev',
          ),
          profile: const OrganizationHierarchyProfile(
            name: 'Haseem Assistant',
            uuid: loggedInProfileUuid,
            email: 'haseemhussain761@gmail.com',
            image: 'https://media-dev.kaizenteams.ai/example.jpg',
            onboarded: true,
            userUuid: 'ccaf92a0-a5da-4227-a8b6-e1f136a75c3d',
          ),
          departmentUuid: '3a94043c-97e9-4dd0-8fbb-eebead1fcbdd',
          children: <OrganizationHierarchyNode>[
            OrganizationHierarchyNode(
              uuid: '5b9e5005-cb6a-4bd5-b287-f9267d3ebfa3',
              role: 'team_lead',
              job: const OrganizationHierarchyJob(
                uuid: 'ca901124-b4ea-4cd0-a594-5f1686ac03ff',
                title: 'Backend Dev',
              ),
              profile: const OrganizationHierarchyProfile(
                name: 'Gretchen Bradford',
                uuid: 'bcc954e5-6072-4a7b-b5ff-76d60ae4ad80',
                email: 'paze@mailinator.com',
                onboarded: true,
                userUuid: '287827f8-86d2-48f8-99ce-8c05ce5040b1',
              ),
              departmentUuid: '3a94043c-97e9-4dd0-8fbb-eebead1fcbdd',
              children: <OrganizationHierarchyNode>[
                OrganizationHierarchyNode(
                  uuid: 'grandchild-node',
                  role: 'team_member',
                  job: const OrganizationHierarchyJob(
                    uuid: 'grandchild-seat',
                    title: 'QA Dev',
                  ),
                  profile: const OrganizationHierarchyProfile(
                    name: 'Nested Report',
                    uuid: 'nested-profile',
                  ),
                ),
              ],
            ),
          ],
        );

        final memberships = rootNode.collectMembershipsForUser(<String>{
          loggedInProfileUuid.toLowerCase(),
        });

        expect(memberships, hasLength(1));
        expect(memberships.single.normalizedRole, 'team_lead');
        expect(memberships.single.manageableSeatProfileIds, const <String>[
          'ca901124-b4ea-4cd0-a594-5f1686ac03ff',
        ]);
      },
    );
  });
}

Organization _organization(String type) {
  return Organization(
    id: 'org-1',
    name: 'Test organisation',
    website: null,
    contactNo: null,
    address: null,
    createdAt: '2026-09-07T00:00:00.000Z',
    type: type,
    logoUrl: null,
  );
}

Map<String, bool> _contentPermissions(User? user, Organization organization) {
  return <String, bool>{
    'organisation content':
        AppPermissionUtils.canModifyCurrentOrganizationContent(
          currentOrganization: organization,
        ),
    'main create entry': AppPermissionUtils.canAccessScopedCreateEntry(
      user,
      currentOrganization: organization,
    ),
    'seat profile creation': AppPermissionUtils.canCreateSeatProfiles(
      user: user,
      currentOrganization: organization,
    ),
    'seat profile department management':
        AppPermissionUtils.canManageAnySeatProfileDepartments(
          user: user,
          currentOrganization: organization,
        ),
    'specific seat profile department management':
        AppPermissionUtils.canManageSeatProfileDepartment(
          user: user,
          currentOrganization: organization,
          departmentId: 'dept-1',
        ),
    'seat profile with no department':
        AppPermissionUtils.canManageSeatProfileDepartment(
          user: user,
          currentOrganization: organization,
          departmentId: '',
        ),
    'training management': AppPermissionUtils.canManageAnyTrainingModules(
      user: user,
      currentOrganization: organization,
    ),
    'specific seat training management':
        AppPermissionUtils.canManageTrainingForSeatProfile(
          user: user,
          currentOrganization: organization,
          seatProfileId: 'seat-1',
        ),
    'training with no seat': AppPermissionUtils.canManageTrainingForSeatProfile(
      user: user,
      currentOrganization: organization,
      seatProfileId: '',
    ),
    'paygrade management': AppPermissionUtils.canManagePaygrades(
      user: user,
      currentOrganization: organization,
    ),
  };
}
