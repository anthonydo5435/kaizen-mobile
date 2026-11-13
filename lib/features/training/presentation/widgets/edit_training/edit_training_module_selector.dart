part of 'package:sparrowkaizen/features/training/presentation/pages/edit_training_screen.dart';

class TrainingLessonSelector extends StatelessWidget {
  const TrainingLessonSelector({
    super.key,
    required this.controller,
    required this.onModuleSelected,
    this.onAddNewLessonTap,
    this.onDeleteModuleTap,
  });

  final TrainingModuleController controller;
  final VoidCallback? onAddNewLessonTap;
  final Future<void> Function(String moduleId) onModuleSelected;
  final Future<void> Function(SeatDescriptionTrainingModule module)? onDeleteModuleTap;

  Future<void> _showModuleSheet(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.56),
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      builder: (_) => _ModuleSelectionSheet(
        controller: controller,
        onModuleSelected: onModuleSelected,
        onDeleteModuleTap: onDeleteModuleTap,
        onAddNewLessonTap: onAddNewLessonTap,
      ),
    );
  }

  void _handleModuleSwipe(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    final selectedIndex = controller.selectedModuleIndex;
    if (velocity >= 220 && controller.canSelectPreviousModule) {
      unawaited(onModuleSelected(controller.modules[selectedIndex - 1].uuid));
    } else if (velocity <= -220) {
      if (controller.canSelectNextModule) {
        unawaited(onModuleSelected(controller.modules[selectedIndex + 1].uuid));
      } else if (controller.canSelectFirstModuleFromDraft) {
        unawaited(onModuleSelected(controller.modules.first.uuid));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.translucent,
          onHorizontalDragEnd: controller.canSwipeBetweenModules ? _handleModuleSwipe : null,
          child: _LessonOverviewRow(
            selectedModule: controller.selectedModule,
            selectedTitle: controller.selectedModuleTitle,
            canAddLesson: controller.canManageTraining && onAddNewLessonTap != null,
            isCreatingNewLesson: controller.isCreatingNewLessonDraft,
            onAddLesson: onAddNewLessonTap,
            onShowAllLessons: () => unawaited(_showModuleSheet(context)),
          ),
        ),
        const SizedBox(height: 22),
        const AppDotDivider(),
        const SizedBox(height: 18),
      ],
    );
  }
}

class _LessonOverviewRow extends StatelessWidget {
  const _LessonOverviewRow({
    required this.selectedModule,
    required this.selectedTitle,
    required this.canAddLesson,
    required this.isCreatingNewLesson,
    required this.onAddLesson,
    required this.onShowAllLessons,
  });

  final SeatDescriptionTrainingModule? selectedModule;
  final String selectedTitle;
  final bool canAddLesson;
  final bool isCreatingNewLesson;
  final VoidCallback? onAddLesson;
  final VoidCallback onShowAllLessons;

  @override
  Widget build(BuildContext context) {
    final module = selectedModule;

    return SizedBox(
      height: 72,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (module != null) ...[
            Expanded(
              flex: 4,
              child: _OpenedLessonCard(
                module: module,
                title: selectedTitle,
                onTap: onShowAllLessons,
              ),
            ),
            const SizedBox(width: 12),
          ],
          if (canAddLesson) ...[
            Expanded(
              flex: 4,
              child: _NewLessonCard(isSelected: isCreatingNewLesson, onTap: onAddLesson!),
            ),
            const SizedBox(width: 12),
          ],
          _SeeAllLessonsButton(onTap: onShowAllLessons),
        ],
      ),
    );
  }
}

class _OpenedLessonCard extends StatelessWidget {
  const _OpenedLessonCard({required this.module, required this.title, required this.onTap});

