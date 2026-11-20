import '../../features/login/domain/entities/user.dart';
import '../../features/login/domain/entities/user_hierarchy_membership.dart';
import '../../features/organizations/domain/entities/organization.dart';

class AppPermissionUtils {
  const AppPermissionUtils._();

  static const Set<String> _scopedManagerRoles = <String>{
    'dept_lead',
    'team_lead',
  };

  static bool hasOwnerOverrideAccess(User? user) {
    final availableRoles = user?.normalizedRoles.toSet() ?? const <String>{};
    return user?.isOwner == true || availableRoles.contains('owner');
  }

  static bool hasOwnerManagementAccess(User? user) {
    return hasOwnerOverrideAccess(user) || _isTopOperatorOrIntegrator(user);
  }

  static bool hasReadOnlyPersonalCheckIns(User? user) {
    return user?.isOwner != true && _isTopOperatorOrIntegrator(user);
  }

  static bool _isTopOperatorOrIntegrator(User? user) {
    return user?.isTopOperator == true || user?.isIntegrator == true;
  }

  static bool canAccessAuditTeamMembers(User? user) {
    final availableRoles = user?.normalizedRoles.toSet() ?? const <String>{};
    return hasOwnerManagementAccess(user) ||
        availableRoles.contains('csuite') ||
        availableRoles.contains('dept_lead') ||
        availableRoles.contains('supervisor') ||
        availableRoles.contains('team_lead');
  }

  static bool shouldShowAuditTeamMembersTab(User? user) {
    return hasReadOnlyPersonalCheckIns(user) ||
        (!hasOwnerOverrideAccess(user) && canAccessAuditTeamMembers(user));
  }

  static bool isChildOrganization(Organization? organization) {
    return organization?.type.trim().toLowerCase() == 'child';
  }

  static bool canModifyCurrentOrganizationContent({
    required Organization? currentOrganization,
  }) {
    // Organisation type is metadata; feature permissions determine access.
    return true;
  }

  static bool canEditDepartments({
    required User? user,
    required Organization? currentOrganization,
  }) {
    return true;
  }

  static bool canManagePublicLinks({
    required User? user,
    required Organization? currentOrganization,
  }) {
    return user?.isOwner == true;
  }

  static bool canAccessScopedCreateEntry(
    User? user, {
    required Organization? currentOrganization,
  }) {
    if (hasOwnerManagementAccess(user)) {
      return true;
    }

    final availableRoles = user?.normalizedRoles.toSet() ?? const <String>{};
    return availableRoles.any(_isElevatedCreateRole);
  }

  static bool canCreateSeatProfiles({
    required User? user,
    required Organization? currentOrganization,
  }) {
    return canManageAnySeatProfileDepartments(
      user: user,
      currentOrganization: currentOrganization,
    );
  }

  static bool canManageAnySeatProfileDepartments({
    required User? user,
    required Organization? currentOrganization,
  }) {
    if (hasOwnerManagementAccess(user)) {
      return true;
    }

    final availableRoles = user?.normalizedRoles.toSet() ?? const <String>{};
    if (availableRoles.contains('csuite')) {
      return true;
    }

    if (!availableRoles.any(_scopedManagerRoles.contains)) {
      return false;
    }

    for (final membership
        in user?.hierarchyMemberships ?? const <UserHierarchyMembership>[]) {
      if (membership.canManageSeatProfileDepartments &&
          membership.hasDepartmentScope) {
        return true;
      }
    }

    return false;
  }

  static bool canManageSeatProfileDepartment({
    required User? user,
    required Organization? currentOrganization,
    required String departmentId,
  }) {
    if (hasOwnerManagementAccess(user)) {
      return true;
    }

    final availableRoles = user?.normalizedRoles.toSet() ?? const <String>{};
    if (availableRoles.contains('csuite')) {
      return true;
    }

    final normalizedDepartmentId = _normalizeIdentifier(departmentId);
    if (normalizedDepartmentId.isEmpty) {
      return false;
    }

    if (!availableRoles.any(_scopedManagerRoles.contains)) {
      return false;
    }

    for (final membership
        in user?.hierarchyMemberships ?? const <UserHierarchyMembership>[]) {
      if (membership.canManageSeatProfileDepartments &&
          membership.managesDepartment(normalizedDepartmentId)) {
        return true;
      }
    }

    return false;
  }

