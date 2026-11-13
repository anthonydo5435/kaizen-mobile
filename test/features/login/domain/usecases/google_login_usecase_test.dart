import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sparrowkaizen/core/constants/app_strings.dart';
import 'package:sparrowkaizen/core/managers/app_manager.dart';
import 'package:sparrowkaizen/core/network/api_error.dart';
import 'package:sparrowkaizen/core/preference/app_preference.dart';
import 'package:sparrowkaizen/features/login/domain/entities/google_authorization.dart';
import 'package:sparrowkaizen/features/login/domain/entities/login_response.dart';
import 'package:sparrowkaizen/features/login/domain/entities/user.dart';
import 'package:sparrowkaizen/features/login/domain/repositories/auth_repository.dart';
import 'package:sparrowkaizen/features/login/domain/usecases/google_login_usecase.dart';
import 'package:sparrowkaizen/features/login/domain/usecases/login_session_usecase.dart';
import 'package:sparrowkaizen/features/login/domain/usecases/login_usecase.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppPreference.init();
    AppManager.instance.resetSessionState();
  });
  tearDown(() async {
    await AppPreference.clearUserSession();
    AppManager.instance.resetSessionState();
  });

  test('Google code becomes app tokens, profile, workspace, and authenticated user', () async {
    final repository = _Repository();
    var workspaceToken = '';
    var authorizationComplete = false;
    final useCase = GoogleLoginUseCase(
      repository,
      session: LoginSessionUseCase(
        repository,
        initializeWorkspace: (token) async => workspaceToken = token,
      ),
    );
    final user = await useCase(onAuthorizationComplete: () => authorizationComplete = true);
    expect(authorizationComplete, isTrue);
    expect(repository.exchangedCode, 'google-code');
    expect(repository.exchangedRedirect, 'https://dev.kaizenteams.ai/auth/google/callback');
    expect(repository.profileToken, 'app-access');
    expect(repository.savedProfile, same(repository.profile));
    expect(AppPreference.getAuthToken(), 'app-access');
    expect(AppPreference.getRefreshToken(), 'app-refresh');
    expect(workspaceToken, 'app-access');
    expect(AppManager.instance.currentUser, same(repository.profile));
    expect(user!.email, 'member@example.com');
    expect(user.displayName, 'Member');
  });

  test('password login retains the same session initializer', () async {
    final repository = _Repository();
    var initializedWorkspace = false;
    final useCase = LoginUseCase(
      repository,
      session: LoginSessionUseCase(
        repository,
        initializeWorkspace: (_) async => initializedWorkspace = true,
      ),
    );
    final user = await useCase(email: 'member@example.com', password: 'password');
    expect(repository.exchangedCode, isNull);
    expect(user.email, 'member@example.com');
    expect(AppPreference.getAuthToken(), 'app-access');
    expect(AppPreference.getRefreshToken(), 'app-refresh');
    expect(initializedWorkspace, isTrue);
  });

  test('canceling Google never calls the backend or creates an app session', () async {
    final repository = _Repository()..authorization = null;
    expect(await GoogleLoginUseCase(repository)(), isNull);
    expect(repository.exchangedCode, isNull);
    expect(AppPreference.getAuthToken(), isEmpty);
  });

  for (final failure in {
    GoogleAuthorizationFailure.browserUnavailable: AppStrings.loginGoogleBrowserUnavailable,
    GoogleAuthorizationFailure.callbackNotVerified: AppStrings.loginGoogleAppNotVerified,
  }.entries) {
    test('${failure.key.name} shows an app error without exchanging credentials', () async {
      final repository = _Repository()
        ..authorizationError = GoogleAuthorizationException(failure.key);
      await expectLater(
        GoogleLoginUseCase(repository)(),
        throwsA(isA<LoginException>().having((error) => error.message, 'message', failure.value)),
      );
      expect(repository.exchangedCode, isNull);
      expect(AppPreference.getAuthToken(), isEmpty);
    });
  }

  test('rejected authorization code yields a readable error without saving tokens', () async {
    final repository = _Repository()
      ..exchangeError = ApiError.requestFailed(400, message: 'invalid_google_code');
    await expectLater(
      GoogleLoginUseCase(repository)(),
      throwsA(
        isA<LoginException>().having(
          (e) => e.message,
          'message',
          AppStrings.loginGoogleCodeRejected,
        ),
      ),
    );
    expect(repository.profileToken, isNull);
    expect(AppPreference.getAuthToken(), isEmpty);
  });

  test('profile loading failure clears both tokens and user state', () async {
    final repository = _Repository()..profileError = StateError('profile failed');
    await expectLater(GoogleLoginUseCase(repository)(), throwsStateError);
    expect(AppPreference.getAuthToken(), isEmpty);
    expect(AppPreference.getRefreshToken(), isEmpty);
    expect(await AppPreference.getUser(), isNull);
    expect(AppManager.instance.currentUser, isNull);
  });

  test('an incomplete token pair never reaches profile initialization', () async {
    final repository = _Repository()..response = const LoginResponse(access: 'access', refresh: '');
    await expectLater(GoogleLoginUseCase(repository)(), throwsA(isA<LoginException>()));
    expect(repository.profileToken, isNull);
    expect(AppPreference.getAuthToken(), isEmpty);
  });
}

class _Repository implements AuthRepository {
  GoogleAuthorization? authorization = const GoogleAuthorization(
    code: 'google-code',
    redirectUri: 'https://dev.kaizenteams.ai/auth/google/callback',
  );
  LoginResponse response = const LoginResponse(access: 'app-access', refresh: 'app-refresh');
  final profile = User(uuid: 'member-id', email: 'member@example.com', name: 'Member');
  Object? exchangeError;
  Object? authorizationError;
  Object? profileError;
  String? exchangedCode;
  String? exchangedRedirect;
  String? profileToken;
  User? savedProfile;

  @override
  Future<GoogleAuthorization?> authorizeGoogle() async {
    if (authorizationError != null) throw authorizationError!;
    return authorization;
  }

  @override
  void cancelGoogleAuthorization() {}
  @override
  Future<LoginResponse> loginWithGoogle({required String code, required String redirectUri}) async {
    exchangedCode = code;
    exchangedRedirect = redirectUri;
    if (exchangeError != null) throw exchangeError!;
    return response;
  }

  @override
  Future<User> fetchUserDetail({required String accessToken}) async {
    profileToken = accessToken;
    if (profileError != null) throw profileError!;
    return profile;
  }

  @override
  Future<void> saveUserProfile(User user) async {
    savedProfile = user;
    await AppPreference.saveUser(user);
  }

  @override
  Future<LoginResponse> login({required String email, required String password}) async => response;
}
