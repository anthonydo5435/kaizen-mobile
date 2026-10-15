import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/utils/custom_functions.dart';
import '../../../../core/widgets/fast_circular_progress.dart';
import '../../../../routes/app_router.dart';
import '../providers/compliance_controller.dart';
import '../providers/compliance_learning_track_controller.dart';
import '../widgets/compliance_empty_state.dart';
import '../widgets/compliance_search_bar.dart';
import '../widgets/learning_track_card.dart';
import 'compliance_learning_track_filter_sheet.dart';

class ComplianceLearningTrackTabScreen extends StatelessWidget {
  const ComplianceLearningTrackTabScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ComplianceLearningTrackController>();
    final tracks = controller.filteredTracks;

    return RefreshIndicator(
      color: AppColors.purple2,
      onRefresh: () async {
        await context.read<ComplianceController>().refreshCurrentTab();
        await controller.refreshSearch(forceRefresh: true);
      },
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: ClampingScrollPhysics(),
        ),
        slivers: [
          SliverToBoxAdapter(
            child: ComplianceSearchBar(
              controller: controller.searchController,
              onChanged: controller.updateSearchQuery,
              onClearTap: controller.clearSearch,
              showClearButton: true,
              onFilterTap: () => _showFilterSheet(context, controller),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 20)),
          if (controller.isSearchLoading)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: FastCircularProgressIndicator()),
            )
          else if (controller.searchError != null)
            SliverFillRemaining(
              hasScrollBody: false,
              child: ComplianceEmptyState(message: controller.searchError!),
            )
          else if (tracks.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: ComplianceEmptyState(
                message: AppStrings.complianceNoTracksFound,
              ),
            )
          else
            SliverList.separated(
              itemCount: tracks.length,
              separatorBuilder: (_, __) => const SizedBox(height: 18),
              itemBuilder: (context, index) {
                final track = tracks[index];

                return LearningTrackCard(
                  track: track,
                  onTap: () async {
                    final isOverdue = CustomFunctions.isDeadlineOverdue(
                      track.deadline,
                    );
                    if (isOverdue) {
                      _showRestrictedSnackBar(context);
                      return;
                    }

                    final isCancelled = CustomFunctions.isCancelledStatus(
                      track.displayStatus,
                    );
                    if (isCancelled) {
                      CustomFunctions.showCustomAlert(
                        context,
                        'Restricted',
                        'You cannot access this compliance',
                      );
                      return;
                    }

                    final trackAssignmentUuid = track.uuid;
                    if (trackAssignmentUuid == null ||
                        trackAssignmentUuid.isEmpty) {
                      return;
                    }

                    await AppRouter.pushNamed<void>(
                      context,
                      AppRouter.complianceTracks,
                      arguments: ComplianceTracksRouteArgs(
                        trackAssignmentUuid: trackAssignmentUuid,
                        title: track.displayName,
                      ),
                    );

                    if (!context.mounted) {
                      return;
                    }

                    await context.read<ComplianceController>().initialize(
                      showLoading: false,
                    );
                    await controller.refreshSearch(forceRefresh: true);
                  },
                );
              },
            ),
          // The floating home bar contributes its measured height to this inset.
          SliverToBoxAdapter(
            child: SizedBox(height: MediaQuery.paddingOf(context).bottom + 24),
          ),
        ],
      ),
    );
  }

  Future<void> _showFilterSheet(
    BuildContext context,
    ComplianceLearningTrackController controller,
  ) async {
    final selectedSeatProfiles = await showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ComplianceLearningTrackFilterSheet(
        seatProfiles: controller.seatProfiles,
        selectedSeatProfiles: controller.selectedSeatProfiles,
      ),
    );
    if (selectedSeatProfiles == null) {
      return;
    }

    controller.updateSelectedSeatProfiles(selectedSeatProfiles);
  }

  void _showRestrictedSnackBar(BuildContext context) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text('You cannot access this compliance')),
      );
  }
}
