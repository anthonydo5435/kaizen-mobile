import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/managers/app_manager.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/network/api_error.dart';
import '../../../../core/network/api_processor.dart';
import '../../../../core/preference/app_preference.dart';
import '../../../../core/services/file_uploader.dart';
import '../../../../core/utils/custom_functions.dart';
import '../../../../routes/app_router.dart';
import '../../../login/domain/entities/login_response.dart';
import '../../../login/domain/entities/user.dart';

class OnboardingController extends ChangeNotifier {
  static const String expiredLinkMessage = 'The Link is Expired, Try Again';

  OnboardingController({
    String? initialProfileImagePath,
    String? initialEmail,
    FileUploader? fileUploader,
    ApiCallExecutor? apiCallExecutor,
  }) : _profileImagePath = initialProfileImagePath,
       _email = initialEmail?.trim() ?? '',
       _fileUploader = fileUploader ?? const FileUploader(),
       _apiCallExecutor = apiCallExecutor ?? const ApiCallExecutor() {
    _userInitialization = _initializeUserFromOnboardingToken();
  }

  final ImagePicker _imagePicker = ImagePicker();
  final FileUploader _fileUploader;
  final ApiCallExecutor _apiCallExecutor;
  late final Future<void> _userInitialization;
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController =
      TextEditingController();
  final GlobalKey<FormState> passwordFormKey = GlobalKey<FormState>();

  String? _profileImagePath;
  bool _hasSelectedNewProfileImage = false;
  bool _isPickingImage = false;
  bool _isSubmitting = false;
  bool _isInitializingUser = false;
  bool _isPasswordHidden = true;
  bool _isConfirmPasswordHidden = true;
  bool _isCompleted = false;
  bool _isDeepLinkExpired = false;
  bool _hasHandledCompletionNavigation = false;
  String _email = '';
  String? _errorMessage;
  User? _resolvedUser;

  String? get profileImagePath => _profileImagePath;
  bool get isPickingImage => _isPickingImage;
  bool get isSubmitting => _isSubmitting;
  bool get isInitializingUser => _isInitializingUser;
  bool get isPasswordHidden => _isPasswordHidden;
  bool get isConfirmPasswordHidden => _isConfirmPasswordHidden;
  bool get isCompleted => _isCompleted;
  bool get isDeepLinkExpired => _isDeepLinkExpired;
  String get email => _email;
  String? get errorMessage => _errorMessage;
  String get setPasswordDisplayEmail =>
      _email.isEmpty ? AppStrings.profileValueUnavailable : _email;
  bool get shouldNavigateToLogin =>
      _isCompleted && !_hasHandledCompletionNavigation;

  bool get hasLocalProfileImageToUpload {
    final path = _profileImagePath?.trim();
    return _hasSelectedNewProfileImage && path != null && path.isNotEmpty;
  }

  bool isSetPasswordKeyboardOpen(double bottomInset) {
    return bottomInset > 0;
  }

  EdgeInsets resolveSetPasswordContentPadding(double bottomInset) {
    return EdgeInsets.fromLTRB(
      32,
      isSetPasswordKeyboardOpen(bottomInset) ? 24 : 32,
      32,
      bottomInset + 32,
    );
  }

  double resolveSetPasswordHeaderSpacing(double bottomInset) {
    return isSetPasswordKeyboardOpen(bottomInset) ? 12 : 28;
  }

  double resolveSetPasswordFormSpacing(double bottomInset) {
    return isSetPasswordKeyboardOpen(bottomInset) ? 48 : 120;
  }

  double resolveSetPasswordActionSpacing(double bottomInset) {
    return isSetPasswordKeyboardOpen(bottomInset) ? 32 : 60;
  }

  double resolveSetPasswordMinHeight({
    required double maxHeight,
    required EdgeInsets contentPadding,
  }) {
    return (maxHeight - contentPadding.vertical)
        .clamp(0.0, double.infinity)
        .toDouble();
  }

  void navigateToLoginAfterCompletion(BuildContext context) {
    if (!shouldNavigateToLogin || !context.mounted) {
      return;
    }

    _hasHandledCompletionNavigation = true;
    AppRouter.pushReplacementNamed<void, void>(context, AppRouter.login);
  }

  String _resolveStoredAccessToken() {
    return AppPreference.getAuthToken().trim();
  }

