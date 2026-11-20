import 'package:sparrowkaizen/core/preference/app_preference.dart';

import '../../domain/entities/login_response.dart';
import '../../domain/entities/google_authorization.dart';
import '../../domain/entities/user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_data_source.dart';
import '../datasources/google_authorization_data_source.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl(this._remoteDataSource, {GoogleAuthorizationDataSource? googleAuthorization})
    : _googleAuthorization = googleAuthorization ?? GoogleAuthorizationDataSource();

  final AuthRemoteDataSource _remoteDataSource;
  final GoogleAuthorizationDataSource _googleAuthorization;

  @override
  Future<GoogleAuthorization?> authorizeGoogle() => _googleAuthorization.authorize();

  @override
  void cancelGoogleAuthorization() => _googleAuthorization.cancel();

  @override
  Future<LoginResponse> loginWithGoogle({required String code, required String redirectUri}) =>
      _remoteDataSource.loginWithGoogle(code: code, redirectUri: redirectUri);

  @override
  Future<LoginResponse> login({required String email, required String password}) {
    return _remoteDataSource.login(email: email, password: password);
  }

  @override
  Future<User> fetchUserDetail({
    required String accessToken,
    bool includeHierarchy = true,
  }) {
    return _remoteDataSource.fetchUserDetail(
      accessToken: accessToken,
      includeHierarchy: includeHierarchy,
    );
  }

  @override
  Future<User> enrichUserWithHierarchy({
    required String accessToken,
    required User user,
  }) => _remoteDataSource.enrichUserWithHierarchy(
    accessToken: accessToken,
    user: user,
  );

  @override
  Future<bool> isCompanyImportReady(String accessToken) =>
      _remoteDataSource.isCompanyImportReady(accessToken);

  @override
  Future<String?> sendVerificationEmail(String userId) =>
      _remoteDataSource.sendVerificationEmail(userId);

  @override
  Future<void> verifyEmailLink(String token) =>
      _remoteDataSource.verifyEmailLink(token);

  @override
  Future<void> saveUserProfile(User user) {
    return AppPreference.saveUser(user);
  }
}
