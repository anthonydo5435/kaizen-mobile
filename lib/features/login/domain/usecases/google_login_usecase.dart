import '../../../../core/constants/app_strings.dart';
import '../../../../core/network/api_error.dart';
import '../../google_sign_in_diagnostics.dart';
import '../entities/app_user.dart';
import '../entities/google_authorization.dart';
import '../entities/login_exception.dart';
import '../repositories/auth_repository.dart';
import 'login_session_usecase.dart';

class GoogleLoginUseCase {
  GoogleLoginUseCase(this._repository, {LoginSessionUseCase? session})
    : _session = session ?? LoginSessionUseCase(_repository);

  final AuthRepository _repository;
  final LoginSessionUseCase _session;

  Future<AppUser?> call({void Function()? onAuthorizationComplete}) async {
    try {
      final authorization = await GoogleSignInDiagnostics.trace(
        'authorization',
        _repository.authorizeGoogle,
      );
      onAuthorizationComplete?.call();
      if (authorization == null) {
        GoogleSignInDiagnostics.log('login.cancelled');
        return null;
      }
      final response = await GoogleSignInDiagnostics.trace(
        'backend_exchange',
        () => _repository.loginWithGoogle(
          code: authorization.code,
          redirectUri: authorization.redirectUri,
        ),
      );
      return await GoogleSignInDiagnostics.trace(
        'session_initialization',
        () => _session(response),
      );
    } on GoogleAuthorizationException catch (error) {
      throw LoginException(switch (error.reason) {
        GoogleAuthorizationFailure.timedOut => AppStrings.loginGoogleTimedOut,
        GoogleAuthorizationFailure.unavailable => AppStrings.loginGoogleUnavailable,
        GoogleAuthorizationFailure.invalidResponse => AppStrings.loginGoogleFailed,
        GoogleAuthorizationFailure.browserUnavailable => AppStrings.loginGoogleBrowserUnavailable,
        GoogleAuthorizationFailure.callbackNotVerified => AppStrings.loginGoogleAppNotVerified,
      });
    } on ApiError catch (error) {
      if (error.message == AppStrings.apiInvalidResponse) {
        throw const LoginException(AppStrings.loginInvalidUserData);
      }
      if (error.message == 'invalid_google_code') {
        throw const LoginException(AppStrings.loginGoogleCodeRejected);
      }
      if (error.statusCode == 0) throw LoginException(error.message);
      if (error.statusCode == 404) {
        throw const LoginException(AppStrings.loginNoAccount);
      }
      if (!error.message.startsWith(AppStrings.apiRequestFailedPrefix)) {
        throw LoginException(error.message);
      }
      throw const LoginException(AppStrings.loginGoogleFailed);
    }
  }

  void cancelAuthorization() => _repository.cancelGoogleAuthorization();
}