  String _resolveDeepLinkToken() {
    return AppPreference.getOnboardingToken().trim();
  }

  String _resolveUserId(User? user) {
    return user?.userUuid?.trim() ?? user?.uuid?.trim() ?? '';
  }

  String? _resolveEmail(User? user) {
    final value = user?.email?.trim();
    if (value == null || value.isEmpty) {
      return null;
    }
    return value;
  }

  Future<void> _initializeUserFromOnboardingToken() async {
    _isInitializingUser = true;
    notifyListeners();

    try {
      final user = await _resolveCurrentUserFromOnboardingToken();
      _isDeepLinkExpired = false;
      _resolvedUser = user;
      _email = _resolveEmail(user) ?? _email;
      _profileImagePath = user?.imageUrl?.trim().isNotEmpty == true
          ? user!.imageUrl!.trim()
          : user?.image?.trim().isNotEmpty == true
          ? user!.image!.trim()
          : _profileImagePath;
      _hasSelectedNewProfileImage = false;
      _errorMessage = null;
    } catch (error) {
      final user = await AppPreference.getUser();
      _resolvedUser = user;
      _email = _resolveEmail(user) ?? _email;
      if (error is ApiError && _isExpiredLinkVerifyError(error)) {
        _isDeepLinkExpired = true;
        _errorMessage = expiredLinkMessage;
      }
    } finally {
      _isInitializingUser = false;
      notifyListeners();
    }
  }

  Future<User?> _resolveCurrentUserFromOnboardingToken() async {
    final deepLinkToken = _resolveDeepLinkToken();
    if (deepLinkToken.isNotEmpty && _resolveStoredAccessToken().isEmpty) {
      debugPrint(
        '[OnboardingController] Deep link token before verifyToken API: '
        '$deepLinkToken',
      );
      late final LoginResponse session;
      try {
        session = await _verifyDeepLinkToken(deepLinkToken);
      } on ApiError catch (error) {
        debugPrint(
          '[OnboardingController] verify_token failed before userDetail call: '
          'status=${error.statusCode} message=${error.message}',
        );
        rethrow;
      }
      debugPrint(
        '[OnboardingController] Calling userDetail with verify_token access: '
        '${session.access}',
      );
      final refreshedUser = await _fetchUserDetail(session.access);
      debugPrint(
        '[OnboardingController] userDetail parsed user after verify_token: '
        '${jsonEncode(refreshedUser.toJson())}',
      );
      await AppPreference.saveUser(refreshedUser);
      AppManager.instance.updateCurrentUser(refreshedUser);
      await _logSavedUserPreference(source: 'verify_token -> userDetail');
      return refreshedUser;
    }

    final savedUser = await AppPreference.getUser();
    final savedUserId = _resolveUserId(savedUser);
    if (savedUser != null && savedUserId.isNotEmpty) {
      return savedUser;
    }

    final accessToken = _resolveStoredAccessToken();
    if (accessToken.isNotEmpty) {
      debugPrint(
        '[OnboardingController] Access token before userDetail API: '
        '$accessToken',
      );
      final refreshedUser = await _fetchUserDetail(accessToken);
      debugPrint(
        '[OnboardingController] userDetail parsed user after stored access: '
        '${jsonEncode(refreshedUser.toJson())}',
      );
      await AppPreference.saveUser(refreshedUser);
      AppManager.instance.updateCurrentUser(refreshedUser);
      await _logSavedUserPreference(
        source: 'stored_access_token -> userDetail',
      );
      return refreshedUser;
    }

    return savedUser;
  }

  Future<LoginResponse> _verifyDeepLinkToken(String token) async {
    try {
      final session = await _apiCallExecutor.processApi<LoginResponse>(
        apiCallType: ApiCallType.get,
        endpoint: ApiEndPoints.verifyToken(token),
        allowAutoRefresh: false,
        decoder: (json) {
          debugPrint(
            '[OnboardingController] verify_token response: '
            '${jsonEncode(json)}',
          );
          if (json is! Map<String, dynamic>) {
            throw const ApiError.invalidResponse();
          }

          if (json['success'] == false) {
            throw ApiError.requestFailed(0, message: expiredLinkMessage);
          }

          final payload = json['data'] is Map<String, dynamic>
              ? json['data'] as Map<String, dynamic>
              : json;
          final access = payload['access']?.toString().trim();
          final refresh = payload['refresh']?.toString().trim();
          if (access == null ||
              access.isEmpty ||
              refresh == null ||
              refresh.isEmpty) {
            throw const ApiError.invalidResponse();
          }

          return LoginResponse(access: access, refresh: refresh);
        },
      );

      _isDeepLinkExpired = false;
      debugPrint(
        '[OnboardingController] verify_token parsed session access='
        '${session.access} refresh=${session.refresh}',
      );
      await AppPreference.setAuthToken(session.access);
      await AppPreference.setRefreshToken(session.refresh);
      await AppPreference.clearOnboardingSession();

      return session;
    } on ApiError catch (error) {
      if (_isExpiredLinkVerifyError(error)) {
        _isDeepLinkExpired = true;
        _errorMessage = expiredLinkMessage;
      }
      rethrow;
    }
  }

