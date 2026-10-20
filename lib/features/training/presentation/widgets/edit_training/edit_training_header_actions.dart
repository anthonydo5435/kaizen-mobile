part of 'package:sparrowkaizen/features/training/presentation/pages/edit_training_screen.dart';

class _TrainingHeaderActions extends StatelessWidget {
  const _TrainingHeaderActions({
    required this.controller,
    required this.onShowAllLessons,
    required this.onAddLesson,
  });

  final TrainingModuleController controller;
  final VoidCallback onShowAllLessons;
  final VoidCallback onAddLesson;

  @override
  Widget build(BuildContext context) {
    final isBusy = controller.isLoading || controller.isCreatingModule;
    final actionSpacing = MediaQuery.orientationOf(context) == Orientation.landscape ? 4.0 : 8.0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppBarGradientAction(
          label: AppStrings.trainingAllLessons,
          icon: Icons.format_list_bulleted_rounded,
          endPadding: actionSpacing,
          compact: true,
          onTap: isBusy ? null : onShowAllLessons,
        ),
        if (controller.canManageTraining)
          AppBarGradientAction(
            label: AppStrings.trainingNewLesson,
            icon: Icons.add_rounded,
            endPadding: actionSpacing,
            compact: true,
            onTap: isBusy || controller.isCreatingNewLessonDraft ? null : onAddLesson,
          ),
        const TrainingShareAction(iconOnly: true),
      ],
    );
  }
}

extension _EditTrainingSectionViewStateHeaderActions on _EditTrainingSectionViewState {
  Future<void> _showAllLessons(TrainingModuleController controller) async {
    FocusScope.of(context).unfocus();
    await _showTrainingModalBottomSheet<void>(
      barrierColor: Colors.black.withValues(alpha: 0.56),
      builder: (_) => _ModuleSelectionSheet(
        controller: controller,
        onAddNewLessonTap: controller.canManageTraining ? () => _startNewLesson(controller) : null,
        onModuleSelected: (moduleId) async {
          await controller.selectModule(moduleId);
          if (mounted) await _syncSelectedTabData(controller);
        },
        onDeleteModuleTap: controller.canManageTraining
            ? (module) => _showDeleteModuleDialog(controller: controller, module: module)
            : null,
      ),
    );
  }

  void _startNewLesson(TrainingModuleController controller) {
    if (!controller.canManageTraining ||
        controller.isLoading ||
        controller.isCreatingModule ||
        controller.isCreatingNewLessonDraft) {
      return;
    }
    _tabNavigation.selectTab(0);
    controller.startCreatingNewLessonDraft();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && controller.isCreatingNewLessonDraft) {
        _newLessonTitleFocusNode.requestFocus();
      }
    });
  }
}
