import '../network/api_endpoints.dart';
import '../network/api_error.dart';
import '../network/api_processor.dart';
import '../managers/app_manager.dart';
import '../preference/app_preference.dart';
import '../../features/login/domain/entities/login_response.dart';
import '../../routes/app_router.dart';

class AuthController {
  AuthController._();

  static final ApiCallExecutor _apiCallExecutor = const ApiCallExecutor();
  static Future<String>? _refreshOperation;
  static int? _refreshSessionVersion;
  static Future<void>? _logoutOperation;
  static LoginResponse? _pendingSignIn;
  static int? _pendingSignInVersion;

  /// Credentials used before verification and workspace checks finish.
  static LoginResponse? get pendingSignIn =>
      _pendingSignInVersion == AppPreference.sessionVersion
      ? _pendingSignIn
      : null;

  static void holdPendingSignIn(LoginResponse credentials) {
    _pendingSignIn = credentials;
    _pendingSignInVersion = AppPreference.sessionVersion;
  }

  static void discardPendingSignIn() {
    _pendingSignIn = null;
    _pendingSignInVersion = null;
  }

  static Future<void> logout() async {
    final pending = _logoutOperation;
    if (pending != null) return pending;
    if (pendingSignIn == null &&
        AppPreference.getAuthToken().isEmpty &&
        AppPreference.getRefreshToken().isEmpty &&
        AppManager.instance.currentUser == null) {
      return;
    }

    final operation = _logout();
    _logoutOperation = operation;
    try {
      await operation;
    } finally {
      if (identical(_logoutOperation, operation)) _logoutOperation = null;
    }
  }

  static Future<void> _logout() async {
    discardPendingSignIn();
    final clearing = AppPreference.clearUserSession();
    final version = AppPreference.sessionVersion;
    ApiCallExecutor.clearGetCache();
    await clearing;
    if (version != AppPreference.sessionVersion) return;
    AppManager.instance.resetSessionState();
    await AppRouter.resetToLogin();
  }

  static Future<String> requestRefreshToken({
    String? failedAccessToken,
    int? sessionVersion,
  }) async {
    final version = sessionVersion ?? AppPreference.sessionVersion;
    if (version != AppPreference.sessionVersion) {
      throw ApiError.requestFailed(401);
    }
    final pending = _refreshOperation;
    if (pending != null && _refreshSessionVersion == version) return pending;

    // A late 401 can belong to a token that another request already refreshed.
    final savedToken = AppPreference.getAuthToken().trim();
    final pendingCredentials = failedAccessToken != null && savedToken.isEmpty
        ? pendingSignIn
        : null;
    final currentAccessToken = pendingCredentials?.access ?? savedToken;
    if (failedAccessToken != null &&
        currentAccessToken.isNotEmpty &&
        failedAccessToken != currentAccessToken) {
      return currentAccessToken;
    }

    final operation = _refreshToken(version, pendingCredentials);
    _refreshOperation = operation;
    _refreshSessionVersion = version;
    try {
      return await operation;
    } finally {
      if (identical(_refreshOperation, operation)) {
        _refreshOperation = null;
        _refreshSessionVersion = null;
      }
    }
  }

  static Future<String> _refreshToken(
    int sessionVersion,
    LoginResponse? pendingCredentials,
  ) async {
    final refreshToken =
        (pendingCredentials?.refresh ?? AppPreference.getRefreshToken()).trim();
    if (refreshToken.isEmpty) {
      await logout();
      throw ApiError.requestFailed(401);
    }

    try {
      final response = await _apiCallExecutor.processApi<Map<String, String>>(
        apiCallType: ApiCallType.post,
        endpoint: ApiEndPoints.refreshToken,
        parameters: {'refresh': refreshToken},
        allowAutoRefresh: false,
        decoder: (json) {
          if (json is! Map<String, dynamic>) {
            throw const ApiError.invalidResponse();
          }

          final access = json['access']?.toString().trim();
          final refresh = json['refresh']?.toString().trim();

          if (access == null ||
              access.isEmpty ||
              refresh == null ||
              refresh.isEmpty) {
            throw const ApiError.invalidResponse();
          }

          return <String, String>{'access': access, 'refresh': refresh};
        },
      );

      if (sessionVersion != AppPreference.sessionVersion ||
          (pendingCredentials != null &&
              !identical(pendingCredentials, pendingSignIn))) {
        throw ApiError.requestFailed(401);
      }
      if (pendingCredentials != null) {
        holdPendingSignIn(
          LoginResponse(
            access: response['access']!,
            refresh: response['refresh']!,
          ),
        );
        return response['access']!;
      }
      // Update both cached preferences before yielding, keeping this session's
      // version stable so other requests can reuse the rotated credentials.
      await Future.wait<void>([
        AppPreference.setAuthToken(response['access']!),
        AppPreference.setRefreshToken(response['refresh']!),
      ]);
      if (sessionVersion != AppPreference.sessionVersion) {
        throw ApiError.requestFailed(401);
      }

      return response['access']!;
    } on ApiError catch (error) {
      if (sessionVersion == AppPreference.sessionVersion &&
          (pendingCredentials == null ||
              identical(pendingCredentials, pendingSignIn)) &&
          (error.statusCode == 400 || error.statusCode == 401)) {
        await logout();
      }

      rethrow;
    }
  }
}
