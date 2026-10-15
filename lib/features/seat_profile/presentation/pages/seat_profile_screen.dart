import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/managers/app_manager.dart';
import '../../../../core/navigation/app_menu_type.dart';
import '../../../../core/widgets/app_department_filter_strip.dart';
import '../../../../core/widgets/app_department_selection_sheet.dart';
import '../../../../core/widgets/app_bar_create_action.dart';
import '../../../../core/widgets/app_text_view.dart';
import '../../../../core/widgets/drawer_main_screen.dart';
import '../../../../core/widgets/fast_circular_progress.dart';
import '../../../../routes/app_router.dart';
import '../../data/datasources/seat_profile_remote_data_source.dart';
import '../../data/repositories/seat_profile_repository_impl.dart';
import '../../domain/entities/seat_profile.dart';
import '../../domain/usecases/get_seat_profiles_usecase.dart';
import '../../widgets/seat_profile_search_bar.dart';
import '../providers/seat_profile_controller.dart';

class SeatProfileScreen extends StatelessWidget {
  const SeatProfileScreen({super.key, this.getSeatProfilesUseCase});

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
              createSeatProfileRepository(remoteDataSource),
        ),
        ProxyProvider<SeatProfileRepositoryImpl, GetSeatProfilesUseCase>(
          update: (_, repository, __) =>
              createGetSeatProfilesUseCase(repository),
        ),
        ChangeNotifierProvider<SeatProfileController>(
          create: (context) => SeatProfileController(
            getSeatProfilesUseCase ?? context.read<GetSeatProfilesUseCase>(),
          ),
        ),
      ],
      child: const _SeatProfileScreenView(),
    );
  }
}

class _SeatProfileScreenView extends StatefulWidget {
  const _SeatProfileScreenView();

  @override
  State<_SeatProfileScreenView> createState() => _SeatProfileScreenViewState();
}

