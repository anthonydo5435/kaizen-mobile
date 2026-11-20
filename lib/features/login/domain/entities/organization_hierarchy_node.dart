import 'organization_hierarchy_job.dart';
import 'organization_hierarchy_profile.dart';
import 'user_hierarchy_membership.dart';

class OrganizationHierarchyNode {
  const OrganizationHierarchyNode({
    required this.uuid,
    required this.role,
    this.title,
    this.profile,
    this.job,
    this.children = const <OrganizationHierarchyNode>[],
    this.colorHex,
    this.isPrimary = false,
    this.isEmployed = false,
    this.parentUuid,
    this.departmentUuid,
    this.isPaygradePending = false,
    this.paygradeAssignmentExists = false,
  });

  final String uuid;
  final String role;
  final String? title;
  final OrganizationHierarchyProfile? profile;
  final OrganizationHierarchyJob? job;
  final List<OrganizationHierarchyNode> children;
  final String? colorHex;
  final bool isPrimary;
  final bool isEmployed;
  final String? parentUuid;
  final String? departmentUuid;
  final bool isPaygradePending;
  final bool paygradeAssignmentExists;

  factory OrganizationHierarchyNode.fromJson(Map<String, dynamic> json) {
    final profileJson = _readMap(json['profile']);
    final jobJson = _readMap(json['job']);
    final rawChildren = json['children'];

    return OrganizationHierarchyNode(
      uuid: json['uuid']?.toString().trim() ?? '',
      role: json['role']?.toString().trim() ?? '',
      title: _readNullableString(json['title']),
      profile: profileJson == null
          ? null
          : OrganizationHierarchyProfile.fromJson(profileJson),
      job: jobJson == null ? null : OrganizationHierarchyJob.fromJson(jobJson),
      children: rawChildren is List
          ? rawChildren
                .whereType<Map<String, dynamic>>()
                .map(OrganizationHierarchyNode.fromJson)
                .toList(growable: false)
          : const <OrganizationHierarchyNode>[],
      colorHex: _readNullableString(json['color_hex'] ?? json['colorHex']),
      isPrimary: json['is_primary'] == true || json['isPrimary'] == true,
      isEmployed: json['is_employed'] == true || json['isEmployed'] == true,
      parentUuid: _readNullableString(
        json['parent_uuid'] ?? json['parentUuid'],
      ),
      departmentUuid: _readNullableString(
        json['department_uuid'] ?? json['departmentUuid'],
      ),
      isPaygradePending:
          json['is_paygrade_pending'] == true ||
          json['isPaygradePending'] == true,
      paygradeAssignmentExists:
          json['paygrade_assignment_exists'] == true ||
          json['paygradeAssignmentExists'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'uuid': uuid,
      'role': role,
      'title': title,
      'profile': profile?.toJson(),
      'job': job?.toJson(),
      'children': children
          .map((child) => child.toJson())
          .toList(growable: false),
      'color_hex': colorHex,
      'is_primary': isPrimary,
      'is_employed': isEmployed,
      'parent_uuid': parentUuid,
      'department_uuid': departmentUuid,
      'is_paygrade_pending': isPaygradePending,
      'paygrade_assignment_exists': paygradeAssignmentExists,
    };
  }

  List<UserHierarchyMembership> collectMembershipsForUser(
    Set<String> userIdentifiers,
  ) {
    if (userIdentifiers.isEmpty) {
      return const <UserHierarchyMembership>[];
    }

    final memberships = <UserHierarchyMembership>[];
    final seenMembershipKeys = <String>{};
    _collectMembershipsForUser(
      userIdentifiers: userIdentifiers,
      memberships: memberships,
      seenMembershipKeys: seenMembershipKeys,
    );
    return List<UserHierarchyMembership>.unmodifiable(memberships);
  }

  void _collectMembershipsForUser({
    required Set<String> userIdentifiers,
    required List<UserHierarchyMembership> memberships,
    required Set<String> seenMembershipKeys,
  }) {
    if (_matchesUserIdentifiers(userIdentifiers)) {
      final membership = toUserHierarchyMembership(
        manageableSeatProfileIds: _resolveManageableSeatProfileIds(),
      );
      final membershipKey = _membershipKey(membership);
      if (seenMembershipKeys.add(membershipKey)) {
        memberships.add(membership);
      }
    }

    for (final child in children) {
      child._collectMembershipsForUser(
        userIdentifiers: userIdentifiers,
        memberships: memberships,
        seenMembershipKeys: seenMembershipKeys,
      );
    }
  }

  bool _matchesUserIdentifiers(Set<String> userIdentifiers) {
    final resolvedProfile = profile;
    if (resolvedProfile == null) {
      return false;
    }

    final profileIdentifiers = <String>{
      _normalizeIdentifier(resolvedProfile.userUuid),
      _normalizeIdentifier(resolvedProfile.uuid),
      _normalizeIdentifier(resolvedProfile.email),
    }..removeWhere((value) => value.isEmpty);

    for (final identifier in profileIdentifiers) {
      if (userIdentifiers.contains(identifier)) {
        return true;
      }
    }

    return false;
  }

  UserHierarchyMembership toUserHierarchyMembership({
    List<String> manageableSeatProfileIds = const <String>[],
  }) {
    return UserHierarchyMembership(
      nodeUuid: uuid,
      role: role,
      title: title,
      profile: profile,
      job: job,
      colorHex: colorHex,
      isPrimary: isPrimary,
      isEmployed: isEmployed,
      parentUuid: parentUuid,
      departmentUuid: departmentUuid,
      isPaygradePending: isPaygradePending,
      paygradeAssignmentExists: paygradeAssignmentExists,
      manageableSeatProfileIds: manageableSeatProfileIds,
    );
  }

  List<String> _resolveManageableSeatProfileIds() {
    final seatProfileIds = <String>[];
    final seenSeatProfileIds = <String>{};

    for (final child in children) {
      final jobUuid = child.job?.uuid.trim() ?? '';
      final normalizedJobUuid = _normalizeIdentifier(jobUuid);
      if (normalizedJobUuid.isNotEmpty &&
          seenSeatProfileIds.add(normalizedJobUuid)) {
        seatProfileIds.add(jobUuid);
      }
    }

    return List<String>.unmodifiable(seatProfileIds);
  }

  String _membershipKey(UserHierarchyMembership membership) {
    final nodeUuid = membership.nodeUuid.trim();
    if (nodeUuid.isNotEmpty) {
      return nodeUuid;
    }

    return [
      membership.departmentUuid?.trim() ?? '',
      membership.parentUuid?.trim() ?? '',
      membership.normalizedRole,
      membership.profile?.userUuid?.trim() ?? '',
      membership.profile?.uuid.trim() ?? '',
      membership.profile?.email?.trim().toLowerCase() ?? '',
    ].join('|');
  }
}

Map<String, dynamic>? _readMap(dynamic value) {
  if (value is Map<String, dynamic>) {
    return value;
  }

  return null;
}

String? _readNullableString(dynamic value) {
  final resolvedValue = value?.toString().trim();
  if (resolvedValue == null || resolvedValue.isEmpty) {
    return null;
  }

  return resolvedValue;
}

String _normalizeIdentifier(String? value) {
  return value?.trim().toLowerCase() ?? '';
}
