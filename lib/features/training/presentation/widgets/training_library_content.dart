import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/navigation/app_menu_type.dart';
import '../../../../core/widgets/drawer_main_screen.dart';
import '../../../../core/widgets/fast_circular_progress.dart';
import '../../domain/entities/seat_description_training_route.dart';
import '../../domain/entities/training_library_module.dart';
import '../controllers/training_library_controller.dart';
import 'training_library_create_action.dart';
import 'training_library_filter_tags.dart';
import 'training_library_result_area.dart';
import 'training_library_search_bar.dart';

class TrainingLibraryContent extends StatelessWidget {
  const TrainingLibraryContent({
    super.key,
    required this.controller,
    required this.onOpenLesson,
    required this.onSelectSeat,
    required this.onCreate,
    this.onModuleActions,
  });

  final TrainingLibraryController controller;
  final Future<void> Function(SeatDescriptionTrainingRoute route) onOpenLesson;
  final VoidCallback onSelectSeat;
  final VoidCallback onCreate;
  final ValueChanged<TrainingLibraryModule>? onModuleActions;

  @override
  Widget build(BuildContext context) {
    return DrawerMainScreen(
      title: AppStrings.trainingLibraryTitle,
      selectedMenu: AppMenuType.library,
      centerTitle: true,
      navigationBarsVisible: controller.navigationBarsVisible,
      appBarActions: [
        if (!controller.isShowingFullscreenLoading &&
            controller.canCreateTraining)
          TrainingLibraryCreateAction(
            onTap: () => controller.openCreateFlow(onOpen: onCreate),
          ),
      ],
      child: SafeArea(
        top: false,
        bottom: false,
        child: controller.isShowingFullscreenLoading
            ? Center(
                child: FastCircularProgressIndicator(width: 24, height: 24),
              )
            : _TrainingLibraryFiltersAndResults(
                controller: controller,
                onModuleTap: (module) =>
                    controller.openLesson(module, openDetails: onOpenLesson),
                onSelectSeat: onSelectSeat,
                onModuleActions: onModuleActions,
              ),
      ),
    );
  }
}

class _TrainingLibraryFiltersAndResults extends StatelessWidget {
  const _TrainingLibraryFiltersAndResults({
    required this.controller,
    required this.onModuleTap,
    required this.onSelectSeat,
    required this.onModuleActions,
  });

  final TrainingLibraryController controller;
  final ValueChanged<TrainingLibraryModule> onModuleTap;
  final VoidCallback onSelectSeat;
  final ValueChanged<TrainingLibraryModule>? onModuleActions;

  @override
  Widget build(BuildContext context) {
    final items = controller.visibleItems;

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TrainingLibrarySearchBar(
            controller: controller,
            onSelectSeat: onSelectSeat,
          ),
          if (controller.appliedFilterTags.isNotEmpty) ...[
            const SizedBox(height: 12),
            TrainingLibraryFilterTags(controller: controller),
          ],
          const SizedBox(height: 24),
          Expanded(
            child: RefreshIndicator(
              color: AppColors.purple2,
              onRefresh: () => controller.refresh(preservePosition: true),
              child: TrainingLibraryResultArea(
                controller: controller,
                items: items,
                scrollController: controller.scrollController,
                onModuleTap: onModuleTap,
                onModuleActions: onModuleActions,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
