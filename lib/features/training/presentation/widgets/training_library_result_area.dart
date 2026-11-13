import 'package:flutter/material.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/widgets/fast_circular_progress.dart';
import '../../domain/entities/training_library_module.dart';
import '../controllers/training_library_controller.dart';
import 'training_library_module_card.dart';
import 'training_library_status_state.dart';
import 'training_library_visible_item.dart';

class TrainingLibraryResultArea extends StatefulWidget {
  const TrainingLibraryResultArea({
    super.key,
    required this.controller,
    required this.items,
    required this.scrollController,
    required this.onModuleTap,
    this.onModuleActions,
  });

  final TrainingLibraryController controller;
  final List<TrainingLibraryModule> items;
  final ScrollController scrollController;
  final ValueChanged<TrainingLibraryModule> onModuleTap;
  final ValueChanged<TrainingLibraryModule>? onModuleActions;

  @override
  State<TrainingLibraryResultArea> createState() =>
      _TrainingLibraryResultAreaState();
}

class _TrainingLibraryResultAreaState extends State<TrainingLibraryResultArea> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    widget.controller.preloadThumbnails(widget.items);
  }

  @override
  void didUpdateWidget(TrainingLibraryResultArea oldWidget) {
    super.didUpdateWidget(oldWidget);
    widget.controller.preloadThumbnails(widget.items);
  }

  VoidCallback? _actionsFor(TrainingLibraryModule module) =>
      widget.onModuleActions != null &&
          widget.controller.canShowModuleActions(module)
      ? () => widget.onModuleActions!(module)
      : null;

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final items = widget.items;
    final scrollController = widget.scrollController;
    if (controller.isInlineLoading) {
      return CustomScrollView(
        controller: scrollController,
        physics: const AlwaysScrollableScrollPhysics(
          parent: ClampingScrollPhysics(),
        ),
        slivers: const [
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: FastCircularProgressIndicator(width: 24, height: 24),
            ),
          ),
        ],
      );
    }

    if (controller.errorMessage != null && controller.items.isEmpty) {
      return ListView(
        controller: scrollController,
        physics: const AlwaysScrollableScrollPhysics(
          parent: ClampingScrollPhysics(),
        ),
        children: [
          TrainingLibraryStatusState(
            message: controller.errorMessage!,
            actionLabel: AppStrings.trainingLibraryRetry,
            onActionTap: controller.initialize,
          ),
        ],
      );
    }

    if (items.isEmpty) {
      return ListView(
        controller: scrollController,
        physics: const AlwaysScrollableScrollPhysics(
          parent: ClampingScrollPhysics(),
        ),
        children: const [
          TrainingLibraryStatusState(
            message: AppStrings.trainingLibraryNoModulesFound,
          ),
        ],
      );
    }

    final footer = controller.isLoadingMore
        ? const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: FastCircularProgressIndicator()),
          )
        : controller.loadMoreErrorMessage != null
        ? TrainingLibraryStatusState(
            message: controller.loadMoreErrorMessage!,
            actionLabel: AppStrings.trainingLibraryRetry,
            onActionTap: controller.loadNextPage,
          )
        : null;
    return switch (controller.viewMode) {
      TrainingLibraryViewMode.grid => _TrainingLibraryGrid(
        items: items,
        footer: footer,
        scrollController: scrollController,
        onModuleTap: widget.onModuleTap,
        onItemVisible: controller.onItemVisible,
        actionsFor: _actionsFor,
      ),
      TrainingLibraryViewMode.list => _TrainingLibraryList(
        items: items,
        footer: footer,
        scrollController: scrollController,
        onModuleTap: widget.onModuleTap,
        onItemVisible: controller.onItemVisible,
        actionsFor: _actionsFor,
      ),
    };
  }
}

class _TrainingLibraryGrid extends StatelessWidget {
  const _TrainingLibraryGrid({
    required this.items,
    required this.footer,
    required this.onItemVisible,
    required this.scrollController,
    required this.onModuleTap,
    required this.actionsFor,
  });

  final List<TrainingLibraryModule> items;
  final Widget? footer;
  final ValueChanged<String> onItemVisible;
  final ScrollController scrollController;
  final ValueChanged<TrainingLibraryModule> onModuleTap;
  final VoidCallback? Function(TrainingLibraryModule module) actionsFor;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 16.0;
        final crossAxisCount = constraints.maxWidth >= 1020
            ? 3
            : (constraints.maxWidth >= 620 ? 2 : 1);
        final cardWidth =
            (constraints.maxWidth - spacing * (crossAxisCount - 1)) /
            crossAxisCount;
        final textScaleExtra =
            (MediaQuery.textScalerOf(context).scale(16) - 16).clamp(
              0.0,
              double.infinity,
            ) *
            6;
        final cardHeight =
            (cardWidth / 1.9).clamp(176.0, 280.0) + textScaleExtra;

        return CustomScrollView(
          controller: scrollController,
          cacheExtent: 600,
          physics: const AlwaysScrollableScrollPhysics(
            parent: ClampingScrollPhysics(),
          ),
          slivers: [
            SliverGrid.builder(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: spacing,
                mainAxisSpacing: spacing,
                mainAxisExtent: cardHeight,
              ),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final module = items[index];
                return TrainingLibraryVisibleItem(
                  key: ValueKey(module.id),
                  onVisible: () => onItemVisible(module.id),
                  child: TrainingLibraryModuleCard(
                    module: module,
                    onTap: () => onModuleTap(module),
                    onLongPress: actionsFor(module),
                  ),
                );
              },
            ),
            if (footer != null) SliverToBoxAdapter(child: footer),
            SliverToBoxAdapter(
              child: SizedBox(
                height: MediaQuery.paddingOf(context).bottom + 16,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _TrainingLibraryList extends StatelessWidget {
  const _TrainingLibraryList({
    required this.items,
    required this.footer,
    required this.onItemVisible,
    required this.scrollController,
    required this.onModuleTap,
    required this.actionsFor,
  });

  final List<TrainingLibraryModule> items;
  final Widget? footer;
  final ValueChanged<String> onItemVisible;
  final ScrollController scrollController;
  final ValueChanged<TrainingLibraryModule> onModuleTap;
  final VoidCallback? Function(TrainingLibraryModule module) actionsFor;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      controller: scrollController,
      cacheExtent: 600,
      padding: EdgeInsets.only(
        bottom: MediaQuery.paddingOf(context).bottom + 16,
      ),
      physics: const AlwaysScrollableScrollPhysics(
        parent: ClampingScrollPhysics(),
      ),
      itemCount: items.length + (footer != null ? 1 : 0),
      separatorBuilder: (_, index) => SizedBox(
        height: footer != null && index == items.length - 1 ? 18 : 16,
      ),
      itemBuilder: (context, index) {
        if (index == items.length) {
          return footer!;
        }
        final module = items[index];
        return TrainingLibraryVisibleItem(
          key: ValueKey(module.id),
          onVisible: () => onItemVisible(module.id),
          child: TrainingLibraryModuleCard(
            module: module,
            onTap: () => onModuleTap(module),
            onLongPress: actionsFor(module),
          ),
        );
      },
    );
  }
}
