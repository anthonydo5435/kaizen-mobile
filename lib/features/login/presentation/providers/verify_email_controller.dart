import 'package:flutter/foundation.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/network/api_error.dart';
import '../../../../core/preference/app_preference.dart';
import '../../../../core/utils/auth_controller.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/entities/user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/usecases/login_session_usecase.dart';

class VerifyEmailController extends ChangeNotifier {
  VerifyEmailController(
    this._repository,
    this._session, {
    AppUser? user,
    User? profile,
    String? verificationToken,
  }) : _user = user,
       _profile = profile,
       _verificationToken = verificationToken;

  final AuthRepository _repository;
  final LoginSessionUseCase _session;
  final User? _profile;
  int _sessionVersion = AppPreference.sessionVersion;
  AppUser? _user;
  String? _verificationToken;
  bool _disposed = false;
  bool _sending = false;
  bool _checking = false;
  LoginSetupStep? _nextStep;
  bool _navigated = false;
  String? _feedbackMessage;

  String get _email => _user?.email ?? _profile?.email ?? '';
  bool get isSending => _sending;
  bool get isChecking => _checking;
  bool get isBusy => _sending || _checking || _nextStep != null;
  bool get _hasSession =>
      !_disposed && _sessionVersion == AppPreference.sessionVersion;

  String? takeFeedbackMessage() {
    final message = _feedbackMessage;
    _feedbackMessage = null;
    return message;
  }

  LoginSetupStep? takeNextStep() {
    if (_navigated || _nextStep == null) return null;
    _navigated = true;
    return _nextStep;
  }

  Future<void> sendVerificationEmail() async {
    if (!_hasSession || isBusy) return;
    final userId =
        (_user?.verificationUserId ?? _profile?.userUuid ?? _profile?.uuid)
            ?.trim();
    if (userId == null || userId.isEmpty) {
      _feedbackMessage = AppStrings.loginVerificationEmailFailed;
      notifyListeners();
      return;
    }

    _sending = true;
    notifyListeners();
    try {
      final message = await _repository.sendVerificationEmail(userId);
      if (_hasSession) {
        _feedbackMessage = message ?? AppStrings.loginVerificationEmailSent;
      }
    } on ApiError catch (error) {
      if (_hasSession) {
        _feedbackMessage = error.responseData is Map<String, dynamic>
            ? error.message
            : AppStrings.loginVerificationEmailFailed;
      }
    } catch (_) {
      if (_hasSession) {
        _feedbackMessage = AppStrings.loginVerificationEmailFailed;
      }
    } finally {
      _sending = false;
      if (_hasSession) notifyListeners();
    }
  }

  Future<void> checkStatus({bool quiet = false}) async {
    if (!_hasSession || isBusy) return;
    final verificationToken = _verificationToken;
    _verificationToken = null;
    final showFeedback = !quiet || verificationToken != null;
    _checking = true;
    notifyListeners();
    try {
      var linkFailed = false;
      if (verificationToken != null) {
        try {
          await _repository.verifyEmailLink(verificationToken);
        } catch (_) {
          linkFailed = true;
        }
      }
      if (!_hasSession) return;

      final user = await _session.continueAuthenticatedSession(
        fallbackEmail: _email,
        fallbackUserId: _user?.verificationUserId,
      );
      if (_disposed) return;
      if (user.setupStep == LoginSetupStep.workspaceImport) {
        // The session was cleared because the account cannot enter the app yet.
        _nextStep = LoginSetupStep.workspaceImport;
        return;
      }
      if (user.setupStep == LoginSetupStep.emailVerification &&
          AuthController.pendingSignIn != null) {
        _sessionVersion = AppPreference.sessionVersion;
      }
      if (!_hasSession) return;
      if (user.setupStep == LoginSetupStep.ready) {
        _nextStep = LoginSetupStep.ready;
        return;
      }
      _user = user;
      if (showFeedback) {
        _feedbackMessage = linkFailed
            ? AppStrings.loginVerificationLinkFailed
            : AppStrings.loginEmailNotVerifiedYet;
      }
    } catch (_) {
      if (_hasSession && showFeedback) {
        _feedbackMessage = AppStrings.loginSetupStatusFailed;
      }
    } finally {
      _checking = false;
      if (!_disposed && (_hasSession || _nextStep != null)) notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