  final SeatDescriptionTrainingModule module;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: true,
      label: title,
      onTap: onTap,
      excludeSemantics: true,
      child: Material(
        color: AppColors.surfaceDark3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.textPrimary, width: 1.5),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            _OpenedLessonThumbnail(thumbnailLink: module.thumbnailLink),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black54],
                ),
              ),
            ),
            Positioned(
              left: 8,
              right: 8,
              bottom: 6,
              child: AppTextView.body2(
                title,
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Material(
              color: Colors.transparent,
              child: InkWell(onTap: onTap),
            ),
          ],
        ),
      ),
    );
  }
}

class _OpenedLessonThumbnail extends StatelessWidget {
  const _OpenedLessonThumbnail({required this.thumbnailLink});

  final String? thumbnailLink;

  @override
  Widget build(BuildContext context) {
    final imageUrl = CustomFunctions.resolveImageUrl(thumbnailLink);
    if (imageUrl == null) {
      return const _ModuleThumbnailPlaceholder();
    }

    return CachedNetworkImage(
      imageUrl: imageUrl,
      fit: BoxFit.cover,
      placeholder: (_, _) => const _ModuleThumbnailPlaceholder(),
      errorWidget: (_, _, _) => const _ModuleThumbnailPlaceholder(),
    );
  }
}

class _NewLessonCard extends StatelessWidget {
  const _NewLessonCard({required this.isSelected, required this.onTap});

  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected ? AppColors.secondaryColor.withValues(alpha: 0.08) : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: CustomPaint(
          foregroundPainter: const _DottedRoundedBorderPainter(
            color: AppColors.secondaryColor,
            radius: 12,
            strokeWidth: 0.6,
            dashLength: 1.5,
            gapLength: 1,
          ),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 10),
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add_circle_outline_rounded, color: AppColors.lightPurple1, size: 18),
                    SizedBox(width: 6),
                    AppTextView.body2(
                      AppStrings.trainingNewLesson,
                      color: AppColors.lightPurple1,
                      fontWeight: FontWeight.w500,
                      maxLines: 1,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SeeAllLessonsButton extends StatelessWidget {
  const _SeeAllLessonsButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 44,
      child: Material(
        color: AppColors.secondaryColor,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: IconButton(
          onPressed: onTap,
          tooltip: AppStrings.trainingAllLessons,
          padding: EdgeInsets.zero,
          icon: const Icon(Icons.north_east, color: AppColors.textPrimary, size: 24),
        ),
      ),
    );
  }
}

class _ModuleSelectionSheet extends StatelessWidget {
  const _ModuleSelectionSheet({
    required this.controller,
    required this.onModuleSelected,
    required this.onDeleteModuleTap,
    this.onAddNewLessonTap,
  });

