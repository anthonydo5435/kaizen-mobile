import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sparrowkaizen/core/widgets/fast_circular_progress.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/navigation/app_menu_type.dart';
import '../../../../core/widgets/app_text_view.dart';
import '../../../../core/widgets/drawer_main_screen.dart';
import '../../../../routes/app_router.dart';
import '../../data/datasources/audit_remote_data_source.dart';
import '../../data/repositories/audit_repository_impl.dart';
import '../../domain/entities/audit_member_status.dart';
import '../../domain/entities/audit_profile.dart';
import '../../domain/usecases/get_audit_overview_usecase.dart';
import '../providers/check_in_controller.dart';
import '../providers/performance_snapshot_controller.dart';
import '../widgets/check_in_search_bar.dart';
import '../widgets/performance_card.dart';
import 'check_in_seat_profile_filter_sheet.dart';

class PerformanceSnapshotScreen extends StatelessWidget {
  const PerformanceSnapshotScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<AuditRemoteDataSource>(
          create: (_) => createAuditRemoteDataSource(),
        ),
        ProxyProvider<AuditRemoteDataSource, AuditRepositoryImpl>(
          update: (_, remoteDataSource, __) =>
              createAuditRepository(remoteDataSource),
        ),
        ProxyProvider<AuditRepositoryImpl, GetAuditOverviewUseCase>(
          update: (_, repository, __) =>
              createGetAuditOverviewUseCase(repository),
        ),
        ChangeNotifierProvider<PerformanceSnapshotController>(
          create: (context) =>
              PerformanceSnapshotController(context.read<AuditRepositoryImpl>())
                ..initialize(),
        ),
      ],
      child: const _PerformanceSnapshotView(),
    );
  }
}

