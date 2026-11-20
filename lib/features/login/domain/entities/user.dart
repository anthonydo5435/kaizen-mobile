import 'user_hierarchy_membership.dart';
import 'user_role_utils.dart';

class User {
  /// Organisation profile UUID, used by Check-in and hierarchy matching.
  final String? uuid;
  final String? status;
  final String? driveId;
  final bool? onboarded;
  final String? organizationUuid;
  final String? name;
  final String? email;
  final String? image;
  final String? imageUuid;
  final String? gender;
  final Signature? signature;

  /// Account UUID, used by account/profile update endpoints.
  final String? userUuid;
  final String? imageUrl;
  final String? lastName;
  final String? firstName;
  final String? contactNo;
  final DateTime? dateJoined;
  final dynamic userProgress;
  final ProfileAddress? profileAddress;
  final bool? isEmailVerified;
  final dynamic envelope;
  final bool? isOwner;
  final DateTime? lastLogin;
  final bool? isIntegrator;
  final bool? isTopOperator;
  final List<String>? roles;
  final bool? isInActiveOrganization;
  final bool? hasSandboxAccess;
  final String? sandboxUuid;
  final String? feVersion;
  final bool? isPasswordReset;
  final bool? introPending;
  final bool? isOrgRenamed;
  final String? companyUuid;
  final bool? hasPaymentDetailsProvided;
  final String? personalityType;
  final String? dateOfBirth;
  final List<UserHierarchyMembership>? hierarchyMemberships;

  List<String> get normalizedRoles => _normalizeRoles(roles: roles);

  User({
    this.uuid,
    this.status,
    this.driveId,
    this.onboarded,
    this.organizationUuid,
    this.name,
    this.email,
    this.image,
    this.imageUuid,
    this.gender,
    this.signature,
    this.userUuid,
    this.imageUrl,
    this.lastName,
    this.firstName,
    this.contactNo,
    this.dateJoined,
    this.userProgress,
    this.profileAddress,
    this.isEmailVerified,
    this.envelope,
    this.isOwner,
    this.lastLogin,
    this.isIntegrator,
    this.isTopOperator,
    this.roles,
    this.isInActiveOrganization,
    this.hasSandboxAccess,
    this.sandboxUuid,
    this.feVersion,
    this.isPasswordReset,
    this.introPending,
    this.isOrgRenamed,
    this.companyUuid,
    this.hasPaymentDetailsProvided,
    this.personalityType,
    this.dateOfBirth,
    this.hierarchyMemberships,
  });

  User copyWith({
    String? uuid,
    String? status,
    String? driveId,
    bool? onboarded,
    String? organizationUuid,
    String? name,
    String? email,
    String? image,
    String? imageUuid,
    String? gender,
    Signature? signature,
    String? userUuid,
    String? imageUrl,
    String? lastName,
    String? firstName,
    String? contactNo,
    DateTime? dateJoined,
    dynamic userProgress,
    ProfileAddress? profileAddress,
    bool? isEmailVerified,
    dynamic envelope,
    bool? isOwner,
    DateTime? lastLogin,
    bool? isIntegrator,
    bool? isTopOperator,
    List<String>? roles,
    bool? isInActiveOrganization,
    bool? hasSandboxAccess,
    String? sandboxUuid,
    String? feVersion,
    bool? isPasswordReset,
    bool? introPending,
    bool? isOrgRenamed,
    String? companyUuid,
    bool? hasPaymentDetailsProvided,
    String? personalityType,
    String? dateOfBirth,
    List<UserHierarchyMembership>? hierarchyMemberships,
  }) {
    return User(
      uuid: uuid ?? this.uuid,
      status: status ?? this.status,
      driveId: driveId ?? this.driveId,
      onboarded: onboarded ?? this.onboarded,
      organizationUuid: organizationUuid ?? this.organizationUuid,
      name: name ?? this.name,
      email: email ?? this.email,
      image: image ?? this.image,
      imageUuid: imageUuid ?? this.imageUuid,
      gender: gender ?? this.gender,
      signature: signature ?? this.signature,
      userUuid: userUuid ?? this.userUuid,
      imageUrl: imageUrl ?? this.imageUrl,
      lastName: lastName ?? this.lastName,
      firstName: firstName ?? this.firstName,
      contactNo: contactNo ?? this.contactNo,
      dateJoined: dateJoined ?? this.dateJoined,
      userProgress: userProgress ?? this.userProgress,
      profileAddress: profileAddress ?? this.profileAddress,
      isEmailVerified: isEmailVerified ?? this.isEmailVerified,
      envelope: envelope ?? this.envelope,
      isOwner: isOwner ?? this.isOwner,
      lastLogin: lastLogin ?? this.lastLogin,
      isIntegrator: isIntegrator ?? this.isIntegrator,
      isTopOperator: isTopOperator ?? this.isTopOperator,
      roles: roles ?? this.roles,
      isInActiveOrganization:
          isInActiveOrganization ?? this.isInActiveOrganization,
      hasSandboxAccess: hasSandboxAccess ?? this.hasSandboxAccess,
      sandboxUuid: sandboxUuid ?? this.sandboxUuid,
      feVersion: feVersion ?? this.feVersion,
      isPasswordReset: isPasswordReset ?? this.isPasswordReset,
      introPending: introPending ?? this.introPending,
      isOrgRenamed: isOrgRenamed ?? this.isOrgRenamed,
      companyUuid: companyUuid ?? this.companyUuid,
      hasPaymentDetailsProvided:
          hasPaymentDetailsProvided ?? this.hasPaymentDetailsProvided,
      personalityType: personalityType ?? this.personalityType,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      hierarchyMemberships: hierarchyMemberships ?? this.hierarchyMemberships,
    );
  }

