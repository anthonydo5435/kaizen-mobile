import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sparrowkaizen/core/preference/app_preference.dart';
import 'package:sparrowkaizen/features/login/domain/entities/user.dart';

import '../../support/user_detail_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'new user details preserve account identity and organisation profile fields',
    () {
      final user = User.fromJson(userDetailResponse);
      final profile = userDetailResponse['profile'] as Map<String, dynamic>;
      expect(user.uuid, profile['uuid']);
      expect(user.userUuid, userDetailResponse['uuid']);
      expect(user.status, 'active');
      expect(user.onboarded, isTrue);
      expect(user.organizationUuid, profile['organization_uuid']);
      expect(user.roles, isEmpty);
      expect(user.isOwner, isTrue);
      expect(user.isIntegrator, isFalse);
      expect(user.isTopOperator, isFalse);
      expect(user.name, 'Owner .');
      expect(user.firstName, 'Owner');
      expect(user.lastName, '.');
      expect(user.email, 'owner@kaizen.com');
      expect(user.gender, 'male');
      expect(user.contactNo, '+1 (524) 507-1337');
      expect(user.companyUuid, userDetailResponse['company_uuid']);
      expect(user.dateJoined!.millisecondsSinceEpoch, 1752796800000);
      expect(user.dateOfBirth, '1123718400000');
      expect(user.personalityType, 'ENFJ_Mentor');
      expect(user.introPending, isFalse);
      expect(user.isOrgRenamed, isTrue);
      expect(user.isPasswordReset, isTrue);
      expect(user.isEmailVerified, isTrue);
    },
  );

  test(
    'image, signature, and address objects map to existing presentation fields',
    () {
      final user = User.fromJson(userDetailResponse);
      expect(user.imageUuid, userDetailResponse['image']['uuid']);
      expect(user.image, userDetailResponse['image']['url']);
      expect(user.imageUrl, userDetailResponse['image']['url']);
      expect(user.signature!.uuid, userDetailResponse['signature']['uuid']);
      expect(user.signature!.image, userDetailResponse['signature']['url']);
      expect(user.signature!.url, userDetailResponse['signature']['url']);
      expect(user.profileAddress!.toJson(), userDetailResponse['address']);
    },
  );

  test(
    'saved preferences retain all new response fields after reloading',
    () async {
      SharedPreferences.setMockInitialValues({});
      await AppPreference.init();
      final user = User.fromJson(userDetailResponse);
      await AppPreference.saveUser(user);
      await AppPreference.init();
      final saved = await AppPreference.getUser();
      expect(saved!.toJson(), user.toJson());
      expect(saved.uuid, user.uuid);
      expect(saved.userUuid, user.userUuid);
      expect(saved.imageUuid, user.imageUuid);
      expect(saved.isOwner, isTrue);
    },
  );

  test(
    'copying user details preserves image metadata and onboarding flags',
    () {
      final original = User.fromJson(userDetailResponse);
      final copied = original.copyWith(name: 'Updated');
      expect(copied.imageUuid, original.imageUuid);
      expect(copied.introPending, isFalse);
      expect(copied.isOrgRenamed, isTrue);
      expect(copied.userUuid, original.userUuid);
      final updated = original.copyWith(
        imageUuid: 'updated',
        introPending: true,
        isOrgRenamed: false,
      );
      expect(updated.imageUuid, 'updated');
      expect(updated.introPending, isTrue);
      expect(updated.isOrgRenamed, isFalse);
    },
  );

  for (final wrapped in [false, true]) {
    test(
      'legacy flat user records remain supported (profile wrapper: $wrapped)',
      () {
        final legacy = <String, dynamic>{
          'uuid': 'profile',
          'user_uuid': 'account',
          'name': 'Legacy User',
          'email': 'legacy@example.com',
          'image': '/legacy.png',
          'image_url': 'https://example.com/legacy.png',
          'signature': {
            'uuid': 'signature',
            'image': 'https://example.com/signature.png',
          },
          'profile_address': {'city': 'Legacy City'},
          'organization_uuid': 'organisation',
          'date_joined': '2026-01-02T00:00:00Z',
          'roles': {'c_suite': true},
          'is_owner': false,
          'has_sandbox_access': true,
        };
        final user = User.fromJson(wrapped ? {'profile': legacy} : legacy);
        expect(user.uuid, 'profile');
        expect(user.userUuid, 'account');
        expect(user.email, 'legacy@example.com');
        expect(user.image, '/legacy.png');
        expect(user.imageUrl, 'https://example.com/legacy.png');
        expect(user.signature!.image, 'https://example.com/signature.png');
        expect(user.profileAddress!.city, 'Legacy City');
        expect(user.dateJoined, DateTime.utc(2026, 1, 2));
        expect(user.normalizedRoles, ['csuite']);
        expect(user.hasSandboxAccess, isTrue);
        expect(user.isOwner, isFalse);
      },
    );
  }

  test(
    'top-level owner flag takes precedence and optional objects may be null',
    () {
      final user = User.fromJson({
        ...userDetailResponse,
        'is_owner': false,
        'image': null,
        'signature': null,
        'address': null,
        'profile': {
          ...userDetailResponse['profile'] as Map<String, dynamic>,
          'is_owner': true,
        },
      });
      expect(user.isOwner, isFalse);
      expect(user.image, isNull);
      expect(user.imageUrl, isNull);
      expect(user.signature, isNull);
      expect(user.profileAddress, isNull);
    },
  );

  for (final timestamp in <Object>[
    1752796800000,
    '1752796800000',
    1752796800,
  ]) {
    test(
      'dates accept milliseconds, seconds, and numeric strings (${timestamp.runtimeType}: $timestamp)',
      () {
        final user = User.fromJson({
          'date_joined': timestamp,
          'last_login': timestamp,
        });
        expect(user.dateJoined!.millisecondsSinceEpoch, 1752796800000);
        expect(user.lastLogin!.millisecondsSinceEpoch, 1752796800000);
      },
    );
  }

  test('unresolved images and invalid dates stay absent', () {
    final user = User.fromJson({
      'image': {'uuid': 'image'},
      'date_joined': 'not-a-date',
      'last_login': '999999999999999999',
    });
    expect(user.image, isNull);
    expect(user.imageUrl, isNull);
    expect(user.imageUuid, 'image');
    expect(user.dateJoined, isNull);
    expect(user.lastLogin, isNull);
  });
}