  bool _isExpiredLinkVerifyError(ApiError error) {
    return error.message == expiredLinkMessage ||
        error.statusCode == 400 ||
        error.statusCode == 401 ||
        error.statusCode == 403;
  }

  Future<void> _logSavedUserPreference({required String source}) async {
    final savedUser = await AppPreference.getUser();
    debugPrint(
      '[OnboardingController] saved user preference after $source: '
      '${savedUser == null ? 'null' : jsonEncode(savedUser.toJson())}',
    );
  }

  Future<User> _fetchUserDetail(String authToken) {
    debugPrint(
      '[OnboardingController] Starting userDetail request with token: '
      '$authToken',
    );
    return _apiCallExecutor
        .processApi<User>(
          apiCallType: ApiCallType.get,
          endpoint: ApiEndPoints.userDetail,
          authToken: authToken,
          invalidateCacheBeforeRequest: true,
          decoder: (json) {
            debugPrint(
              '[OnboardingController] userDetail response: ${jsonEncode(json)}',
            );
            if (json is! Map<String, dynamic>) {
              throw const ApiError.invalidResponse();
            }

            final profile = json['profile'];
            if (profile is! Map<String, dynamic>) {
              throw const ApiError.invalidResponse();
            }

            return User.fromJson(json);
          },
        )
        .catchError((error) {
          if (error is ApiError) {
            debugPrint(
              '[OnboardingController] userDetail failed: '
              'status=${error.statusCode} message=${error.message}',
            );
          } else {
            debugPrint('[OnboardingController] userDetail failed: $error');
          }
          throw error;
        });
  }

  Future<User?> ensureOnboardingSessionReady() async {
    try {
      await _userInitialization;

      final user = _resolvedUser ?? await AppPreference.getUser();
      _email = _resolveEmail(user) ?? _email;
      _errorMessage = null;
      notifyListeners();
      return user;
    } catch (_) {
      _errorMessage = null;
      notifyListeners();
      return null;
    }
  }

