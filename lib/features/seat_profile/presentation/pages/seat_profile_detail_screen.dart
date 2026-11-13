import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/managers/app_manager.dart';
import '../../../../core/preference/app_preference.dart';
import '../../../../core/widgets/app_ai_generate_button.dart';
import '../../../../core/widgets/app_share_button.dart';
import '../../../../core/widgets/app_text_view.dart';
import '../../../../core/widgets/fast_circular_progress.dart';
import '../../../../routes/app_router.dart';
import '../../data/datasources/seat_profile_remote_data_source.dart';
import '../../data/repositories/seat_profile_repository_impl.dart';
import '../../domain/entities/seat_profile_detail.dart';
import '../../domain/usecases/get_seat_profiles_usecase.dart';
import '../../widgets/seat_profile_dotted_action_button.dart';
import '../providers/seat_profile_detail_controller.dart';
import 'seat_profile_generate_content_sheet.dart';
import 'seat_profile_manage_categories_sheet.dart';
import 'seat_profile_share_dialogue.dart';

class SeatProfileDetailScreen extends StatelessWidget {
  const SeatProfileDetailScreen({
    super.key,
    required this.seatId,
    this.getSeatProfilesUseCase,
  });

  final String seatId;
  final GetSeatProfilesUseCase? getSeatProfilesUseCase;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<SeatProfileRemoteDataSource>(
          create: (_) => createSeatProfileRemoteDataSource(),
        ),
        ProxyProvider<SeatProfileRemoteDataSource, SeatProfileRepositoryImpl>(
          update: (_, remoteDataSource, __) =>
              createSeatProfileDetailRepository(remoteDataSource),
        ),
        ProxyProvider<SeatProfileRepositoryImpl, GetSeatProfilesUseCase>(
          update: (_, repository, __) =>
              createGetSeatProfileDetailUseCase(repository),
        ),
        ChangeNotifierProvider<SeatProfileDetailController>(
          create: (context) => SeatProfileDetailController(
            getSeatProfilesUseCase ?? context.read<GetSeatProfilesUseCase>(),
          )..initialize(seatId),
        ),
      ],
      child: const SeatProfileDetailView(),
    );
  }
}

class SeatProfileDetailView extends StatelessWidget {
  const SeatProfileDetailView({super.key, this.isShared = false});

  final bool isShared;

  void _goBack(BuildContext context) {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
      return;
    }
    final destination = AppPreference.getAuthToken().trim().isEmpty
        ? AppRouter.login
        : AppRouter.defaultAuthenticatedRouteName;
    navigator.pushReplacementNamed(destination);
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<SeatProfileDetailController>();
    final detail = controller.detail;