  static bool canManageAnyTrainingModules({
    required User? user,
    required Organization? currentOrganization,
  }) {
    if (hasOwnerManagementAccess(user)) {
      return true;
    }

    final availableRoles = user?.normalizedRoles.toSet() ?? const <String>{};
    if (availableRoles.contains('csuite')) {
      return true;
    }

    if (!availableRoles.any(_scopedManagerRoles.contains)) {
      return false;
    }

    for (final membership
        in user?.hierarchyMemberships ?? const <UserHierarchyMembership>[]) {
      if (membership.hasOrganizationWideTrainingManagement ||
          (membership.canManageTrainingModules &&
              membership.hasManagedSeatProfiles)) {
        return true;
      }
    }

    return false;
  }

  static bool canManageTrainingForSeatProfile({
    required User? user,
    required Organization? currentOrganization,
    required String seatProfileId,
    Iterable<String> additionalSeatProfileIds = const <String>[],
  }) {
    if (hasOwnerManagementAccess(user)) {
      return true;
    }

    final normalizedSeatProfileIds = _normalizeIdentifierSet(<String>[
      seatProfileId,
      ...additionalSeatProfileIds,
    ]);
    if (normalizedSeatProfileIds.isEmpty) {
      return false;
    }

    final availableRoles = user?.normalizedRoles.toSet() ?? const <String>{};
    if (availableRoles.contains('csuite')) {
      return true;
    }

    if (!availableRoles.any(_scopedManagerRoles.contains)) {
      return false;
    }

    for (final membership
        in user?.hierarchyMemberships ?? const <UserHierarchyMembership>[]) {
      if (!membership.canManageTrainingModules) {
        continue;
      }

      if (membership.hasOrganizationWideTrainingManagement) {
        return true;
      }

      for (final candidateSeatProfileId in normalizedSeatProfileIds) {
        if (membership.managesSeatProfile(candidateSeatProfileId)) {
          return true;
        }
      }
    }

    return false;
  }

  static bool isAssignedToTrainingSeatProfile({
    required User? user,
    required String seatProfileId,
    Iterable<String> additionalSeatProfileIds = const <String>[],
  }) {
    final seatIds = _normalizeIdentifierSet([
      seatProfileId,
      ...additionalSeatProfileIds,
    ]);
    return user?.hierarchyMemberships?.any(
          (membership) =>
              seatIds.contains(_normalizeIdentifier(membership.job?.uuid)),
        ) ==
        true;
  }

  static bool canViewTrainingQuizAndAssignment({
    required User? user,
    required Organization? currentOrganization,
    required String seatProfileId,
    Iterable<String> additionalSeatProfileIds = const <String>[],
  }) {
    final managesSeat =
        user?.hierarchyMemberships?.any(
          (membership) =>
              membership.managesSeatProfile(seatProfileId) ||
              additionalSeatProfileIds.any(membership.managesSeatProfile),
        ) ==
        true;
    return managesSeat ||
        isAssignedToTrainingSeatProfile(
          user: user,
          seatProfileId: seatProfileId,
          additionalSeatProfileIds: additionalSeatProfileIds,
        ) ||
        canManageTrainingForSeatProfile(
          user: user,
          currentOrganization: currentOrganization,
          seatProfileId: seatProfileId,
          additionalSeatProfileIds: additionalSeatProfileIds,
        );
  }

  static bool canManagePaygrades({
    required User? user,
    required Organization? currentOrganization,
  }) {
    if (hasOwnerManagementAccess(user)) {
      return true;
    }

    final availableRoles = user?.normalizedRoles.toSet() ?? const <String>{};
    return availableRoles.contains('csuite');
  }

  static Set<String> _normalizeIdentifierSet(Iterable<String?> values) {
    final normalizedValues = <String>{};
    for (final value in values) {
      final normalizedValue = _normalizeIdentifier(value);
      if (normalizedValue.isNotEmpty) {
        normalizedValues.add(normalizedValue);
      }
    }
    return normalizedValues;
  }

  static String _normalizeIdentifier(String? value) {
    return value?.trim().toLowerCase() ?? '';
  }

  static bool _isElevatedCreateRole(String role) {
    return role.isNotEmpty && role != 'team_member';
  }
}
