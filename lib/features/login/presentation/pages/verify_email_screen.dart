import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/managers/app_manager.dart';
import '../../../../core/services/deep_link_service.dart';
import '../../../../core/utils/auth_controller.dart';
import '../../../../core/widgets/app_text_view.dart';
import '../../../../core/widgets/fast_circular_progress.dart';
import '../../../../routes/app_router.dart';
import '../../../auth/presentation/widgets/auth_link_button.dart';
import '../../../auth/presentation/widgets/auth_page_frame.dart';
import '../../data/datasources/auth_remote_data_source.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/usecases/login_session_usecase.dart';
import '../providers/verify_email_controller.dart';

class VerifyEmailScreen extends StatelessWidget {
  const VerifyEmailScreen({super.key, this.user, this.verificationToken});

  final AppUser? user;
  final String? verificationToken;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) {
        final repository = AuthRepositoryImpl(AuthRemoteDataSource());
        return VerifyEmailController(
          repository,
          LoginSessionUseCase(repository),
          user: user,
          profile: AppManager.instance.currentUser,
          verificationToken: verificationToken,
        );
      },
      child: _VerifyEmailView(checkOnEntry: verificationToken != null),
    );
  }
}

class _VerifyEmailView extends StatefulWidget {
  const _VerifyEmailView({required this.checkOnEntry});

  final bool checkOnEntry;

  @override
  State<_VerifyEmailView> createState() => _VerifyEmailViewState();
}

class _VerifyEmailViewState extends State<_VerifyEmailView> with WidgetsBindingObserver {
  late final VerifyEmailController _controller;

  @override
  void initState() {
    super.initState();
    _controller = context.read<VerifyEmailController>();
    _controller.addListener(_handleVerificationResult);
    WidgetsBinding.instance.addObserver(this);
    if (widget.checkOnEntry) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_controller.checkStatus());
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && ModalRoute.isCurrentOf(context) != false) {
      unawaited(_controller.checkStatus(quiet: true));
    }
  }

  void _handleVerificationResult() {
    final message = _controller.takeFeedbackMessage();
    if (message != null && ModalRoute.isCurrentOf(context) == true) {
      ScaffoldMessenger.of(context)
        ..removeCurrentSnackBar()
        ..showSnackBar(SnackBar(content: AppTextView.body2(message)));
    }
    final step = _controller.takeNextStep();
    if (step == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      if (step == LoginSetupStep.workspaceImport) {
        AppRouter.pushReplacementNamed<void, void>(context, AppRouter.login, arguments: step);
        return;
      }
      if (DeepLinkService.instance.hasPendingAuthenticatedTarget) {
        await DeepLinkService.instance.openPendingAuthenticatedTargetAfterLogin();
        return;
      }
      AppRouter.pushReplacementNamed<void, void>(context, AppRouter.defaultAuthenticatedRouteName);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.removeListener(_handleVerificationResult);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<VerifyEmailController>();
    return PopScope(
      canPop: false,
      child: AuthPageFrame(
        title: '',
        subtitle: AppStrings.loginVerifyEmailDescription,
        contentTopSpacing: 45,
        body: _VerifyEmailActions(controller: controller),
      ),
    );
  }
}

class _VerifyEmailActions extends StatelessWidget {
  const _VerifyEmailActions({required this.controller});

  final VerifyEmailController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Image.asset('${AppStrings.imagePath}email.png', width: 130, height: 130),
        const SizedBox(height: 18),
        Align(
          child: _VerifyEmailButton(
            text: AppStrings.loginSendVerificationEmail,
            isLoading: controller.isSending,
            onPressed: controller.isBusy ? null : controller.sendVerificationEmail,
          ),
        ),
        const SizedBox(height: 10),
        Align(
          child: Stack(
            alignment: Alignment.center,
            children: [
              Opacity(
                opacity: controller.isChecking ? 0 : 1,
                alwaysIncludeSemantics: true,
                child: AuthLinkButton(
                  label: AppStrings.loginConfirmEmailVerified,
                  color: Colors.white,
                  fontSize: 14,
                  onTap: controller.isBusy ? null : controller.checkStatus,
                ),
              ),
              if (controller.isChecking) const FastCircularProgressIndicator(width: 14, height: 14),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Align(
          child: AuthLinkButton(label: AppStrings.loginSetupSignOut, onTap: AuthController.logout),
        ),
      ],
    );
  }
}

class _VerifyEmailButton extends StatelessWidget {
  const _VerifyEmailButton({required this.text, required this.isLoading, required this.onPressed});

  final String text;
  final bool isLoading;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    const shape = StadiumBorder();
    final onTap = isLoading ? null : onPressed;
    return Semantics(
      button: true,
      enabled: onTap != null,
      child: Material(
        type: MaterialType.transparency,
        shape: shape,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          customBorder: shape,
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 32),
            child: Ink(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
              decoration: const ShapeDecoration(
                shape: shape,
                gradient: LinearGradient(colors: [AppColors.secondaryColor, AppColors.hex5f3cb8]),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Opacity(
                    opacity: isLoading ? 0 : 1,
                    alwaysIncludeSemantics: true,
                    child: AppTextView.body(
                      text,
                      color: AppColors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      textAlign: TextAlign.center,
                    ),
                  ),
                  if (isLoading)
                    const Positioned.fill(
                      child: Center(child: FastCircularProgressIndicator(width: 16, height: 16)),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
