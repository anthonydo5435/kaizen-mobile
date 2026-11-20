import 'package:flutter/material.dart';
import 'package:sparrowkaizen/core/managers/app_manager.dart';
import 'package:sparrowkaizen/core/managers/app_manager_remote_data_source.dart';
import 'package:sparrowkaizen/core/network/api_error.dart';
import 'package:sparrowkaizen/core/constants/app_strings.dart';
import 'package:sparrowkaizen/core/preference/app_preference.dart';

import '../../../../routes/app_router.dart';
import '../../../../core/services/deep_link_service.dart';
import '../../../login/data/datasources/auth_remote_data_source.dart';
import '../../../login/data/repositories/auth_repository_impl.dart';
import '../../../login/domain/entities/app_user.dart';
import '../../../login/domain/usecases/login_session_usecase.dart';

class SplashController extends ChangeNotifier {
  SplashController({
    AuthRemoteDataSource? authRemoteDataSource,
    AppManagerRemoteDataSource? appManagerRemoteDataSource,
  }) : _authRemoteDataSource = authRemoteDataSource ?? AuthRemoteDataSource(),
       _appManagerRemoteDataSource =
           appManagerRemoteDataSource ?? AppManagerRemoteDataSource();

  final AuthRemoteDataSource _authRemoteDataSource;
  final AppManagerRemoteDataSource _appManagerRemoteDataSource;
  bool _isLoading = true;
  String? _errorMessage;
  DeepLinkTarget? _pendingStartupTarget;
  bool _didResolveStartupTarget = false;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> initialize(BuildContext context) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    if (!context.mounted) {
      return;
    }

    final authToken = AppPreference.getAuthToken().trim();

    if (!_didResolveStartupTarget) {
      _pendingStartupTarget = await DeepLinkService.instance
          .consumeStartupTarget();
      _didResolveStartupTarget = true;
    }

    final pendingDeepLinkTarget = _pendingStartupTarget;
    if (!context.mounted) {
      return;
    }

    if (authToken.isNotEmpty) {
      late final AppUser user;
      try {
        user = await _runAuthenticatedStartup();
      } catch (error) {
        if (!context.mounted) {
          return;
        }

        _isLoading = false;
        _errorMessage = _resolveStartupErrorMessage(error);
        notifyListeners();
        return;
      }

      if (!context.mounted) return;
      final workspacePending = user.setupStep == LoginSetupStep.workspaceImport;
      if (workspacePending ||
          (user.setupStep == LoginSetupStep.emailVerification &&
              (pendingDeepLinkTarget?.requiresAuthentication ?? true))) {
        if (pendingDeepLinkTarget != null &&
            pendingDeepLinkTarget.requiresAuthentication) {
          DeepLinkService.instance.deferAuthenticatedTarget(
            pendingDeepLinkTarget,
          );
        }
        _pendingStartupTarget = null;
        _isLoading = false;
        notifyListeners();
        AppRouter.pushReplacementNamed<void, void>(
          context,
          workspacePending ? AppRouter.login : AppRouter.verifyEmail,
          arguments: workspacePending
              ? user.setupStep
              : VerifyEmailRouteArgs(user: user),
        );
        return;
      }

      if (pendingDeepLinkTarget != null) {
        if (!context.mounted) {
          return;
        }

        _pendingStartupTarget = null;
        _isLoading = false;
        notifyListeners();

        AppRouter.pushReplacementNamed<void, void>(
          context,
          pendingDeepLinkTarget.routeName,
          arguments: pendingDeepLinkTarget.arguments,
        );
        return;
      }

      if (!context.mounted) {
        return;
      }

      _isLoading = false;
      notifyListeners();

      if (!context.mounted) {
        return;
      }
      if (DeepLinkService.instance.hasPendingAuthenticatedTarget) {
        await DeepLinkService.instance
            .openPendingAuthenticatedTargetAfterLogin();
        return;
      }

      AppRouter.pushReplacementNamed<void, void>(
        context,
        AppRouter.defaultAuthenticatedRouteName,
      );
    } else {
      if (pendingDeepLinkTarget != null) {
        _pendingStartupTarget = null;
        _isLoading = false;
        notifyListeners();

        AppRouter.pushReplacementNamed<void, void>(
          context,
          pendingDeepLinkTarget.routeName,
          arguments: pendingDeepLinkTarget.arguments,
        );
        return;
      }

      _isLoading = false;
      notifyListeners();

      AppRouter.pushReplacementNamed<void, void>(context, AppRouter.login);
    }
  }

  Future<void> retry(BuildContext context) {
    return initialize(context);
  }

  Future<AppUser> _runAuthenticatedStartup() async {
    final sessionVersion = AppPreference.sessionVersion;
    await AppManager.instance.initialize(
      forceRefresh: true,
      requireSuccess: true,
      remoteDataSource: _appManagerRemoteDataSource,
    );
    if (sessionVersion != AppPreference.sessionVersion) {
      throw ApiError.requestFailed(401);
    }

    return LoginSessionUseCase(
      AuthRepositoryImpl(_authRemoteDataSource),
      initializeWorkspace: (token) async {
        final company = await _appManagerRemoteDataSource.fetchCompanyDetails(
          accessToken: token,
        );
        if (sessionVersion != AppPreference.sessionVersion) return;
        await AppPreference.saveActiveCompany(company);
        if (sessionVersion != AppPreference.sessionVersion) return;
        AppManager.instance.saveActiveCompany(company);
      },
    ).continueAuthenticatedSession();
  }

  String _resolveStartupErrorMessage(Object error) {
    if (error is ApiError) {
      final message = error.message.trim();
      if (message == AppStrings.apiUnableToConnectServer ||
          message == AppStrings.apiRequestTimedOut) {
        return message;
      }
    }

    // Server bodies and exception details can contain HTML or long diagnostics.
    return AppStrings.splashStartupFailed;
  }
}