    return Scaffold(
      backgroundColor: AppColors.mainBg,
      appBar: AppBar(
        backgroundColor: AppColors.mainBg,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        leadingWidth: 40,
        leading: IconButton(
          onPressed: () =>
              isShared ? _goBack(context) : Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
        ),
        title: const AppTextView.title1(
          AppStrings.seatProfileDetailsTitle,
          color: AppColors.secondaryColor,
          fontSize: 24,
          fontWeight: FontWeight.w500,
        ),
      ),
      body: SafeArea(
        top: false,
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 24),
          child: ListenableBuilder(
            listenable: AppManager.instance,
            builder: (context, _) {
              final canManageContent =
                  !isShared && _canManageSeatProfile(detail);

              return Column(
                children: [
                  if (controller.isLoading)
                    Expanded(
                      child: Center(child: FastCircularProgressIndicator()),
                    )
                  else if (controller.errorMessage != null)
                    Expanded(child: _buildMessage(controller.errorMessage!))
                  else if (detail == null)
                    Expanded(
                      child: _buildMessage(AppStrings.loginSomethingWentWrong),
                    )
                  else
                    Expanded(
                      child: ListView(
                        children: [
                          _buildSeatSummary(
                            detail,
                            onShare:
                                !isShared &&
                                    (controller.shareController?.canManage ??
                                        false)
                                ? () => showSeatProfileShareDialogue(
                                    context,
                                    controller.shareController!,
                                  )
                                : null,
                          ),
                          const SizedBox(height: 18),
                          if (!isShared) ...[
                            _DetailActionRow(
                              controller: controller,
                              canManageContent: canManageContent,
                              onUpdateCategory: () =>
                                  _showManageSeatCategoriesDialog(
                                    context,
                                    controller,
                                  ),
                              onGenerate: () => _showGenerateSeatContentSheet(
                                context,
                                controller,
                              ),
                            ),
                            const SizedBox(height: 18),
                          ],
                          if (detail.categories.isEmpty)
                            _buildMessage(
                              AppStrings.seatProfileNoCategoriesFound,
                            )
                          else
                            ...detail.categories.map(
                              (category) => Padding(
                                key: ValueKey(category.id),
                                padding: const EdgeInsets.only(bottom: 16),
                                child: _CategoryCard(
                                  category: category,
                                  onTap: () => _openDescriptions(
                                    context,
                                    controller,
                                    category,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _showManageSeatCategoriesDialog(
    BuildContext context,
    SeatProfileDetailController controller,
  ) async {
    if (!_canManageSeatProfile(controller.detail)) {
      return;
    }

    final didUpdate = await showSeatProfileManageCategoriesSheet(
      context,
      initialCategories: controller.categoryDrafts,
      onSaveCategories: controller.saveSeatCategoryDrafts,
    );
    if (didUpdate != true || !context.mounted) {
      return;
    }

    await controller.refresh();
  }

  Future<void> _showGenerateSeatContentSheet(
    BuildContext context,
    SeatProfileDetailController controller,
  ) async {
    if (!_canManageSeatProfile(controller.detail)) {
      return;
    }

    controller.clearSeatContentGenerationError();

    final hasExistingCategories =
        controller.detail?.categories.isNotEmpty == true ||
        controller.categoryDrafts.isNotEmpty;

    await showSeatProfileGenerateContentSheet(
      context,
      controller: controller,
      hasExistingCategories: hasExistingCategories,
    );
  }

  Future<void> _openDescriptions(
    BuildContext context,
    SeatProfileDetailController controller,
    SeatProfileCategory category,
  ) async {
    await AppRouter.pushNamed<void>(
      context,
      AppRouter.seatProfileDescriptions,
      arguments: SeatProfileDescriptionsRouteArgs(
        category: category,
        controller: controller,
        isShared: isShared,
      ),
    );
  }

  Widget _buildSeatSummary(SeatProfileDetail detail, {VoidCallback? onShare}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppTextView.body1(
                  detail.title,
                  color: AppColors.secondaryColor,
                  fontWeight: FontWeight.w700,
                ),
                if ((detail.department?.name ?? '').isNotEmpty) ...[
                  const SizedBox(height: 4),
                  AppTextView.body2(
                    detail.department!.name,
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ],
              ],
            ),
          ),
          if (onShare != null) ...[
            const SizedBox(width: 12),
            AppShareButton(onTap: onShare),
          ],
        ],
      ),
    );
  }

  Widget _buildMessage(String message) {
    return Center(
      child: AppTextView.body(
        message,
        color: AppColors.textSecondary,
        textAlign: TextAlign.center,
      ),
    );
  }

  bool _canManageSeatProfile(SeatProfileDetail? detail) {
    final departmentId = detail?.department?.id.trim() ?? '';
    return AppManager.instance.canCurrentUserManageSeatProfileDepartment(
      departmentId: departmentId,
    );
  }
}

class _DetailActionRow extends StatelessWidget {
  const _DetailActionRow({
    required this.controller,
    required this.canManageContent,
    required this.onUpdateCategory,
    required this.onGenerate,
  });

  final SeatProfileDetailController controller;
  final bool canManageContent;
  final VoidCallback onUpdateCategory;
  final VoidCallback onGenerate;

  @override
  Widget build(BuildContext context) {
    if (!canManageContent) {
      return const SizedBox.shrink();
    }

    final isBusy = controller.isGeneratingSeatContent;
    final isEnabled = controller.detail != null && !controller.isLoading;

    return Row(
      children: [
        Expanded(
          child: SeatProfileDottedActionButton(
            label: AppStrings.seatProfileUpdateCategoryAction,
            onTap: isEnabled && !isBusy ? onUpdateCategory : null,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: AppAiGenerateButton(
            label: AppStrings.seatProfileGenerateAction,
            expand: true,
            minHeight: 40,
            showOutline: true,
            isLoading: controller.isGeneratingSeatContent,
            onTap: isEnabled && controller.canGenerateSeatContent
                ? onGenerate
                : null,
          ),
        ),
      ],
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({required this.category, required this.onTap});

  final SeatProfileCategory category;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final weight = category.weightPercent;
    final weightLabel = weight == weight.roundToDouble()
        ? '${weight.toInt()}%'
        : '${weight.toStringAsFixed(1)}%';

    return Material(
      color: AppColors.surfaceDark,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        splashFactory: NoSplash.splashFactory,
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppTextView.body1(
                      category.title,
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                    const SizedBox(height: 10),
                    const AppTextView.body2(
                      AppStrings.seatProfilePercentageHold,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(height: 4),
                    AppTextView.body2(
                      weightLabel,
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: AppColors.mainBg,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textSecondary,
                  size: 20,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
