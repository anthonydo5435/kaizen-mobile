part of 'package:sparrowkaizen/features/training/presentation/pages/edit_training_screen.dart';

extension _EditTrainingSectionViewStateMedia on _EditTrainingSectionViewState {
  void _prepareForExternalMediaPicker() {
    if (!widget.skipResumeSessionRefreshOnMediaPicker) {
      return;
    }

    AppManager.instance.skipNextResumeSessionRefresh();
  }

  void _setFinalizingVideoSetup(bool value) {
    if (!mounted || _isFinalizingVideoSetup == value) {
      return;
    }

    _isFinalizingVideoSetupNotifier.value = value;
  }

  void _setPickingVideo(bool value) {
    if (!mounted || _isPickingVideo == value) {
      return;
    }

    _isPickingVideoNotifier.value = value;
  }

  Future<void> _selectVideoSourceAndUpload(
    TrainingModuleController controller,
  ) async {
    if (!controller.canUploadSelectedModuleVideo ||
        _isPickingVideo ||
        !_ensureNoModuleVideoUploadInProgress(controller)) {
      return;
    }

    final selection = await _showVideoSourcePicker();
    if (!mounted || selection == null) {
      return;
    }

    if (selection.usesCamera) {
      await _pickAndUploadVideo(controller, ImageSource.camera);
      return;
    }

    if (selection.usesSystemGalleryPicker) {
      await _pickAndUploadVideo(controller, ImageSource.gallery);
      return;
    }

    final asset = selection.asset;
    if (asset == null) {
      return;
    }

    await _uploadSelectedGalleryVideo(controller, asset);
  }