class _SeatProfileScreenViewState extends State<_SeatProfileScreenView> {
  late final ScrollController _scrollController;
  late final SeatProfileController _controller;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_handleScroll);
    _controller = context.read<SeatProfileController>();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      _controller.initialize();
    });
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_handleScroll)
      ..dispose();
    super.dispose();
  }

  void _handleScroll() {
    if (!_scrollController.hasClients ||
        _scrollController.position.extentAfter > 360) {
      return;
    }

    _controller.loadNextPage();
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<SeatProfileController>();
    final shouldShowCreateAction =
        !controller.isInitialLoading && !controller.isListLoading;

    return DrawerMainScreen(
      title: AppStrings.seatProfileTitle,
      selectedMenu: AppMenuType.seatProfiles,
      centerTitle: true,
      appBarActions: [
        if (shouldShowCreateAction)
          _SeatProfileCreateAction(
            onTap: () => _openCreateSeatProfile(context),
          ),
      ],
      child: SafeArea(
        top: false,
        bottom: false,
        child: controller.isInitialLoading
            ? Center(child: FastCircularProgressIndicator())
            : _buildContent(context, controller),
      ),
    );
  }

  Widget _buildContent(BuildContext context, SeatProfileController controller) {
    final items = controller.visibleItems;

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 1),
      child: RefreshIndicator(
        color: AppColors.purple2,
        onRefresh: controller.refresh,
        child: CustomScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(
            parent: ClampingScrollPhysics(),
          ),
          slivers: [
            SliverToBoxAdapter(
              child: SeatProfileSearchBar(
                controller: controller.searchController,
                onChanged: controller.updateSearchQuery,
                onFilterTap: () => _openFilterSheet(context, controller),
                hintText: AppStrings.seatProfileSearchHint,
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
            _buildListArea(controller, items),
            if (controller.isLoadingMore)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.only(top: 18),
                  child: Center(child: FastCircularProgressIndicator()),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildListArea(
    SeatProfileController controller,
    List<SeatProfile> items,
  ) {
    if (controller.isListLoading) {
      return const SliverFillRemaining(
        hasScrollBody: false,
        child: Center(child: FastCircularProgressIndicator()),
      );
    }

    if (controller.errorMessage != null && items.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Center(child: _buildErrorState(controller)),
      );
    }

    if (items.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Center(child: _buildEmptyState()),
      );
    }

    return SliverList.builder(
      itemCount: items.length,
      itemBuilder: (context, index) {
        final profile = items[index];
        return Padding(
          key: ValueKey(profile.id),
          padding: EdgeInsets.only(bottom: index == items.length - 1 ? 0 : 16),
          child: _SeatProfileCard(profile: profile),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(14),
      ),
      child: AppTextView.body(
        AppStrings.seatProfileNoItemsFound,
        color: AppColors.textSecondary,
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildErrorState(SeatProfileController controller) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          AppTextView.body(
            controller.errorMessage ?? AppStrings.loginSomethingWentWrong,
            color: AppColors.textSecondary,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: controller.refresh,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Future<void> _openCreateSeatProfile(BuildContext context) async {
    if (!AppManager.instance.currentUserCanOpenSeatProfileCreateFlow) {
      return;
    }

    final didCreate = await AppRouter.pushNamed(
      context,
      AppRouter.seatProfileCreate,
    );
    if (didCreate != true || !mounted) {
      return;
    }

    await _controller.refresh();
  }

  Future<void> _openFilterSheet(
    BuildContext context,
    SeatProfileController controller,
  ) async {
    final departmentId = await showAppDepartmentSelectionSheet(
      context,
      items: <AppDepartmentFilterItem>[
        const AppDepartmentFilterItem(id: 'all', name: AppStrings.categoryAll),
        ...controller.departments.map(
          (department) =>
              AppDepartmentFilterItem(id: department.id, name: department.name),
        ),
      ],
      selectedDepartmentId: controller.selectedDepartmentId,
      safeAreaBottom: false,
    );

    if (departmentId == null || !mounted) {
      return;
    }

    await controller.selectDepartment(departmentId);
  }
}

class _SeatProfileCreateAction extends StatelessWidget {
  const _SeatProfileCreateAction({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppManager.instance,
      builder: (context, _) {
        if (!AppManager.instance.currentUserCanOpenSeatProfileCreateFlow) {
          return const SizedBox.shrink();
        }

        return AppBarCreateAction(
          label: AppStrings.seatProfileCreateAction,
          onTap: onTap,
        );
      },
    );
  }
}

class _SeatProfileCard extends StatefulWidget {
  const _SeatProfileCard({required this.profile});

  final SeatProfile profile;

  @override
  State<_SeatProfileCard> createState() => _SeatProfileCardState();
}

class _SeatProfileCardState extends State<_SeatProfileCard>
    with SingleTickerProviderStateMixin {
  static const _expandDuration = Duration(milliseconds: 320);
  static const _collapseDuration = Duration(milliseconds: 280);

  late final AnimationController _expansionController;
  late final CurvedAnimation _expansion;
  late final Animation<double> _chevronTurns;

  @override
  void initState() {
    super.initState();
    _expansionController = AnimationController(
      vsync: this,
      duration: _expandDuration,
      reverseDuration: _collapseDuration,
    );
    _expansion = CurvedAnimation(
      parent: _expansionController,
      curve: Curves.easeInOutCubic,
    );
    _chevronTurns = Tween<double>(begin: 0, end: 0.5).animate(_expansion);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    _expansionController
      ..duration = disableAnimations ? Duration.zero : _expandDuration
      ..reverseDuration = disableAnimations ? Duration.zero : _collapseDuration;
  }

  @override
  void dispose() {
    _expansion.dispose();
    _expansionController.dispose();
    super.dispose();
  }

  void _toggleExpansion() {
    if (_expansionController.status == AnimationStatus.forward ||
        _expansionController.isCompleted) {
      _expansionController.reverse();
    } else {
      _expansionController.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = widget.profile;

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: _toggleExpansion,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surfaceDark,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: AppTextView.body1(
                    profile.name,
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 12),
                _CardForwardArrow(turns: _chevronTurns),
              ],
            ),
            // Keep the header fixed while revealing the mounted details from the top.
            SizeTransition(
              sizeFactor: _expansion,
              axisAlignment: -1,
              child: FadeTransition(
                opacity: _expansion,
                child: AnimatedBuilder(
                  animation: _expansionController,
                  builder: (context, child) {
                    final canInteract = _expansionController.isCompleted;
                    return IgnorePointer(
                      ignoring: !canInteract,
                      child: ExcludeSemantics(
                        excluding: !canInteract,
                        child: ExcludeFocus(
                          excluding: !canInteract,
                          child: child!,
                        ),
                      ),
                    );
                  },
                  child: _SeatProfileCardDetails(
                    profile: profile,
                    onDetailsTap: () => AppRouter.pushNamed(
                      context,
                      AppRouter.seatProfileDetail,
                      arguments: SeatProfileDetailRouteArgs(
                        seatId: profile.resolvedDetailId,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SeatProfileCardDetails extends StatelessWidget {
  const _SeatProfileCardDetails({
    required this.profile,
    required this.onDetailsTap,
  });

  final SeatProfile profile;
  final VoidCallback onDetailsTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 14),
        _buildStatRow(
          AppStrings.seatProfileCategoriesCount,
          '${profile.categoriesCount}',
          isStatus: false,
        ),
        const SizedBox(height: 10),
        _buildStatRow(
          AppStrings.seatProfileDescriptionsCount,
          '${profile.descriptionsCount}',
          isStatus: false,
        ),
        const SizedBox(height: 10),
        _buildStatRow(
          AppStrings.seatProfilePrimaryPaygrade,
          profile.hasPrimaryPaygrade
              ? AppStrings.paygradesAvailableYes
              : AppStrings.paygradesAvailableNo,
          isStatus: true,
        ),
        const SizedBox(height: 10),
        _buildStatRow(
          AppStrings.seatProfileAncillaryPaygrade,
          profile.hasAncillaryPaygrade
              ? AppStrings.paygradesAvailableYes
              : AppStrings.paygradesAvailableNo,
          isStatus: true,
        ),
        const SizedBox(height: 16),
        InkWell(
          onTap: onDetailsTap,
          borderRadius: BorderRadius.circular(999),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: AppTextView.body2(
                  AppStrings.seatProfileDetailsTitle,
                  color: AppColors.secondaryColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 6),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                color: AppColors.secondaryColor,
                size: 14,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatRow(String label, String value, {required bool isStatus}) {
    final isPositive = value == AppStrings.paygradesAvailableYes;

    return Row(
      children: [
        Expanded(
          child: AppTextView.body2(label, color: AppColors.textSecondary),
        ),
        if (isStatus)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: (isPositive ? AppColors.lightGreen1 : AppColors.red1)
                  .withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: isPositive ? AppColors.lightGreen1 : AppColors.red1,
              ),
            ),
            child: AppTextView.body3(
              value,
              color: isPositive ? AppColors.lightGreen1 : AppColors.red1,
              fontWeight: FontWeight.w700,
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.only(right: 17),
            child: AppTextView.body2(
              value,
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
      ],
    );
  }
}

class _CardForwardArrow extends StatelessWidget {
  const _CardForwardArrow({required this.turns});

  final Animation<double> turns;

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: turns,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: AppColors.mainBg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: AppColors.fieldBorder.withValues(alpha: 0.28),
          ),
        ),
        child: const Icon(
          Icons.keyboard_arrow_down_rounded,
          color: AppColors.textSecondary,
          size: 20,
        ),
      ),
    );
  }
}
