part of 'package:sparrowkaizen/features/training/presentation/pages/edit_training_screen.dart';

extension _EditTrainingSectionViewStateHandlers
    on _EditTrainingSectionViewState {
  void _handleTabChanged() {
    if (_lastHandledTabIndex == _selectedTabIndex) {
      return;
    }
    _lastHandledTabIndex = _selectedTabIndex;
    _cancelPortraitReset();
    _updatePreferredOrientations();
    FocusScope.of(context).unfocus();
    unawaited(_syncSelectedTabData(context.read<TrainingModuleController>()));
  }

  void _handleTrainingControllerChanged() {
    if (!mounted) {
      return;
    }

    final controller = _trainingController;
    if (controller == null) {
      return;
    }

    final currentDocumentError = _normalizeSnackBarMessage(
      controller.documentErrorMessage,
    );
    final currentAssignmentError = _normalizeSnackBarMessage(
      controller.assignmentErrorMessage,
    );
    final currentQuestionsError = _normalizeSnackBarMessage(
      controller.questionsErrorMessage,
    );

    if (currentDocumentError != null &&
        currentDocumentError != _lastDocumentErrorMessage &&
        !_isTrainingModalSheetOpen) {
      _showApiErrorSnackBar(currentDocumentError);
    }

    if (currentQuestionsError != null &&
        currentQuestionsError != _lastQuestionsErrorMessage &&
        !_isTrainingModalSheetOpen) {
      _showApiErrorSnackBar(currentQuestionsError);
    }

    if (currentAssignmentError != null &&
        currentAssignmentError != _lastAssignmentErrorMessage &&
        !_isTrainingModalSheetOpen) {
      _showApiErrorSnackBar(currentAssignmentError);
    }

    _lastDocumentErrorMessage = currentDocumentError;
    _lastAssignmentErrorMessage = currentAssignmentError;
    _lastQuestionsErrorMessage = currentQuestionsError;

    if (controller.summarySnackBarSequence >
        _lastHandledSummarySnackBarSequence) {
      _lastHandledSummarySnackBarSequence = controller.summarySnackBarSequence;
      final summaryMessage = _normalizeSnackBarMessage(
        controller.summarySnackBarMessage,
      );
      if (summaryMessage != null) {
        _showApiErrorSnackBar(summaryMessage);
      }
    }
  }

  void _handleGlobalVideoUploadChanged() {
    if (!mounted || !widget.useNonBlockingVideoUpload) {
      return;
    }

    final uploadController = TrainingVideoUploadController.instance;
    final terminalTasks = uploadController.terminalTasksSince(
      _lastHandledGlobalVideoUploadEventSequence,
    );
    final controller = _trainingController;
    if (controller == null) {
      return;
    }

    if (terminalTasks.isNotEmpty) {
      _lastHandledGlobalVideoUploadEventSequence =
          terminalTasks.last.terminalEventSequence;

      for (final task in terminalTasks) {
        if (task.descriptionId != widget.trainingDescriptionId) {
          continue;
        }

        if (task.isCompleted) {
          final uploadedVideo = task.uploadedVideo;
          if (uploadedVideo == null) {
            continue;
          }

          controller.applyBackgroundUploadedVideo(
            moduleId: task.moduleId,
            video: uploadedVideo,
            localVideoPath: task.localVideoPath,
          );
          if (controller.selectedModuleId == task.moduleId) {
            unawaited(_handleVideoUploadSuccess(controller));
          }
          continue;
        }

        if (!task.isFailed) {
          continue;
        }

        final message = task.errorMessage?.trim();
        if (message != null && message.isNotEmpty) {
          _showApiErrorSnackBar(message);
        }
      }
    }

    final summaryEvents = uploadController.summaryEventsSince(
      _lastHandledGlobalVideoSummaryEventSequence,
    );
    if (summaryEvents.isEmpty) {
      return;
    }

    _lastHandledGlobalVideoSummaryEventSequence =
        summaryEvents.last.eventSequence;

    for (final event in summaryEvents) {
      if (event.descriptionId != widget.trainingDescriptionId ||
          controller.selectedModuleId != event.moduleId) {
        continue;
      }

      controller.applyGeneratedSummaryForModule(
        moduleId: event.moduleId,
        description: event.summary,
      );

      final message = _normalizeSnackBarMessage(event.snackBarMessage);
      if (message != null) {
        _showApiErrorSnackBar(message);
      }
    }
  }

  Future<bool> _startNonBlockingVideoUpload(
    TrainingModuleController controller,
    File videoFile,
  ) {
    return TrainingVideoUploadController.instance.startUploadForTrainingModule(
      descriptionId: widget.trainingDescriptionId,
      moduleId: controller.selectedModuleId,
      moduleTitle: controller.selectedModuleTitle,
      sourceFile: videoFile,
    );
  }

  bool _ensureNoModuleVideoUploadInProgress(
    TrainingModuleController controller,
  ) {
    if (!widget.useNonBlockingVideoUpload ||
        !TrainingVideoUploadController.instance.isUploadActiveForModule(
          descriptionId: widget.trainingDescriptionId,
          moduleId: controller.selectedModuleId,
        )) {
      return true;
    }

    _showApiErrorSnackBar(
      AppStrings.trainingModuleVideoUploadAlreadyInProgress,
    );
    return false;
  }

  Future<void> _uploadSelectedGalleryVideo(
    TrainingModuleController controller,
    AssetEntity asset,
  ) async {
    if (!controller.canUploadSelectedModuleVideo ||
        _isPickingVideo ||
        !_ensureNoModuleVideoUploadInProgress(controller)) {
      return;
    }

    try {
      _setPickingVideo(true);
      if (!widget.useNonBlockingVideoUpload) {
        _setFinalizingVideoSetup(true);
      }

      final originalFile = await asset.originFile;
      final selectedFile = originalFile ?? await asset.file;
      if (!mounted || selectedFile == null) {
        _setFinalizingVideoSetup(false);
        _showNonApiSnackBar(AppStrings.pickVideoError);
        return;
      }

      if (widget.useNonBlockingVideoUpload) {
        final didStart = await _startNonBlockingVideoUpload(
          controller,
          selectedFile,
        );
        _setPickingVideo(false);
        _setFinalizingVideoSetup(false);

        if (!mounted) {
          return;
        }

        if (didStart != true) {
          final message = TrainingVideoUploadController
              .instance
              .startErrorMessage
              ?.trim();
          if (message != null && message.isNotEmpty) {
            _showApiErrorSnackBar(message);
          }
        }
        return;
      }

      final uploadFuture = controller.uploadVideoForSelectedModule(
        selectedFile,
      );
      _setPickingVideo(false);

      final didUpload = await uploadFuture;
      if (!mounted) {
        return;
      }

      if (didUpload != true) {
        _setFinalizingVideoSetup(false);
        final message = controller.errorMessage?.trim();
        if (message != null && message.isNotEmpty) {
          _showApiErrorSnackBar(message);
        }
        return;
      }

      await _handleVideoUploadSuccess(controller);
    } on PlatformException catch (error) {
      _setFinalizingVideoSetup(false);
      if (!mounted) {
        return;
      }
      _showNonApiSnackBar(_buildVideoErrorMessage(ImageSource.gallery, error));
    } catch (_) {
      _setFinalizingVideoSetup(false);
      if (!mounted) {
        return;
      }
      _showNonApiSnackBar(AppStrings.pickVideoError);
    } finally {
      if (mounted && _isPickingVideo) {
        _setPickingVideo(false);
      }
    }
  }

  String? _normalizeSnackBarMessage(String? value) {
    final resolved = value?.trim();
    if (resolved == null || resolved.isEmpty) {
      return null;
    }

    return resolved;
  }
}
