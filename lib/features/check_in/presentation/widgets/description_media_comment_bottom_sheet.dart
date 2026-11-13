import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:video_player/video_player.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/utils/custom_functions.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_keyboard_bottom_sheet_surface.dart';
import '../../../../core/widgets/app_overlay_close_button.dart';
import '../../../../core/widgets/app_text_view.dart';
import '../../../../core/widgets/fast_circular_progress.dart';
import 'description_media_image_markup_sheet.dart';

enum DescriptionMediaCommentContentType {
  photo,
  video,
  upload,
  screenRecording,
}

class DescriptionMediaCommentBottomSheet extends StatefulWidget {
  const DescriptionMediaCommentBottomSheet({
    super.key,
    required this.contentType,
    required this.onSave,
    this.initialMediaFile,
    this.initialMediaType,
    this.allowInitialMediaRemoval = true,
  });

  final DescriptionMediaCommentContentType contentType;
  final Future<void> Function(
    String comment,
    File? mediaFile,
    String? mediaType,
  )
  onSave;
  final File? initialMediaFile;
  final String? initialMediaType;
  final bool allowInitialMediaRemoval;

  @override
  State<DescriptionMediaCommentBottomSheet> createState() =>
      _DescriptionMediaCommentBottomSheetState();
}

class _DescriptionMediaCommentBottomSheetState
    extends State<DescriptionMediaCommentBottomSheet> {
  final TextEditingController _controller = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();

  File? _selectedMedia;
  String? _selectedMediaType;
  DescriptionMediaImageMarkupSession? _imageMarkupSession;
  var _isPickingMedia = false;
  var _isSaving = false;

  bool get _hasLockedInitialMedia =>
      widget.initialMediaFile != null && !widget.allowInitialMediaRemoval;

  @override
  void initState() {
    super.initState();
    _selectedMedia = widget.initialMediaFile;
    _selectedMediaType = widget.initialMediaType;
    if (_selectedMedia == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          unawaited(_initializeMedia());
        }
      });
    }
  }

  Future<void> _initializeMedia() async {
    await _restoreLostMediaIfNeeded();
    if (!mounted || _selectedMedia != null) {
      return;
    }

    switch (widget.contentType) {
      case DescriptionMediaCommentContentType.photo:
        await _capturePhoto();
      case DescriptionMediaCommentContentType.video:
        await _captureVideo();
      case DescriptionMediaCommentContentType.upload:
      case DescriptionMediaCommentContentType.screenRecording:
        return;
    }
  }

  @override
  void dispose() {
    _disposeImageMarkupPreview(_imageMarkupSession);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final comment = _controller.text.trim();
    final canSave =
        (comment.isNotEmpty || _selectedMedia != null) &&
        !_isSaving &&
        !_isPickingMedia;
    final sheetHeight = MediaQuery.sizeOf(context).height * 0.88;
    final topPadding = MediaQuery.paddingOf(context).top;
    final bottomPadding = MediaQuery.paddingOf(context).bottom;
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: keyboardInset),
      child: SafeArea(
        top: false,
        bottom: false,
        child: Container(
          height: sheetHeight,
          margin: EdgeInsets.only(top: topPadding),
          child: AppKeyboardBottomSheetSurface(
            color: AppColors.surfaceDark,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
            border: Border.all(color: AppColors.grey2.withValues(alpha: 0.55)),
            child: Padding(
              padding: EdgeInsets.fromLTRB(10, 2, 10, bottomPadding + 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(
                          left: 5,
                          top: 8,
                          bottom: 8,
                        ),
                        child: AppOverlayCloseButton(
                          onTap: _isSaving
                              ? null
                              : () => Navigator.of(context).pop(),
                        ),
                      ),
                      const Spacer(),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: _buildSelectedContent()),
                        const SizedBox(height: 8),
                        const _ReusableCommentFieldLabel(),
                        const SizedBox(height: 8),
                        _ReusableCommentField(
                          controller: _controller,
                          enabled: !_isSaving,
                          onChanged: (_) => setState(() {}),
                        ),
                        const SizedBox(height: 14),
                        AppButton(
                          text: AppStrings.saveComment,
                          onPressed: canSave ? _save : null,
                          isLoading: _isSaving,
                          backgroundColor: canSave
                              ? AppColors.secondaryColor
                              : AppColors.grey1,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSelectedContent() {
    return switch (widget.contentType) {
      DescriptionMediaCommentContentType.photo => _buildPhotoContent(),
      DescriptionMediaCommentContentType.video => _buildVideoContent(),
      DescriptionMediaCommentContentType.upload => _buildUploadContent(),
      DescriptionMediaCommentContentType.screenRecording =>
        _buildScreenRecordingContent(),
    };
  }

  Widget _buildPhotoContent() {
    return _ContentContainer(
      child: _selectedMedia == null
          ? _ActionStateView(
              isBusy: _isPickingMedia,
              title: AppStrings.auditTakePhoto,
              subtitle: AppStrings.auditCapturePhotoComment,
              buttonText: AppStrings.auditOpenCamera,
              onPressed: _isSaving || _isPickingMedia ? null : _capturePhoto,
            )
          : _SelectedMediaPreview(
              mediaFile: _selectedMedia!,
              mediaType: _selectedMediaType,
              onClear: _isSaving || _isPickingMedia
                  ? null
                  : _clearSelectedMedia,
              onEditImage: _isSaving || _isPickingMedia
                  ? null
                  : _openImageMarkupEditor,
            ),
    );
  }

  Widget _buildVideoContent() {
    return _ContentContainer(
      child: _selectedMedia == null
          ? _ActionStateView(
              isBusy: _isPickingMedia,
              title: AppStrings.auditRecordVideo,
              subtitle: AppStrings.auditCaptureVideoComment,
              buttonText: AppStrings.auditOpenVideoCamera,
              onPressed: _isSaving || _isPickingMedia ? null : _captureVideo,
            )
          : _SelectedMediaPreview(
              mediaFile: _selectedMedia!,
              mediaType: _selectedMediaType,
              onClear: _isSaving || _isPickingMedia
                  ? null
                  : _clearSelectedMedia,
            ),
    );
  }

  Widget _buildUploadContent() {
    return _ContentContainer(
      child: _selectedMedia == null
          ? _UploadMediaContent(
              isBusy: _isPickingMedia,
              onUploadPhoto: _isSaving || _isPickingMedia
                  ? null
                  : _pickImageFromGallery,
              onUploadVideo: _isSaving || _isPickingMedia
                  ? null
                  : _pickVideoFromGallery,
            )
          : _SelectedMediaPreview(
              mediaFile: _selectedMedia!,
              mediaType: _selectedMediaType,
              onClear: _isSaving || _isPickingMedia
                  ? null
                  : _clearSelectedMedia,
              onEditImage: _isSaving || _isPickingMedia
                  ? null
                  : _openImageMarkupEditor,
            ),
    );
  }

  Widget _buildScreenRecordingContent() {
    return _ContentContainer(
      child: _selectedMedia == null
          ? const _ScreenRecordingPreviewOnlyState()
          : _SelectedMediaPreview(
              mediaFile: _selectedMedia!,
              mediaType: _selectedMediaType,
              onClear: _isSaving || _isPickingMedia || _hasLockedInitialMedia
                  ? null
                  : _clearSelectedMedia,
            ),
    );
  }

  Future<void> _save() async {
    final comment = _controller.text.trim();
    if ((comment.isEmpty && _selectedMedia == null) || _isSaving) {
      return;
    }

    setState(() => _isSaving = true);
    try {
      await widget.onSave(
        comment,
        _resolvedMediaFileForSave(),
        _selectedMediaType,
      );
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (error) {
      debugPrint('Unable to create comment: $error');
      if (mounted) {
        setState(() => _isSaving = false);
        if (_selectedMedia != null) {
          CustomFunctions.showCustomAlert(
            context,
            'Failed',
            'File failed to upload!, Try again later!',
          );
        }
      }
    }
  }

  Future<void> _capturePhoto() async {
    await _pickImage(ImageSource.camera);
  }

  Future<void> _captureVideo() async {
    await _pickVideo(ImageSource.camera);
  }

  Future<void> _pickImageFromGallery() async {
    await _pickImage(ImageSource.gallery);
  }

  Future<void> _pickVideoFromGallery() async {
    await _pickVideo(ImageSource.gallery);
  }

  Future<void> _pickImage(ImageSource source) async {
    if (_isPickingMedia || _isSaving) {
      return;
    }

    setState(() => _isPickingMedia = true);
    try {
      final pickedFile = await _imagePicker.pickImage(source: source);
      if (!mounted || pickedFile == null) {
        return;
      }

      _updateSelectedMedia(File(pickedFile.path), 'image');
    } on PlatformException catch (error) {
      if (!mounted) {
        return;
      }
      _showSnackBar(_buildImageErrorMessage(source, error));
    } catch (error) {
      debugPrint('Unable to pick image: $error');
      if (mounted) {
        _showSnackBar(
          source == ImageSource.camera
              ? AppStrings.auditCameraOpenError
              : AppStrings.auditPickImageError,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isPickingMedia = false);
      }
    }
  }

  Future<void> _pickVideo(ImageSource source) async {
    if (_isPickingMedia || _isSaving) {
      return;
    }

    setState(() => _isPickingMedia = true);
    try {
      final pickedFile = await _imagePicker.pickVideo(source: source);
      if (!mounted || pickedFile == null) {
        return;
      }

      final mediaFile = File(pickedFile.path);
      _updateSelectedMedia(mediaFile, 'video');

      if (source == ImageSource.camera) {
        await _persistCapturedVideoToGallery(mediaFile);
      }
    } on PlatformException catch (error) {
      if (!mounted) {
        return;
      }
      _showSnackBar(_buildVideoErrorMessage(source, error));
    } catch (error) {
      debugPrint('Unable to pick video: $error');
      if (mounted) {
        _showSnackBar(
          source == ImageSource.camera
              ? AppStrings.auditRecordVideoError
              : AppStrings.auditPickVideoError,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isPickingMedia = false);
      }
    }
  }

  Future<void> _restoreLostMediaIfNeeded() async {
    if (!Platform.isAndroid || _selectedMedia != null) {
      return;
    }

    try {
      final response = await _imagePicker.retrieveLostData();
      if (!mounted || response.isEmpty) {
        return;
      }

      if (response.exception != null) {
        _showSnackBar(AppStrings.auditRestoreMediaError);
        return;
      }

      final restoredFile =
          response.file ??
          (response.files?.isNotEmpty == true ? response.files!.first : null);
      if (restoredFile == null) {
        return;
      }

      final restoredMediaType = _resolveRecoveredMediaType(
        retrieveType: response.type,
        path: restoredFile.path,
      );
      if (restoredMediaType == null ||
          !_canRestoreRecoveredMedia(restoredMediaType)) {
        return;
      }

      final mediaFile = File(restoredFile.path);
      if (!await mediaFile.exists()) {
        if (!mounted) {
          return;
        }
        _showSnackBar(
          restoredMediaType == 'video'
              ? AppStrings.auditRecordedVideoMissing
              : AppStrings.auditPickImageError,
        );
        return;
      }

      if (!mounted) {
        return;
      }

      _updateSelectedMedia(mediaFile, restoredMediaType);

      if (restoredMediaType == 'video' &&
          widget.contentType == DescriptionMediaCommentContentType.video) {
        await _persistCapturedVideoToGallery(mediaFile);
      }
    } catch (error) {
      debugPrint('Unable to restore lost media: $error');
      if (mounted) {
        _showSnackBar(AppStrings.auditRestoreMediaError);
      }
    }
  }

  String? _resolveRecoveredMediaType({
    required RetrieveType? retrieveType,
    required String path,
  }) {
    if (retrieveType == RetrieveType.image) {
      return 'image';
    }
    if (retrieveType == RetrieveType.video) {
      return 'video';
    }

    final contentType = CustomFunctions.contentTypeFromPath(
      path,
      fallback: 'application/octet-stream',
    );
    if (contentType.startsWith('image/')) {
      return 'image';
    }
    if (contentType.startsWith('video/')) {
      return 'video';
    }

    return null;
  }

  bool _canRestoreRecoveredMedia(String mediaType) {
    return switch (widget.contentType) {
      DescriptionMediaCommentContentType.photo => mediaType == 'image',
      DescriptionMediaCommentContentType.video => mediaType == 'video',
      DescriptionMediaCommentContentType.upload =>
        mediaType == 'image' || mediaType == 'video',
      DescriptionMediaCommentContentType.screenRecording => false,
    };
  }

  Future<void> _persistCapturedVideoToGallery(File mediaFile) async {
    if (Platform.isAndroid) {
      return;
    }

    if (!await mediaFile.exists()) {
      if (mounted) {
        _showSnackBar(AppStrings.auditRecordedVideoMissing);
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
        _showSnackBar(AppStrings.auditSaveRecordedVideoPermission);
        return;
      }

      await PhotoManager.editor.saveVideo(
        mediaFile,
        title: CustomFunctions.fileNameFromPath(
          mediaFile.path,
          fallback: 'audit-video.mp4',
        ),
      );
    } catch (error) {
      debugPrint('Unable to save recorded video to gallery: $error');
      if (mounted) {
        _showSnackBar(AppStrings.auditSaveRecordedVideoError);
      }
    }
  }

  String _buildImageErrorMessage(ImageSource source, PlatformException error) {
    final errorCode = error.code.toLowerCase();
    final errorMessage = (error.message ?? '').toLowerCase();
    final isCamera = source == ImageSource.camera;

    if (isCamera &&
        (errorCode.contains('camera_access_denied') ||
            errorCode.contains('camera_denied') ||
            errorMessage.contains('access to the camera'))) {
      return AppStrings.auditCameraPermissionPhoto;
    }

    if (!isCamera &&
        (errorCode.contains('photo_access_denied') ||
            errorCode.contains('photo_access_restricted') ||
            errorMessage.contains('photo library'))) {
      return AppStrings.auditPhotoLibraryPermissionImage;
    }

    return isCamera
        ? AppStrings.auditCameraOpenError
        : AppStrings.auditPickImageError;
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
        : AppStrings.auditPickVideoError;
  }

  void _clearSelectedMedia() {
    final previousMarkupSession = _imageMarkupSession;
    setState(() {
      _selectedMedia = null;
      _selectedMediaType = null;
      _imageMarkupSession = null;
    });
    _disposeImageMarkupPreview(previousMarkupSession);
  }

  Future<void> _openImageMarkupEditor() async {
    final selectedMediaType = _selectedMediaType?.trim().toLowerCase();
    if (_isSaving || _isPickingMedia || selectedMediaType != 'image') {
      return;
    }

    final sourceImageFile =
        _imageMarkupSession?.sourceImageFile ?? _selectedMedia;
    if (sourceImageFile == null) {
      return;
    }

    final markupSession = await showDescriptionMediaImageMarkupSheet(
      context,
      imageFile: sourceImageFile,
      initialSession: _imageMarkupSession,
    );
    if (!mounted || markupSession == null) {
      return;
    }

    _applyImageMarkupSession(markupSession);
  }

  void _updateSelectedMedia(File mediaFile, String mediaType) {
    final previousMarkupSession = _imageMarkupSession;
    setState(() {
      _selectedMedia = mediaFile;
      _selectedMediaType = mediaType;
      _imageMarkupSession = null;
    });
    _disposeImageMarkupPreview(
      previousMarkupSession,
      preservedPaths: <String>{mediaFile.path},
    );
  }

  void _applyImageMarkupSession(DescriptionMediaImageMarkupSession session) {
    final previousMarkupSession = _imageMarkupSession;
    setState(() {
      _selectedMedia = session.displayImageFile;
      _selectedMediaType = 'image';
      _imageMarkupSession = session;
    });
    _disposeImageMarkupPreview(
      previousMarkupSession,
      preservedPaths: <String>{session.previewImageFile.path},
    );
  }

  File? _resolvedMediaFileForSave() {
    final selectedMediaType = _selectedMediaType?.trim().toLowerCase();
    if (selectedMediaType == 'image') {
      return _imageMarkupSession?.displayImageFile ?? _selectedMedia;
    }

    return _selectedMedia;
  }

  void _disposeImageMarkupPreview(
    DescriptionMediaImageMarkupSession? session, {
    Set<String> preservedPaths = const <String>{},
  }) {
    if (session == null) {
      return;
    }

    final previewPath = session.previewImageFile.path;
    if (previewPath.isEmpty ||
        previewPath == session.sourceImageFile.path ||
        preservedPaths.contains(previewPath)) {
      return;
    }

    unawaited(_deleteFileIfExists(previewPath));
  }

  Future<void> _deleteFileIfExists(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (error) {
      debugPrint('Unable to delete markup preview: $error');
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _ReusableCommentFieldLabel extends StatelessWidget {
  const _ReusableCommentFieldLabel();

  @override
  Widget build(BuildContext context) {
    return AppTextView.body2(
      AppStrings.comment,
      color: AppColors.textPrimary,
      fontWeight: FontWeight.w600,
      fontSize: 13,
    );
  }
}

class _ReusableCommentField extends StatelessWidget {
  const _ReusableCommentField({
    required this.controller,
    required this.enabled,
    required this.onChanged,
  });

  final TextEditingController controller;
  final bool enabled;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 104,
      child: TextField(
        controller: controller,
        maxLines: 4,
        minLines: 4,
        enabled: enabled,
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        cursorColor: AppColors.secondaryColor,
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: AppStrings.enterComment,
          hintStyle: TextStyle(
            color: AppColors.textSecondary.withValues(alpha: 0.7),
            fontSize: 14,
            fontWeight: FontWeight.w400,
          ),
          filled: true,
          fillColor: AppColors.fieldFill,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 12,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: AppColors.fieldBorder.withValues(alpha: 0.35),
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.secondaryColor),
          ),
          disabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: AppColors.grey1.withValues(alpha: 0.25),
            ),
          ),
        ),
      ),
    );
  }
}