class _PerformanceSnapshotView extends StatelessWidget {
  const _PerformanceSnapshotView();

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<PerformanceSnapshotController>();
    return DrawerMainScreen(
      title: AppStrings.performanceSnapshot,
      selectedMenu: AppMenuType.performanceSnapshot,
      centerTitle: true,
      child: SafeArea(
        top: false,
        bottom: false,
        child: Builder(
          builder: (context) => _buildContent(context, controller),
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    PerformanceSnapshotController controller,
  ) {
    final data = controller.currentData;
    final visibleReports = controller.visibleReports;
    final showTeamReportsControls = controller.canAccessTeamReports;
    final showSelectionTabs =
        showTeamReportsControls && !controller.isActualOwner;

    return Column(
      children: [
        if (showSelectionTabs)
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 22),
            child: _PerformanceSnapshotTabs(
              selectedTab: controller.selectedTab,
              onTabSelected: (tab) => controller.selectTab(
                tab == PerformanceSnapshotTab.reports
                    ? AuditMemberStatus.active
                    : AuditMemberStatus.deactivated,
              ),
            ),
          ),
        Expanded(
          child: RefreshIndicator(
            color: AppColors.purple2,
            onRefresh: controller.refresh,
            child: ListView(
              controller: controller.scrollController,
              physics: const AlwaysScrollableScrollPhysics(
                parent: ClampingScrollPhysics(),
              ),
              padding: EdgeInsets.fromLTRB(
                8,
                showSelectionTabs ? 0 : 8,
                8,
                MediaQuery.paddingOf(context).bottom + 24,
              ),
              children: [
                if (showTeamReportsControls) ...[
                  CheckInSearchBar(
                    controller: controller.searchController,
                    onChanged: controller.updateSearchQuery,
                    onClearTap: () {
                      controller.resetSearch();
                    },
                    isSearchLoading: controller.isSearchLoading,
                    onFilterTap: () =>
                        _openSeatProfileFilter(context, controller),
                  ),
                  if (controller.selectedJobTitle != null) ...[
                    const SizedBox(height: 14),
                    _FilterTag(
                      label: controller.selectedJobTitle!,
                      onClear: controller.clearSelectedJobTitle,
                    ),
                  ],
                  const SizedBox(height: 18),
                  if (controller.isFilterLoading)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 18),
                      child: Center(
                        child: AppTextView.body2(
                          AppStrings.performanceSnapshotFilterLoading,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                ],
                if (data.isLoading && data.items.isEmpty)
                  Center(child: FastCircularProgressIndicator())
                else if (visibleReports.isEmpty)
                  _EmptyState(message: controller.emptyStateMessage)
                else ...[
                  for (
                    var index = 0;
                    index < visibleReports.length;
                    index++
                  ) ...[
                    PerformanceSnapshotCard(
                      member: visibleReports[index],
                      actionLabel: 'View',
                      onCheckInTap: () => _openReport(
                        context,
                        visibleReports[index],
                        controller.selectedTab ==
                            PerformanceSnapshotTab.myReports,
                      ),
                    ),
                    if (index != visibleReports.length - 1)
                      const SizedBox(height: 18),
                  ],
                  if (data.isLoadingMore) ...[
                    const SizedBox(height: 18),
                    Center(child: FastCircularProgressIndicator()),
                  ],
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _openSeatProfileFilter(
    BuildContext context,
    PerformanceSnapshotController controller,
  ) async {
    await controller.ensureJobOptionsLoaded();
    if (!context.mounted) {
      return;
    }

    final result = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: CheckInSeatProfileFilterSheet(
          options: controller.jobOptions,
          initialValue: controller.selectedJobTitle,
          showAllOption: true,
          compactSpacing: true,
          rowSpacing: 0,
          showCloseHeader: true,
          centerTitle: true,
          title: AppStrings.performanceSnapshotJob,
          allOptionLabel: AppStrings.performanceSnapshotAllJobs,
          searchHint: AppStrings.performanceSnapshotSearchJob,
        ),
      ),
    );

    if (result == null) {
      return;
    }

    controller.setSelectedJobTitle(result);
  }

  Future<void> _openReport(
    BuildContext context,
    AuditProfile profile,
    bool isMyReport,
  ) {
    return AppRouter.pushNamed(
      context,
      AppRouter.reports,
      arguments: PerformanceReportRouteArgs(
        profile: profile,
        isMyReport: isMyReport,
      ),
    );
  }
}

class _FilterTag extends StatelessWidget {
  const _FilterTag({required this.label, required this.onClear});

  final String label;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.lightPurple2,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              InkWell(
                onTap: onClear,
                borderRadius: BorderRadius.circular(999),
                child: const Icon(
                  Icons.close_outlined,
                  size: 14,
                  color: AppColors.purple2,
                ),
              ),
              const SizedBox(width: 8),
              AppTextView.body3(
                label,
                color: AppColors.purple2,
                fontWeight: FontWeight.w600,
                fontSize: 11,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PerformanceSnapshotTabs extends StatelessWidget {
  const _PerformanceSnapshotTabs({
    required this.selectedTab,
    required this.onTabSelected,
  });

  final PerformanceSnapshotTab selectedTab;
  final ValueChanged<PerformanceSnapshotTab> onTabSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: _PerformanceSnapshotTabButton(
              label: AppStrings.reportsTitle,
              isSelected: selectedTab == PerformanceSnapshotTab.reports,
              onTap: () => onTabSelected(PerformanceSnapshotTab.reports),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _PerformanceSnapshotTabButton(
              label: AppStrings.myReportsTitle,
              isSelected: selectedTab == PerformanceSnapshotTab.myReports,
              onTap: () => onTabSelected(PerformanceSnapshotTab.myReports),
            ),
          ),
        ],
      ),
    );
  }
}

class _PerformanceSnapshotTabButton extends StatelessWidget {
  const _PerformanceSnapshotTabButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.secondaryColor : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: AppTextView.body3(
          label,
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w700,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 48),
      child: Center(
        child: AppTextView.body(
          message,
          color: AppColors.textSecondary,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
