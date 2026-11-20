import '../entities/login_response.dart';
import '../entities/google_authorization.dart';
import '../entities/user.dart';

abstract class AuthRepository {
  Future<LoginResponse> login({required String email, required String password});

  Future<GoogleAuthorization?> authorizeGoogle();

  void cancelGoogleAuthorization();

  Future<LoginResponse> loginWithGoogle({required String code, required String redirectUri});

  Future<User> fetchUserDetail({
    required String accessToken,
    bool includeHierarchy = true,
  });

  Future<User> enrichUserWithHierarchy({
    required String accessToken,
    required User user,
  });

  Future<bool> isCompanyImportReady(String accessToken);

  Future<String?> sendVerificationEmail(String userId);

  Future<void> verifyEmailLink(String token);

  Future<void> saveUserProfile(User user);
}