class _ContentContainer extends StatelessWidget {
  const _ContentContainer({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surfaceDark3,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.grey2.withValues(alpha: 0.45)),
      ),
      child: child,
    );
  }
}

class _ActionStateView extends StatelessWidget {
  const _ActionStateView({
    required this.isBusy,
    required this.title,
    required this.subtitle,
    required this.buttonText,
    required this.onPressed,
  });

  final bool isBusy;
  final String title;
  final String subtitle;
  final String buttonText;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isBusy)
              SizedBox(
                width: 26,
                height: 26,
                child: FastCircularProgressIndicator(),
              )
            else ...[
              AppTextView.body1(
                title,
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              AppTextView.body2(
                subtitle,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
                fontSize: 13,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 18),
              AppButton(
                text: buttonText,
                onPressed: onPressed,
                minimumHeight: 44,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _UploadMediaContent extends StatelessWidget {
  const _UploadMediaContent({
    required this.isBusy,
    required this.onUploadPhoto,
    required this.onUploadVideo,
  });

  final bool isBusy;
  final VoidCallback? onUploadPhoto;
  final VoidCallback? onUploadVideo;

  @override
  Widget build(BuildContext context) {
    if (isBusy) {
      return Center(
        child: SizedBox(
          width: 26,
          height: 26,
          child: FastCircularProgressIndicator(),
        ),
      );
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppTextView.body1(
              AppStrings.auditUploadMedia,
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w700,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            AppTextView.body2(
              AppStrings.auditUploadMediaChoice,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
              fontSize: 13,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),
            AppButton(
              text: AppStrings.auditUploadPhoto,
              onPressed: onUploadPhoto,
              minimumHeight: 44,
            ),
            const SizedBox(height: 12),
            AppButton(
              text: AppStrings.auditUploadVideo,
              onPressed: onUploadVideo,
              minimumHeight: 44,
              backgroundColor: AppColors.surfaceDark,
              textColor: AppColors.textPrimary,
            ),
          ],
        ),
      ),
    );
  }
}

class _ScreenRecordingPreviewOnlyState extends StatelessWidget {
  const _ScreenRecordingPreviewOnlyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppTextView.body1(
              AppStrings.auditScreenRecordingPreview,
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w700,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            AppTextView.body2(
              AppStrings.auditScreenRecordingPreviewHint,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
              fontSize: 13,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _SelectedMediaPreview extends StatelessWidget {
  const _SelectedMediaPreview({
    required this.mediaFile,
    required this.mediaType,
    required this.onClear,
    this.onEditImage,
  });

  final File mediaFile;
  final String? mediaType;
  final VoidCallback? onClear;
  final VoidCallback? onEditImage;

  @override
  Widget build(BuildContext context) {
    final normalizedMediaType = mediaType?.trim().toLowerCase();
    final isVideo =
        normalizedMediaType == 'video' ||
        normalizedMediaType == 'screen_recording';

    return Stack(
      fit: StackFit.expand,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: isVideo
              ? _LocalVideoPreview(videoFile: mediaFile)
              : ColoredBox(
                  color: AppColors.surfaceDark1,
                  child: Image.file(
                    mediaFile,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.high,
                  ),
                ),
        ),
        if (onClear != null)
          Positioned(
            top: 10,
            right: 10,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onClear,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.45),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
            ),
          ),
        if (!isVideo && onEditImage != null)
          Positioned(
            left: 12,
            right: 12,
            bottom: 12,
            child: Align(
              alignment: Alignment.bottomLeft,
              child: FilledButton.icon(
                onPressed: onEditImage,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.secondaryColor,
                  foregroundColor: AppColors.textPrimary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  minimumSize: Size.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text(AppStrings.auditMarkupImage),
              ),
            ),
          ),
      ],
    );
  }
}

