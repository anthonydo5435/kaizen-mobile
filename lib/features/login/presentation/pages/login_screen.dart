import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sparrowkaizen/core/utils/custom_functions.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/services/deep_link_service.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_view.dart';
import '../../../../routes/app_router.dart';
import '../../../auth/presentation/widgets/auth_link_button.dart';
import '../../../auth/presentation/widgets/auth_outlined_text_field.dart';
import '../../../auth/presentation/widgets/auth_page_frame.dart';
import '../../data/datasources/auth_remote_data_source.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../domain/usecases/google_login_usecase.dart';
import '../../domain/usecases/login_usecase.dart';
import '../providers/login_controller.dart';
import '../widgets/google_login_button.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<AuthRemoteDataSource>(create: (_) => createAuthRemoteDataSource()),
        ProxyProvider<AuthRemoteDataSource, AuthRepositoryImpl>(
          update: (_, remoteDataSource, __) => createAuthRepository(remoteDataSource),
        ),
        ProxyProvider<AuthRepositoryImpl, LoginUseCase>(
          update: (_, repository, __) => createLoginUseCase(repository),
        ),
        ProxyProvider<AuthRepositoryImpl, GoogleLoginUseCase>(
          update: (_, repository, __) => GoogleLoginUseCase(repository),
        ),
        ChangeNotifierProvider<LoginController>(
          create: (context) => LoginController(
            context.read<LoginUseCase>(),
            googleLogin: context.read<GoogleLoginUseCase>().call,
            cancelGoogleLogin: context.read<GoogleLoginUseCase>().cancelAuthorization,
          ),
        ),
      ],
      child: const _LoginScreenView(),
    );
  }
}

class _LoginScreenView extends StatefulWidget {
  const _LoginScreenView();

  @override
  State<_LoginScreenView> createState() => _LoginScreenViewState();
}

class _LoginScreenViewState extends State<_LoginScreenView> {
  late final LoginController _controller;
  bool _isErrorDialogVisible = false;

  @override
  void initState() {
    super.initState();
    _controller = context.read<LoginController>();
    _controller.addListener(_handleControllerStateChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_handleControllerStateChanged);
    super.dispose();
  }

  void _handleControllerStateChanged() {
    final errorMessage = _controller.errorMessage;
    final user = _controller.user;

    if (_controller.shouldShowErrorMessage() && errorMessage != null) {
      _showLoginErrorDialog(errorMessage);
    }

    if (_controller.shouldHandleUserNavigation() && user != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) {
          return;
        }

        if (DeepLinkService.instance.hasPendingAuthenticatedTarget) {
          await DeepLinkService.instance.openPendingAuthenticatedTargetAfterLogin();
          return;
        }

        AppRouter.pushReplacementNamed<void, void>(
          context,
          AppRouter.defaultAuthenticatedRouteName,
        );
      });
    }
  }

  Future<void> _showLoginErrorDialog(String message) async {
    if (!mounted || _isErrorDialogVisible) {
      return;
    }
    _isErrorDialogVisible = true;
    CustomFunctions.showCustomAlert(context, AppStrings.loginFailedTitle, message);
    _isErrorDialogVisible = false;
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<LoginController>();
    return AuthPageFrame(
      title: AppStrings.loginToYourAccount,
      subtitle: AppStrings.enterProvidedCredentialsToContinue,
      body: Form(
        key: controller.formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildEmailField(),
            const SizedBox(height: 4),
            _buildPasswordField(),
            Align(
              alignment: Alignment.centerRight,
              child: AuthLinkButton(
                label: AppStrings.loginForgotPassword,
                color: AppColors.textSecondary,
                icon: Icons.lock_outline_rounded,
                fontWeight: FontWeight.w500,
                onTap: () {
                  AppRouter.pushNamed<void>(context, AppRouter.forgotPassword);
                },
              ),
            ),
            const SizedBox(height: 16),
            _buildLoginButton(context, controller),
            const _LoginMethodSeparator(),
            GoogleLoginButton(
              isLoading: controller.isGoogleLoading,
              onPressed: controller.isLoading
                  ? null
                  : () {
                      FocusScope.of(context).unfocus();
                      controller.loginWithGoogle();
                    },
            ),
            if (controller.canCancelGoogleLogin)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: AuthLinkButton(
                  label: AppStrings.loginCancelGoogle,
                  onTap: controller.cancelGoogleLogin,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmailField() {
    return AuthOutlinedTextField(
      controller: _controller.emailController,
      labelText: AppStrings.loginEmailLabel,
      errorText: _controller.emailError,
      keyboardType: TextInputType.emailAddress,
      textInputAction: TextInputAction.next,
      autofillHints: const <String>[AutofillHints.email],
      onChanged: _controller.updateEmail,
    );
  }

  Widget _buildPasswordField() {
    return AuthOutlinedTextField(
      controller: _controller.passwordController,
      labelText: AppStrings.loginPasswordLabel,
      errorText: _controller.passwordError,
      obscureText: _controller.isPasswordHidden,
      textInputAction: TextInputAction.done,
      autofillHints: const <String>[AutofillHints.password],
      onChanged: _controller.updatePassword,
      suffixIcon: IconButton(
        onPressed: _controller.togglePasswordVisibility,
        icon: Icon(
          _controller.isPasswordHidden ? Icons.visibility_off_outlined : Icons.visibility_outlined,
          color: AppColors.secondaryColor,
          size: 20,
        ),
      ),
    );
  }

  Widget _buildLoginButton(BuildContext context, LoginController controller) {
    return AppButton(
      text: AppStrings.loginButton,
      isLoading: controller.isPasswordLoading,
      onPressed: controller.isLoading
          ? null
          : () async {
              if (!controller.validateLoginFields()) {
                return;
              }

              await context.read<LoginController>().login(
                email: controller.emailController.text,
                password: controller.passwordController.text,
              );
            },
    );
  }
}

class _LoginMethodSeparator extends StatelessWidget {
  const _LoginMethodSeparator();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 18),
      child: Row(
        children: [
          Expanded(child: Divider(color: AppColors.fieldBorder.withValues(alpha: 0.5), height: 1)),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: AppTextView.body2(
              AppStrings.loginAlternativeSeparator,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          Expanded(child: Divider(color: AppColors.fieldBorder, height: 1)),
        ],
      ),
    );
  }
}
