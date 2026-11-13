import 'package:flutter/material.dart';
import 'package:sparrowkaizen/core/managers/app_manager.dart';
import 'package:sparrowkaizen/core/managers/app_manager_remote_data_source.dart';
import 'package:sparrowkaizen/core/network/api_error.dart';
import 'package:sparrowkaizen/core/constants/app_strings.dart';
import 'package:sparrowkaizen/core/preference/app_preference.dart';

import '../../../../routes/app_router.dart';
import '../../../../core/services/deep_link_service.dart';
import '../../../login/data/datasources/auth_remote_data_source.dart';

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
      try {
        await _runAuthenticatedStartup(authToken);
      } catch (error) {
        if (!context.mounted) {
          return;
        }

        _isLoading = false;
        _errorMessage = _resolveStartupErrorMessage(error);
        notifyListeners();
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

  Future<void> _runAuthenticatedStartup(String authToken) async {
    final user = await _authRemoteDataSource.fetchUserDetail(
      accessToken: authToken,
    );
    await AppPreference.saveUser(user);
    AppManager.instance.updateCurrentUser(user);
    await _loadCompanyDetails(authToken, requireSuccess: true);
    await AppManager.instance.initialize(
      forceRefresh: true,
      requireSuccess: true,
    );
  }

  Future<void> _loadCompanyDetails(
    String authToken, {
    bool requireSuccess = false,
  }) async {
    try {
      final companyDetails = await _appManagerRemoteDataSource
          .fetchCompanyDetails(accessToken: authToken);
      await AppPreference.saveActiveCompany(companyDetails);
      AppManager.instance.saveActiveCompany(companyDetails);
    } catch (_) {
      if (requireSuccess) {
        rethrow;
      }
      // Keep startup resilient if company details cannot be fetched.
    }
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