  factory User.fromJson(Map<String, dynamic> json) {
    final nestedProfile = _readMap(json['profile']);
    final profile = nestedProfile ?? json;
    // Account fields moved outside profile; older saved users remain flat.
    final account = nestedProfile == null ? json : {...nestedProfile, ...json};
    final image = _readMap(account['image']);
    final imagePath = image == null
        ? _readString(account['image'])
        : _readString(image['url'] ?? image['image']);
    final signature = _readMap(account['signature']);
    final address =
        _readMap(account['address']) ?? _readMap(account['profile_address']);

    return User(
      uuid: _readString(profile['uuid']) ?? _readString(json['uuid']),
      status: _readString(profile['status']),
      driveId: _readString(profile['drive_id']),
      onboarded: profile['onboarded'],
      organizationUuid: _readString(profile['organization_uuid']),
      name: _readString(account['name']),
      email: _readString(account['email']),
      image: imagePath,
      imageUuid: _readString(image?['uuid'] ?? account['image_uuid']),
      gender: _readString(account['gender']),
      signature: signature == null ? null : Signature.fromJson(signature),
      userUuid: nestedProfile == null
          ? _readString(json['user_uuid'])
          : _readString(json['uuid']) ?? _readString(account['user_uuid']),
      imageUrl: _readString(account['image_url']) ?? imagePath,
      lastName: _readString(account['last_name']),
      firstName: _readString(account['first_name']),
      contactNo: _readString(account['contact_no']),
      dateJoined: _parseDate(profile['date_joined']),
      userProgress: account['user_progress'],
      profileAddress: address == null ? null : ProfileAddress.fromJson(address),
      isEmailVerified: account['is_email_verified'],
      envelope: profile['envelope'],
      isOwner: account['is_owner'],
      lastLogin: _parseDate(account['last_login']),
      isIntegrator: profile['is_integrator'],
      isTopOperator: profile['is_top_operator'],
      roles: _parseRoles(profile['roles']),
      isInActiveOrganization: profile['is_in_active_organization'],
      hasSandboxAccess:
          account['has_sandbox_access'] ?? account['hasSandboxAccess'],
      sandboxUuid: _readString(account['sandbox_uuid']),
      feVersion: _readString(account['fe_version']),
      isPasswordReset: account['is_password_reset'],
      introPending: account['intro_pending'],
      isOrgRenamed: account['is_org_renamed'],
      companyUuid: _readString(account['company_uuid']),
      hasPaymentDetailsProvided: account['has_payment_details_provided'],
      personalityType: _readPersonalityType(account),
      dateOfBirth: _readDateOfBirth(account),
      hierarchyMemberships: _parseHierarchyMemberships(
        account['hierarchy_memberships'] ?? account['hierarchyMemberships'],
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'uuid': uuid,
      'status': status,
      'drive_id': driveId,
      'onboarded': onboarded,
      'organization_uuid': organizationUuid,
      'name': name,
      'email': email,
      'image': image,
      'image_uuid': imageUuid,
      'gender': gender,
      'signature': signature?.toJson(),
      'user_uuid': userUuid,
      'image_url': imageUrl,
      'last_name': lastName,
      'first_name': firstName,
      'contact_no': contactNo,
      'date_joined': dateJoined?.toIso8601String(),
      'user_progress': userProgress,
      'profile_address': profileAddress?.toJson(),
      'is_email_verified': isEmailVerified,
      'envelope': envelope,
      'is_owner': isOwner,
      'last_login': lastLogin?.toIso8601String(),
      'is_integrator': isIntegrator,
      'is_top_operator': isTopOperator,
      'roles': roles,
      'is_in_active_organization': isInActiveOrganization,
      'has_sandbox_access': hasSandboxAccess,
      'sandbox_uuid': sandboxUuid,
      'fe_version': feVersion,
      'is_password_reset': isPasswordReset,
      'intro_pending': introPending,
      'is_org_renamed': isOrgRenamed,
      'company_uuid': companyUuid,
      'has_payment_details_provided': hasPaymentDetailsProvided,
      'personality_type': personalityType,
      'date_of_birth': dateOfBirth,
      'hierarchy_memberships': hierarchyMemberships
          ?.map((membership) => membership.toJson())
          .toList(growable: false),
    };
  }

  static String? _readString(Object? value) {
    if (value is! String && value is! num) return null;
    final text = value.toString().trim();
    return text.isEmpty || text == 'null' ? null : text;
  }

  static DateTime? _parseDate(Object? value) {
    final text = _readString(value);
    if (text == null) return null;
    final timestamp = int.tryParse(text);
    if (timestamp == null) return DateTime.tryParse(text);
    final milliseconds = text.replaceFirst('-', '').length <= 10
        ? timestamp * 1000
        : timestamp;
    try {
      return DateTime.fromMillisecondsSinceEpoch(milliseconds, isUtc: true);
    } on RangeError {
      return null;
    }
  }

  static String? _readPersonalityType(Map<String, dynamic> json) {
    final candidates = <dynamic>[
      json['personalityType'],
      json['personality_type'],
      _readMap(json['personality'])?['personalityType'],
      _readMap(json['personality'])?['personality_type'],
      _readMap(json['envelope'])?['personalityType'],
      _readMap(json['envelope'])?['personality_type'],
      _readMap(json['user_progress'])?['personalityType'],
      _readMap(json['user_progress'])?['personality_type'],
    ];

    for (final candidate in candidates) {
      final value = candidate?.toString().trim();
      if (value != null && value.isNotEmpty) {
        return value;
      }
    }

    return null;
  }

  static String? _readDateOfBirth(Map<String, dynamic> json) {
    final candidates = <dynamic>[
      json['dateOfBirth'],
      json['date_of_birth'],
      _readMap(json['envelope'])?['dateOfBirth'],
      _readMap(json['envelope'])?['date_of_birth'],
      _readMap(json['user_progress'])?['dateOfBirth'],
      _readMap(json['user_progress'])?['date_of_birth'],
    ];

    for (final candidate in candidates) {
      final value = candidate?.toString().trim();
      if (value != null && value.isNotEmpty) {
        return value;
      }
    }

    return null;
  }

  static Map<String, dynamic>? _readMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }

    return null;
  }

  static List<String>? _parseRoles(dynamic rawRoles) {
    if (rawRoles == null) {
      return null;
    }

    if (rawRoles is List) {
      final roles = rawRoles
          .map((role) => role?.toString().trim() ?? '')
          .where((role) => role.isNotEmpty)
          .toList(growable: false);
      return roles;
    }

    if (rawRoles is Map) {
      final roles = <String>[];

      rawRoles.forEach((key, value) {
        final normalizedKey = key.toString().trim();
        if (normalizedKey.isEmpty) {
          return;
        }

        if (value == null || value == false) {
          return;
        }

        roles.add(normalizedKey);
      });

      return roles;
    }

    return null;
  }

  static List<UserHierarchyMembership>? _parseHierarchyMemberships(
    dynamic rawMemberships,
  ) {
    if (rawMemberships is! List) {
      return null;
    }

    return rawMemberships
        .whereType<Map<String, dynamic>>()
        .map(UserHierarchyMembership.fromJson)
        .toList(growable: false);
  }

  static List<String> _normalizeRoles({List<String>? roles}) {
    final normalizedRoles = <String>[];
    final seenRoles = <String>{};

    void addRole(String? rawRole) {
      final normalizedRole = normalizeUserRole(rawRole);
      if (normalizedRole.isEmpty || !seenRoles.add(normalizedRole)) {
        return;
      }

      normalizedRoles.add(normalizedRole);
    }

    for (final role in roles ?? const <String>[]) {
      addRole(role);
    }

    return List<String>.unmodifiable(normalizedRoles);
  }
}

class Signature {
  final String? uuid;
  final String? image;

  Signature({this.uuid, this.image});

  factory Signature.fromJson(Map<String, dynamic> json) {
    return Signature(uuid: json['uuid'], image: json['url'] ?? json['image']);
  }

  String? get url => image;

  Map<String, dynamic> toJson() => {'uuid': uuid, 'image': image};
}

class ProfileAddress {
  final String? address;
  final String? city;
  final String? state;
  final String? country;
  final String? zipCode;

  ProfileAddress({
    this.address,
    this.city,
    this.state,
    this.country,
    this.zipCode,
  });

  factory ProfileAddress.fromJson(Map<String, dynamic> json) {
    return ProfileAddress(
      address: json['address'],
      city: json['city'],
      state: json['state'],
      country: json['country'],
      zipCode: json['zip_code'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'address': address,
      'city': city,
      'state': state,
      'country': country,
      'zip_code': zipCode,
    };
  }
}
