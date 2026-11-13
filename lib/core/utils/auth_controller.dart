import '../network/api_endpoints.dart';
import '../network/api_error.dart';
import '../network/api_processor.dart';
import '../managers/app_manager.dart';
import '../preference/app_preference.dart';
import '../../routes/app_router.dart';

class AuthController {
  AuthController._();

  static final ApiCallExecutor _apiCallExecutor = const ApiCallExecutor();
  static Future<String>? _refreshOperation;
  static int? _refreshSessionVersion;
  static Future<void>? _logoutOperation;

  static Future<void> logout() async {
    final pending = _logoutOperation;
    if (pending != null) return pending;
    if (AppPreference.getAuthToken().isEmpty &&
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
    final currentAccessToken = AppPreference.getAuthToken().trim();
    if (failedAccessToken != null &&
        currentAccessToken.isNotEmpty &&
        failedAccessToken != currentAccessToken) {
      return currentAccessToken;
    }

    final operation = _refreshToken(version);
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

  static Future<String> _refreshToken(int sessionVersion) async {
    final refreshToken = AppPreference.getRefreshToken().trim();
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

      if (sessionVersion != AppPreference.sessionVersion) {
        throw ApiError.requestFailed(401);
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
          (error.statusCode == 400 || error.statusCode == 401)) {
        await logout();
      }

      rethrow;
    }
  }
}
