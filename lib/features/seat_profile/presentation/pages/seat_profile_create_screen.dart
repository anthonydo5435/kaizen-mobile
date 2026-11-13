import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/widgets/app_ai_generate_button.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_confirmation_dialog.dart';
import '../../../../core/widgets/app_dialog_style.dart';
import '../../../../core/widgets/app_overlay_close_button.dart';
import '../../../../core/widgets/app_text_view.dart';
import '../../../../core/widgets/fast_circular_progress.dart';
import '../../../../routes/app_router.dart';
import '../../data/datasources/seat_profile_remote_data_source.dart';
import '../../data/repositories/seat_profile_repository_impl.dart';
import '../../domain/usecases/get_seat_profiles_usecase.dart';
import '../models/seat_profile_form_initial_data.dart';
import '../providers/seat_profile_create_controller.dart';
import '../providers/seat_profile_category_form_controller.dart';

part '../widgets/seat_profile_create_form.dart';
part '../widgets/seat_profile_create_categories_dialog.dart';
part '../widgets/seat_profile_create_category_widgets.dart';
part '../widgets/seat_profile_create_generation_dialog.dart';

class SeatProfileCreateScreen extends StatelessWidget {
  const SeatProfileCreateScreen({
    super.key,
    this.initialData,
    this.getSeatProfilesUseCase,
  });

  final SeatProfileFormInitialData? initialData;
  final GetSeatProfilesUseCase? getSeatProfilesUseCase;

  @override
  Widget build(BuildContext context) {
    if (!SeatProfileCreateController.canAccessForm(initialData: initialData)) {
      return const _SeatProfileCreateAccessDeniedView();
    }

    return MultiProvider(
      providers: [
        Provider<SeatProfileRemoteDataSource>(
          create: (_) => createSeatProfileRemoteDataSource(),
        ),
        ProxyProvider<SeatProfileRemoteDataSource, SeatProfileRepositoryImpl>(
          update: (_, remoteDataSource, __) =>
              SeatProfileRepositoryImpl(remoteDataSource),
        ),
        ProxyProvider<SeatProfileRepositoryImpl, GetSeatProfilesUseCase>(
          update: (_, repository, __) => GetSeatProfilesUseCase(repository),
        ),
        ChangeNotifierProvider<SeatProfileCreateController>(
          create: (context) => SeatProfileCreateController.forCurrentUser(
            getSeatProfilesUseCase ?? context.read<GetSeatProfilesUseCase>(),
            initialData: initialData,
          )..initialize(),
        ),
      ],
      child: const _SeatProfileCreateScreenView(),
    );
  }
}

class _SeatProfileCreateAccessDeniedView extends StatelessWidget {
  const _SeatProfileCreateAccessDeniedView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.mainBg,
      appBar: AppBar(
        backgroundColor: AppColors.mainBg,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        leadingWidth: 40,
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(false),
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: AppTextView.body(
              AppStrings.seatProfileCreateAccessDenied,
              color: AppColors.textSecondary,
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}

class _SeatProfileCreateScreenView extends StatelessWidget {
  const _SeatProfileCreateScreenView();

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<SeatProfileCreateController>();

    return PopScope<Object?>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) {
          return;
        }

        _handleBackTap(context, controller);
      },
      child: Scaffold(
        backgroundColor: AppColors.mainBg,
        appBar: AppBar(
          backgroundColor: AppColors.mainBg,
          foregroundColor: AppColors.textPrimary,
          elevation: 0,
          leadingWidth: 40,
          leading: IconButton(
            onPressed: () => _handleBackTap(context, controller),
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
          ),
          title: AppTextView.title1(
            controller.title,
            color: AppColors.secondaryColor,
            fontSize: 24,
            fontWeight: FontWeight.w500,
          ),
        ),
        body: SafeArea(
          top: false,
          bottom: false,
          child: controller.showInitialLoading
              ? Center(child: FastCircularProgressIndicator())
              : _SeatProfileCreateContent(
                  controller: controller,
                  onCompleteFlowToDetails: () =>
                      _openSeatProfileDetails(context, controller),
                ),
        ),
      ),
    );
  }

  void _handleBackTap(
    BuildContext context,
    SeatProfileCreateController controller,
  ) {
    Navigator.of(context).pop(controller.didCompleteFlow);
  }

  void _openSeatProfileDetails(
    BuildContext context,
    SeatProfileCreateController controller,
  ) {
    final seatId = controller.detailTargetSeatId;
    if (seatId.isEmpty) {
      Navigator.of(context).pop(true);
      return;
    }

    AppRouter.pushReplacementNamed<void, bool>(
      context,
      AppRouter.seatProfileDetail,
      arguments: SeatProfileDetailRouteArgs(seatId: seatId),
      result: true,
    );
  }
}
