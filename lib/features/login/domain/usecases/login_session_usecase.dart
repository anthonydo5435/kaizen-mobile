import 'package:sparrowkaizen/core/managers/app_manager.dart';
import 'package:sparrowkaizen/core/managers/app_manager_remote_data_source.dart';
import 'package:sparrowkaizen/core/preference/app_preference.dart';
import 'package:sparrowkaizen/core/utils/auth_controller.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/network/api_error.dart';
import '../../../../core/network/api_processor.dart';
import '../entities/app_user.dart';
import '../entities/login_exception.dart';
import '../entities/login_response.dart';
import '../entities/user.dart';
import '../repositories/auth_repository.dart';

/// Initializes the same app session for password and Google authentication.
class LoginSessionUseCase {
  const LoginSessionUseCase(
    this._authRepository, {
    Future<void> Function(String)? initializeWorkspace,
    Future<void> Function()? initializeOrganizations,
  }) : _initializeWorkspace = initializeWorkspace,
       _initializeOrganizations = initializeOrganizations;

  final AuthRepository _authRepository;
  final Future<void> Function(String)? _initializeWorkspace;
  final Future<void> Function()? _initializeOrganizations;

  Future<AppUser> call(
    LoginResponse response, {
    String fallbackEmail = '',
  }) async {
    if (response.access.trim().isEmpty || response.refresh.trim().isEmpty) {
      throw const LoginException(AppStrings.loginInvalidUserData);
    }
    int? sessionVersion;
    try {
      AuthController.discardPendingSignIn();
      final clearing = AppPreference.clearUserSession();
      sessionVersion = AppPreference.sessionVersion;
      await clearing;
      _ensureCurrentSession(sessionVersion);
      AppManager.instance.resetSessionState();
      AuthController.holdPendingSignIn(response);
      await (_initializeOrganizations ?? _fetchOrganizationsAfterLogin)();
      _ensureCurrentSession(sessionVersion);
      return await continueAuthenticatedSession(
        fallbackEmail: response.email ?? fallbackEmail,
        fallbackUserId: response.userId,
      );
    } catch (_) {
      // Never leave a partial session behind if loading or persisting the profile fails.
      if (sessionVersion == AppPreference.sessionVersion) {
        AuthController.discardPendingSignIn();
        await AppPreference.clearUserSession();
        AppManager.instance.resetSessionState();
      }
      rethrow;
    }
  }

  Future<AppUser> continueAuthenticatedSession({
    String fallbackEmail = '',
    String? fallbackUserId,
  }) async {
    final sessionVersion = AppPreference.sessionVersion;
    final accessToken = _accessToken;
    if (accessToken.trim().isEmpty) throw ApiError.requestFailed(401);

    var profile = await _authRepository.fetchUserDetail(
      accessToken: accessToken,
      includeHierarchy: false,
    );
    _ensureCurrentSession(sessionVersion);
    final email = (profile.email ?? fallbackEmail).trim();
    final id = (profile.uuid ?? profile.userUuid ?? fallbackUserId ?? email)
        .trim();
    if (email.isEmpty || id.isEmpty) {
      throw const LoginException(AppStrings.loginInvalidUserData);
    }

    var step = LoginSetupStep.ready;
    if (profile.isEmailVerified == false) {
      step = LoginSetupStep.emailVerification;
    } else if (profile.isEmailVerified == true &&
        !await _authRepository.isCompanyImportReady(_accessToken)) {
      step = LoginSetupStep.workspaceImport;
    }
    _ensureCurrentSession(sessionVersion);

    if (step == LoginSetupStep.workspaceImport) {
      AuthController.discardPendingSignIn();
      final clearing = AppPreference.clearUserSession();
      final clearedVersion = AppPreference.sessionVersion;
      ApiCallExecutor.clearGetCache();
      await clearing;
      _ensureCurrentSession(clearedVersion);
      AppManager.instance.resetSessionState();
    } else if (step == LoginSetupStep.emailVerification) {
      await _moveSavedUnverifiedSignInToMemory();
      AppManager.instance.updateCurrentUser(profile);
    } else {
      final pendingSignIn = AuthController.pendingSignIn;
      if (pendingSignIn != null) {
        await Future.wait<void>([
          AppPreference.setAuthToken(pendingSignIn.access),
          AppPreference.setRefreshToken(pendingSignIn.refresh),
        ]);
        _ensureCurrentSession(sessionVersion);
        AuthController.discardPendingSignIn();
      }
      profile = await _authRepository.enrichUserWithHierarchy(
        accessToken: AppPreference.getAuthToken(),
        user: profile,
      );
      _ensureCurrentSession(sessionVersion);
      await _authRepository.saveUserProfile(profile);
      _ensureCurrentSession(sessionVersion);
      AppManager.instance.updateCurrentUser(profile);

      final token = AppPreference.getAuthToken();
      if (_initializeWorkspace != null) {
        await _initializeWorkspace(token);
      } else {
        await _fetchCompanyDetailsAfterUserDetails(token, sessionVersion);
      }
      _ensureCurrentSession(sessionVersion);
    }

    return AppUser(
      id: id,
      email: email,
      displayName: _resolveDisplayName(email: email, profile: profile),
      verificationUserId: profile.userUuid ?? profile.uuid ?? fallbackUserId,
      setupStep: step,
    );
  }

  String get _accessToken =>
      AuthController.pendingSignIn?.access ?? AppPreference.getAuthToken();

  Future<void> _moveSavedUnverifiedSignInToMemory() async {
    if (AuthController.pendingSignIn != null) return;

    // Older app versions stored tokens before checking verification.
    final credentials = LoginResponse(
      access: AppPreference.getAuthToken(),
      refresh: AppPreference.getRefreshToken(),
    );
    final clearing = Future.wait<void>([
      AppPreference.clearTokens(),
      AppPreference.clearUser(),
    ]);
    final version = AppPreference.sessionVersion;
    await clearing;
    _ensureCurrentSession(version);
    AuthController.holdPendingSignIn(credentials);
  }

  void _ensureCurrentSession(int sessionVersion) {
    if (sessionVersion != AppPreference.sessionVersion) {
      throw ApiError.requestFailed(401);
    }
  }

  String _resolveDisplayName({required String email, required User profile}) {
    final candidates = [
      profile.name,
      [
        profile.firstName?.trim(),
        profile.lastName?.trim(),
      ].whereType<String>().where((value) => value.isNotEmpty).join(' '),
    ];

    for (final candidate in candidates) {
      final value = candidate?.trim();
      if (value != null && value.isNotEmpty) {
        return value;
      }
    }

    final localPart = email.split('@').first.trim();
    if (localPart.isEmpty) {
      return 'User';
    }

    return localPart
        .split(RegExp(r'[._-]+'))
        .where((part) => part.isNotEmpty)
        .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
        .join(' ');
  }

  Future<void> _fetchOrganizationsAfterLogin() async {
    await AppManager.instance.initialize(
      forceRefresh: true,
      requireSuccess: true,
      accessToken: _accessToken,
    );
  }

  Future<void> _fetchCompanyDetailsAfterUserDetails(
    String accessToken,
    int sessionVersion,
  ) async {
    try {
      final companyDetails = await AppManagerRemoteDataSource()
          .fetchCompanyDetails(accessToken: accessToken);
      _ensureCurrentSession(sessionVersion);
      await AppPreference.saveActiveCompany(companyDetails);
      AppManager.instance.saveActiveCompany(companyDetails);
    } catch (_) {
      // Keep login resilient if company details cannot be fetched right now.
    }
  }
}