  Future<_TrainingVideoPickerSelection?> _showVideoSourcePicker() {
    return showModalBottomSheet<_TrainingVideoPickerSelection>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Platform.isAndroid
          ? const _TrainingVideoSystemPickerSheet()
          : const _TrainingVideoGalleryPickerSheet(),
    );
  }

  Future<void> _pickAndUploadVideo(
    TrainingModuleController controller,
    ImageSource source,
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

      _prepareForExternalMediaPicker();
      final selectedVideo = await _pickVideoFile(source);
      if (!mounted || selectedVideo == null) {
        _setFinalizingVideoSetup(false);
        return;
      }

      if (source == ImageSource.camera &&
          !selectedVideo.isSavedDirectlyToGallery) {
        await _persistCapturedVideoToGallery(selectedVideo.file);
      }

      if (widget.useNonBlockingVideoUpload) {
        final didStart = await _startNonBlockingVideoUpload(
          controller,
          selectedVideo.file,
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
        selectedVideo.file,
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
      _showNonApiSnackBar(_buildVideoErrorMessage(source, error));
    } catch (_) {
      _setFinalizingVideoSetup(false);
      if (!mounted) {
        return;
      }
      _showNonApiSnackBar(
        source == ImageSource.camera
            ? AppStrings.auditRecordVideoError
            : AppStrings.pickVideoError,
      );
    } finally {
      if (mounted && _isPickingVideo) {
        _setPickingVideo(false);
      }
    }
  }

  Future<_PickedTrainingVideo?> _pickVideoFile(ImageSource source) async {
    if (source == ImageSource.camera && Platform.isAndroid) {
      try {
        final capturedFile = await TrainingVideoCaptureBridge.instance
            .captureVideoWithSystemCamera();
        if (capturedFile != null) {
          return _PickedTrainingVideo(
            file: capturedFile,
            isSavedDirectlyToGallery: true,
          );
        }
      } on PlatformException catch (error) {
        if (!_shouldFallbackToDefaultAndroidCamera(error)) {
          rethrow;
        }
      }
    }

    final pickedFile = await _imagePicker.pickVideo(source: source);
    if (pickedFile == null) {
      return null;
    }

    return _PickedTrainingVideo(
      file: File(pickedFile.path),
      isSavedDirectlyToGallery: false,
    );
  }

  bool _shouldFallbackToDefaultAndroidCamera(PlatformException error) {
    if (!Platform.isAndroid) {
      return false;
    }

    return switch (error.code) {
      'legacy_android_capture_fallback' ||
      'modern_android_capture_fallback' ||
      'capture_cleanup_failed' ||
      'capture_destination_unavailable' ||
      'camera_launch_failed' ||
      'no_available_camera' => true,
      _ => false,
    };
  }

  Future<void> _restoreLostTrainingVideoIfNeeded() async {
    if (!Platform.isAndroid) {
      return;
    }

    try {
      await TrainingVideoCaptureBridge.instance.restorePendingCaptureIfNeeded();
      final response = await _imagePicker.retrieveLostData();
      if (!mounted || response.isEmpty) {
        return;
      }

      if (response.exception != null) {
        _showNonApiSnackBar(AppStrings.auditRestoreMediaError);
        return;
      }

      final restoredFile =
          response.file ??
          (response.files?.isNotEmpty == true ? response.files!.first : null);
      if (restoredFile == null || !_isRecoveredVideo(response, restoredFile)) {
        return;
      }

      final videoFile = File(restoredFile.path);
      await _persistCapturedVideoToGallery(videoFile);
    } catch (error) {
      debugPrint('Unable to restore lost training video: $error');
      if (mounted) {
        _showNonApiSnackBar(AppStrings.auditRestoreMediaError);
      }
    }
  }

  bool _isRecoveredVideo(LostDataResponse response, XFile restoredFile) {
    if (response.type == RetrieveType.video) {
      return true;
    }

    final contentType = CustomFunctions.contentTypeFromPath(
      restoredFile.path,
      fallback: 'application/octet-stream',
    );
    return contentType.startsWith('video/');
  }

  Future<void> _persistCapturedVideoToGallery(File mediaFile) async {
    if (Platform.isAndroid) {
      return;
    }

    if (!await mediaFile.exists()) {
      if (mounted) {
        _showNonApiSnackBar(AppStrings.auditRecordedVideoMissing);
      }
      return;
    }

    try {
      final permissionState = await PhotoManager.requestPermissionExtend(
        requestOption: const PermissionRequestOption(
          iosAccessLevel: IosAccessLevel.addOnly,
          androidPermission: AndroidPermission(
            type: RequestType.video,
            mediaLocation: false,
          ),
        ),
      );
      if (!mounted) {
        return;
      }

      if (!permissionState.hasAccess) {
        _showNonApiSnackBar(AppStrings.auditSaveRecordedVideoPermission);
        return;
      }

      await PhotoManager.editor.saveVideo(
        mediaFile,
        title: CustomFunctions.fileNameFromPath(
          mediaFile.path,
          fallback: 'training-video.mp4',
        ),
      );
    } catch (error) {
      debugPrint('Unable to save training video to gallery: $error');
      if (mounted) {
        _showNonApiSnackBar(AppStrings.auditSaveRecordedVideoError);
      }
    }
  }

  Future<void> _reUploadVideo(TrainingModuleController controller) async {
    if (!controller.canUploadSelectedModuleVideo ||
        _isPickingVideo ||
        _isFinalizingVideoSetup ||
        !_ensureNoModuleVideoUploadInProgress(controller)) {
      return;
    }

    final moduleId = controller.selectedModuleId;
    final didDelete = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.56),
      builder: (_) => ChangeNotifierProvider<TrainingModuleController>.value(
        value: controller,
        child: _ReUploadTrainingVideoDialog(
          moduleTitle: controller.selectedModuleTitle,
        ),
      ),
    );

    if (!mounted || controller.selectedModuleId != moduleId) {
      return;
    }

    if (didDelete == true) {
      await _selectVideoSourceAndUpload(controller);
      return;
    }

    if (didDelete == false) {
      final message = controller.errorMessage?.trim();
      if (message != null && message.isNotEmpty) {
        _showApiErrorSnackBar(message);
      }
    }
  }

  Future<void> _handleVideoUploadSuccess(
    TrainingModuleController controller,
  ) async {
    try {
      await _showThumbnailPickerDialog(controller);
    } finally {
      _setFinalizingVideoSetup(false);
    }
  }

  Future<bool> _showThumbnailPickerDialog(
    TrainingModuleController controller,
  ) async {
    final didUploadThumbnail = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.56),
      builder: (dialogContext) =>
          ChangeNotifierProvider<TrainingModuleController>.value(
            value: controller,
            child: _TrainingThumbnailPickerDialog(
              onSelectThumbnailTap: () async {
                final didUpload = await _pickAndUploadThumbnail(controller);
                if (didUpload == true && dialogContext.mounted) {
                  Navigator.of(dialogContext).pop(true);
                }
              },
              onSkipTap: () {
                if (!controller.isUploadingThumbnail && dialogContext.mounted) {
                  Navigator.of(dialogContext).pop(false);
                }
              },
            ),
          ),
    );

    return didUploadThumbnail == true;
  }

  Future<bool?> _pickAndUploadThumbnail(
    TrainingModuleController controller,
  ) async {
    if (controller.isUpdatingVideoActions) {
      return false;
    }

    try {
      _prepareForExternalMediaPicker();
      final pickedFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (!mounted || pickedFile == null) {
        return null;
      }

      final didUpload = await controller.uploadThumbnailForSelectedModule(
        File(pickedFile.path),
      );
      if (!mounted) {
        return false;
      }

      if (didUpload != true) {
        final message = controller.errorMessage?.trim();
        if (message != null && message.isNotEmpty) {
          _showApiErrorSnackBar(message);
        }
        return false;
      }

      return true;
    } on PlatformException catch (error) {
      if (!mounted) {
        return false;
      }
      _showNonApiSnackBar(_buildImageErrorMessage(error));
    } catch (_) {
      if (!mounted) {
        return false;
      }
      _showNonApiSnackBar(AppStrings.pickImageError);
    }

    return false;
  }

  String _buildVideoErrorMessage(ImageSource source, PlatformException error) {
    final errorCode = error.code.toLowerCase();
    final errorMessage = (error.message ?? '').toLowerCase();
    final isCamera = source == ImageSource.camera;

    if (isCamera &&
        (errorCode.contains('camera_access_denied') ||
            errorCode.contains('camera_denied') ||
            errorMessage.contains('access to the camera'))) {
      return AppStrings.auditCameraPermissionVideo;
    }

    if (!isCamera &&
        (errorCode.contains('photo_access_denied') ||
            errorCode.contains('photo_access_restricted') ||
            errorMessage.contains('photo library'))) {
      return AppStrings.auditPhotoLibraryPermissionVideo;
    }

    return isCamera
        ? AppStrings.auditRecordVideoError
        : AppStrings.pickVideoError;
  }

  String _buildImageErrorMessage(PlatformException error) {
    final errorCode = error.code.toLowerCase();
    final errorMessage = (error.message ?? '').toLowerCase();
    if (errorCode.contains('photo_access_denied') ||
        errorCode.contains('photo_access_restricted') ||
        errorMessage.contains('photo library')) {
      return AppStrings.auditPhotoLibraryPermissionImage;
    }

    return AppStrings.pickImageError;
  }
}