class _LocalVideoPreview extends StatefulWidget {
  const _LocalVideoPreview({required this.videoFile});

  final File videoFile;

  @override
  State<_LocalVideoPreview> createState() => _LocalVideoPreviewState();
}

class _LocalVideoPreviewState extends State<_LocalVideoPreview> {
  VideoPlayerController? _controller;
  Future<void>? _initializeFuture;

  @override
  void initState() {
    super.initState();
    _setupController();
  }

  @override
  void didUpdateWidget(covariant _LocalVideoPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoFile.path != widget.videoFile.path) {
      _disposeController();
      _setupController();
    }
  }

  @override
  void dispose() {
    _disposeController();
    super.dispose();
  }

  void _setupController() {
    final controller = VideoPlayerController.file(widget.videoFile);
    _controller = controller;
    _initializeFuture = controller
        .initialize()
        .then((_) async {
          await controller.setLooping(false);
          await controller.setVolume(0);
          if (mounted) {
            setState(() {});
          }
        })
        .catchError((error) {
          debugPrint('Unable to load recorded preview: $error');
          if (mounted) {
            setState(() {});
          }
        });
  }

  void _disposeController() {
    final controller = _controller;
    _controller = null;
    _initializeFuture = null;
    controller?.dispose();
  }

  Future<void> _togglePlayback() async {
    final controller = _controller;
    if (controller == null) {
      return;
    }

    if (!controller.value.isInitialized) {
      try {
        await _initializeFuture;
      } catch (_) {
        return;
      }
    }

    if (!controller.value.isInitialized) {
      return;
    }

    if (controller.value.isPlaying) {
      await controller.pause();
      if (mounted) {
        setState(() {});
      }
      return;
    }

    final duration = controller.value.duration;
    final position = controller.value.position;
    if (duration > Duration.zero && position >= duration) {
      await controller.seekTo(Duration.zero);
    }

    await controller.play();
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final initializeFuture = _initializeFuture;
    if (controller == null || initializeFuture == null) {
      return const _RecordedPreviewFallback();
    }

    return FutureBuilder<void>(
      future: initializeFuture,
      builder: (context, snapshot) {
        if (snapshot.hasError || !controller.value.isInitialized) {
          return const _RecordedPreviewFallback();
        }

        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _togglePlayback,
            child: Stack(
              fit: StackFit.expand,
              children: [
                FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: controller.value.size.width,
                    height: controller.value.size.height,
                    child: VideoPlayer(controller),
                  ),
                ),
                Container(
                  color: Colors.black.withValues(alpha: 0.18),
                  child: Center(
                    child: Icon(
                      controller.value.isPlaying
                          ? Icons.pause_circle_filled_rounded
                          : Icons.play_circle_fill_rounded,
                      color: Colors.white,
                      size: 42,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _RecordedPreviewFallback extends StatelessWidget {
  const _RecordedPreviewFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: const Center(
        child: Icon(Icons.videocam_rounded, color: Colors.white70, size: 42),
      ),
    );
  }
}