  final TrainingModuleController controller;
  final Future<void> Function(String moduleId) onModuleSelected;
  final Future<void> Function(SeatDescriptionTrainingModule module)? onDeleteModuleTap;
  final VoidCallback? onAddNewLessonTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(animation: controller, builder: (context, _) => _buildSheet(context));
  }

  Widget _buildSheet(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: 16, bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Align(
        alignment: Alignment.bottomCenter,
        heightFactor: 1,
        child: Container(
          width: double.infinity,
          constraints: BoxConstraints(
            maxWidth: 620,
            maxHeight: MediaQuery.sizeOf(context).height * 0.85,
          ),
          decoration: const BoxDecoration(
            color: AppColors.mainBg,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 38,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.92),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: AppTextView.body1(
                          AppStrings.trainingAllLessons,
                          color: AppColors.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      _DialogCloseButton(onTap: () => Navigator.of(context).pop()),
                    ],
                  ),
                  if (controller.canManageTraining && onAddNewLessonTap != null) ...[
                    const SizedBox(height: 18),
                    _AddNewLessonSheetButton(
                      onTap:
                          controller.isLoading ||
                              controller.isCreatingModule ||
                              controller.isCreatingNewLessonDraft
                          ? null
                          : () {
                              Navigator.of(context).pop();
                              onAddNewLessonTap!();
                            },
                    ),
                  ],
                  if (controller.modules.isNotEmpty) ...[
                    const SizedBox(height: 18),
                    ListView.separated(
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: controller.modules.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final module = controller.modules[index];
                        return _ModuleSheetTile(
                          key: ValueKey(module.uuid),
                          module: module,
                          isSelected:
                              !controller.isCreatingNewLessonDraft &&
                              module.uuid == controller.selectedModuleId,
                          isDeleting: controller.deletingModuleId == module.uuid,
                          showDeleteAction:
                              controller.canManageTraining && onDeleteModuleTap != null,
                          onTap: () {
                            Navigator.of(context).pop();
                            unawaited(onModuleSelected(module.uuid));
                          },
                          onDeleteTap: () {
                            if (!controller.canManageTraining ||
                                onDeleteModuleTap == null ||
                                controller.deletingModuleId == module.uuid) {
                              return;
                            }
                            Navigator.of(context).pop();
                            unawaited(onDeleteModuleTap!(module));
                          },
                        );
                      },
                    ),
                  ] else ...[
                    const SizedBox(height: 18),
                    AppTextView.body3(
                      AppStrings.trainingNoModulesAvailable,
                      color: AppColors.textSecondary,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AddNewLessonSheetButton extends StatelessWidget {
  const _AddNewLessonSheetButton({required this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => CustomPaint(
    foregroundPainter: _DottedRoundedBorderPainter(
      color: AppColors.secondaryColor.withValues(alpha: onTap == null ? 0.4 : 0.7),
      radius: 12,
      strokeWidth: 1.2,
      dashLength: 1.2,
      gapLength: 3,
    ),
    child: OutlinedButton.icon(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.secondaryColor,
        minimumSize: const Size.fromHeight(48),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        side: BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      icon: const Icon(Icons.add_rounded, size: 20),
      label: AppTextView.body2(
        AppStrings.trainingAddNewLesson,
        color: AppColors.secondaryColor.withValues(alpha: onTap == null ? 0.4 : 1),
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
    ),
  );
}

class _ModuleSheetTile extends StatelessWidget {
  const _ModuleSheetTile({
    super.key,
    required this.module,
    required this.isSelected,
    required this.isDeleting,
    required this.showDeleteAction,
    required this.onTap,
    required this.onDeleteTap,
  });

  final SeatDescriptionTrainingModule module;
  final bool isSelected;
  final bool isDeleting;
  final bool showDeleteAction;
  final VoidCallback onTap;
  final VoidCallback onDeleteTap;

  @override
  Widget build(BuildContext context) {
    final resolvedThumbnail = CustomFunctions.resolveImageUrl(module.thumbnailLink);

    return TrainingSwipeDeleteAction(
      onDelete: showDeleteAction && !isDeleting ? onDeleteTap : null,
      deleteSemanticLabel: AppStrings.trainingLibraryDeleteLessonTitle,
      borderRadius: 18,
      backgroundColor: AppColors.mainBg,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isDeleting ? null : onTap,
          borderRadius: BorderRadius.circular(18),
          child: Ink(
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.secondaryColor.withValues(alpha: 0.1)
                  : AppColors.surfaceDark3,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isSelected
                    ? AppColors.secondaryColor.withValues(alpha: 0.42)
                    : AppColors.fieldBorder.withValues(alpha: 0.22),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: SizedBox(
                      width: 82,
                      height: 60,
                      child: resolvedThumbnail == null
                          ? const _ModuleThumbnailPlaceholder()
                          : CachedNetworkImage(
                              imageUrl: resolvedThumbnail,
                              fit: BoxFit.cover,
                              placeholder: (_, _) => const _ModuleThumbnailPlaceholder(),
                              errorWidget: (_, _, _) => const _ModuleThumbnailPlaceholder(),
                            ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AppTextView.body2(
                      module.title,
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (isDeleting) ...[
                    const SizedBox(width: 12),
                    const FastCircularProgressIndicator(width: 16, height: 16),
                  ] else if (isSelected) ...[
                    const SizedBox(width: 12),
                    const Icon(
                      Icons.check_circle_rounded,
                      color: AppColors.secondaryColor,
                      size: 20,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
