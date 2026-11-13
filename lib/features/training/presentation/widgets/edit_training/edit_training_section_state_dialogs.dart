part of 'package:sparrowkaizen/features/training/presentation/pages/edit_training_screen.dart';

extension _EditTrainingSectionViewStateDialogs
    on _EditTrainingSectionViewState {
  void _showApiErrorSnackBar(String message) {
    _showSnackBar(message);
  }

  void _showNonApiSnackBar(String message) {
    if (widget.showOnlyApiErrorSnackBars) {
      return;
    }

    _showSnackBar(message);
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: AppColors.surfaceDark3,
        ),
      );
  }

  Future<T?> _showTrainingModalBottomSheet<T>({
    required WidgetBuilder builder,
    Color? barrierColor,
  }) async {
    _beginTrainingModalSheetPresentation();

    try {
      return await showModalBottomSheet<T>(
        context: context,
        backgroundColor: Colors.transparent,
        barrierColor: barrierColor,
        isScrollControlled: true,
        isDismissible: true,
        enableDrag: true,
        builder: builder,
      );
    } finally {
      _endTrainingModalSheetPresentation();
    }
  }

  Future<void> _showDeleteModuleDialog({
    required TrainingModuleController controller,
    required SeatDescriptionTrainingModule module,
  }) async {
    final didDelete = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.56),
      builder: (_) => ChangeNotifierProvider<TrainingModuleController>.value(
        value: controller,
        child: _DeleteModuleDialog(module: module),
      ),
    );

    if (!mounted) {
      return;
    }

    if (didDelete == true) {
      await _syncSelectedTabData(controller);
      return;
    }

    if (didDelete == false) {
      final message = controller.errorMessage?.trim();
      if (message != null && message.isNotEmpty) {
        _showApiErrorSnackBar(message);
      }
    }
  }

  Future<void> _showDeleteQuestionDialog({
    required TrainingModuleController controller,
    required SeatDescriptionTrainingQuestion question,
  }) async {
    final didDelete = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.56),
      builder: (_) => ChangeNotifierProvider<TrainingModuleController>.value(
        value: controller,
        child: _DeleteQuestionDialog(question: question),
      ),
    );

    if (!mounted) {
      return;
    }

    if (didDelete == false) {
      final message = controller.questionsErrorMessage?.trim();
      if (message != null && message.isNotEmpty) {
        _showApiErrorSnackBar(message);
      }
    }
  }

  Future<void> _showModuleTitleEditBottomSheet(
    TrainingModuleController controller,
  ) async {
    if (!controller.canEditSelectedModuleTitle) {
      return;
    }

    await _showTrainingModalBottomSheet<bool>(
      barrierColor: Colors.black.withValues(alpha: 0.56),
      builder: (_) => _TrainingTextEditSheet(
        sheetTitle: AppStrings.trainingEditFieldTitle(
          AppStrings.trainingLessonTitle,
        ),
        sheetDescription: AppStrings.trainingEditTextSheetDescription,
        fieldLabel: AppStrings.trainingLessonTitle,
        hintText: AppStrings.trainingLessonTitleHint,
        initialValue: controller.selectedModuleTitle,
        minLines: 1,
        maxLines: 2,
        textInputAction: TextInputAction.done,
        saveButtonLabel: AppStrings.trainingSaveChangesAction,
        saveIcon: Icons.check_rounded,
        validator: (value) =>
            value.trim().isEmpty ? AppStrings.trainingFieldValueRequired : null,
        onSave: controller.saveSelectedModuleTitleForSelectedModule,
      ),
    );
  }

  Future<void> _showGenerateQuizDialog(
    TrainingModuleController controller,
  ) async {
    if (!controller.canGenerateQuizForSelectedModule) {
      return;
    }

    controller.resetQuizGenerationForm();

    final didGenerate = await _showTrainingModalBottomSheet<bool>(
      barrierColor: Colors.black.withValues(alpha: 0.56),
      builder: (_) => ChangeNotifierProvider<TrainingModuleController>.value(
        value: controller,
        child: const _GenerateQuizDialog(),
      ),
    );

    if (!mounted || didGenerate != true) {
      return;
    }
  }

  Future<void> _handleGenerateAssignmentTap(
    TrainingModuleController controller,
  ) async {
    if (!controller.canGenerateAssignmentForSelectedModule) {
      return;
    }

    await _showTrainingModalBottomSheet<bool>(
      builder: (_) => ChangeNotifierProvider<TrainingModuleController>.value(
        value: controller,
        child: const _GenerateAssignmentDialog(),
      ),
    );
  }

  Future<void> _showAddQuestionDialog(
    TrainingModuleController controller,
  ) async {
    if (!controller.canAddQuestionToSelectedModule) {
      return;
    }

    final didAdd = await _showTrainingModalBottomSheet<bool>(
      barrierColor: Colors.black.withValues(alpha: 0.56),
      builder: (_) => ChangeNotifierProvider<TrainingModuleController>.value(
        value: controller,
        child: _AddQuestionDialog(
          onPickImage: () async {
            _prepareForExternalMediaPicker();
            final image = await _imagePicker.pickImage(
              source: ImageSource.gallery,
              imageQuality: 85,
            );
            return image == null ? null : File(image.path);
          },
        ),
      ),
    );

    if (!mounted || didAdd != true) {
      return;
    }
  }

  Future<void> _showEditQuestionDialog(
    TrainingModuleController controller,
    SeatDescriptionTrainingQuestion question,
  ) async {
    if (!controller.canManageTraining ||
        controller.isSavingQuestion(question.uuid) ||
        controller.isDeletingQuestion(question.uuid) ||
        !controller.selectedModuleQuestions.any(
          (item) => item.uuid == question.uuid,
        )) {
      return;
    }

    await _showTrainingModalBottomSheet<bool>(
      builder: (_) => ChangeNotifierProvider<TrainingModuleController>.value(
        value: controller,
        child: _EditQuestionDialog(
          question: question,
          moduleId: controller.selectedModuleId,
        ),
      ),
    );
  }

  Future<void> _handleGenerateSopTap(
    TrainingModuleController controller,
  ) async {
    if (!controller.canGenerateSopForSelectedModule ||
        controller.isDocumentLoading) {
      return;
    }

    await _showGenerateSopDialog(controller);
  }

  Future<void> _showGenerateSopDialog(
    TrainingModuleController controller,
  ) async {
    final didGenerate = await _showTrainingModalBottomSheet<bool>(
      builder: (_) => ChangeNotifierProvider<TrainingModuleController>.value(
        value: controller,
        child: const _GenerateSopDialog(),
      ),
    );

    if (!mounted || didGenerate != true) {
      return;
    }
  }
}