  Future<bool> pickProfileImage() async {
    if (_isPickingImage) {
      return false;
    }

    _isPickingImage = true;
    notifyListeners();

    try {
      final pickedImage = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );

      if (pickedImage == null) {
        return false;
      }

      _profileImagePath = pickedImage.path;
      _hasSelectedNewProfileImage = true;
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    } finally {
      _isPickingImage = false;
      notifyListeners();
    }
  }

  Future<bool> submitProfileImage() async {
    if (_isSubmitting) {
      return false;
    }

    final selectedImagePath = _profileImagePath?.trim();
    if (selectedImagePath == null || selectedImagePath.isEmpty) {
      return true;
    }

    if (selectedImagePath.startsWith('http')) {
      return true;
    }

    _errorMessage = null;
    _isSubmitting = true;
    notifyListeners();

    try {
      final user = await ensureOnboardingSessionReady();
      final authToken = _resolveStoredAccessToken();
      final userId = _resolveUserId(user);
      if (user == null || authToken.isEmpty || userId.isEmpty) {
        _errorMessage = 'Unable to upload profile image right now.';
        return false;
      }

      final fileName = CustomFunctions.fileNameFromPath(selectedImagePath);
      final contentType = CustomFunctions.contentTypeFromPath(
        selectedImagePath,
      );
      final fileBytes = await XFile(selectedImagePath).readAsBytes();

      final uploadedImage = await _sendProfileImage(
        fileName: fileName,
        fileBytes: fileBytes,
        contentType: contentType,
        authToken: authToken,
      );

      await _updateProfileImage(
        userId: userId,
        imageUuid: uploadedImage.uuid,
        authToken: authToken,
      );

      final updatedUser = user.copyWith(
        image: uploadedImage.image,
        imageUuid: uploadedImage.uuid,
        imageUrl: uploadedImage.image,
      );
      _profileImagePath = uploadedImage.image;
      _hasSelectedNewProfileImage = false;
      await AppPreference.saveUser(updatedUser);
      AppManager.instance.updateCurrentUser(updatedUser);

      return true;
    } on ApiError catch (error) {
      _errorMessage = error.message;
      return false;
    } catch (_) {
      _errorMessage = 'Unable to upload profile image right now.';
      return false;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  Future<UploadedImagePayload> _sendProfileImage({
    required String fileName,
    required List<int> fileBytes,
    required String contentType,
    required String authToken,
  }) {
    return _fileUploader.uploadOnboardingImage(
      fileName: fileName,
      fileBytes: fileBytes,
      contentType: contentType,
      authToken: authToken,
    );
  }

  Future<void> _updateProfileImage({
    required String userId,
    required String imageUuid,
    required String authToken,
  }) {
    return _apiCallExecutor.processApi<void>(
      apiCallType: ApiCallType.patch,
      endpoint: ApiEndPoints.userById(userId),
      authToken: authToken,
      parameters: {'image': imageUuid},
      decoder: (_) {},
    );
  }

  void togglePasswordVisibility() {
    _isPasswordHidden = !_isPasswordHidden;
    notifyListeners();
  }

  void toggleConfirmPasswordVisibility() {
    _isConfirmPasswordHidden = !_isConfirmPasswordHidden;
    notifyListeners();
  }

  bool _hasPasswordLetter(String password) {
    return RegExp(r'[A-Za-z]').hasMatch(password);
  }

  bool _hasPasswordNumber(String password) {
    return RegExp(r'\d').hasMatch(password);
  }

  String? _validatePasswordRequirements(
    String password, {
    required bool isConfirmation,
  }) {
    if (password.isEmpty) {
      return isConfirmation
          ? AppStrings.authEnterConfirmPassword
          : AppStrings.loginEnterPassword;
    }
    if (password.length < 8) {
      return AppStrings.authPasswordMinLength;
    }
    if (!_hasPasswordLetter(password)) {
      return AppStrings.authPasswordLetterRequired;
    }
    if (!_hasPasswordNumber(password)) {
      return AppStrings.authPasswordNumberRequired;
    }
    return null;
  }

  String? validatePassword(String? value) {
    final password = value?.trim() ?? '';
    return _validatePasswordRequirements(password, isConfirmation: false);
  }

  String? validateConfirmPassword(String? value) {
    final confirmPassword = value?.trim() ?? '';
    final requirementError = _validatePasswordRequirements(
      confirmPassword,
      isConfirmation: true,
    );
    if (requirementError != null) {
      return requirementError;
    }
    if (confirmPassword != passwordController.text.trim()) {
      return AppStrings.authPasswordsDoNotMatch;
    }
    return null;
  }

  Future<void> submitSetPassword() async {
    await completeOnboarding();
  }

  Future<bool> completeOnboarding() async {
    if (_isSubmitting) {
      return false;
    }

    final isValid = passwordFormKey.currentState?.validate() ?? false;
    if (!isValid) {
      return false;
    }

    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final user = await ensureOnboardingSessionReady();
      final authToken = _resolveStoredAccessToken();
      final userId = _resolveUserId(user);
      if (user == null || authToken.isEmpty || userId.isEmpty) {
        _errorMessage = AppStrings.authSetPasswordUnableToUpdate;
        return false;
      }

      final email = _resolveEmail(user) ?? _email.trim();

      await _apiCallExecutor.processApi<void>(
        apiCallType: ApiCallType.put,
        endpoint: ApiEndPoints.changePassword(userId),
        authToken: authToken,
        parameters: {
          'email': email,
          'new_password': passwordController.text.trim(),
          'confirm_password': confirmPasswordController.text.trim(),
        },
        decoder: (_) {},
      );

      await AppPreference.clearTokens();
      _hasHandledCompletionNavigation = false;
      _isCompleted = true;
      return true;
    } on ApiError catch (error) {
      _errorMessage = error.message;
      return false;
    } catch (_) {
      _errorMessage = AppStrings.authSetPasswordUnableToUpdate;
      return false;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }
}
