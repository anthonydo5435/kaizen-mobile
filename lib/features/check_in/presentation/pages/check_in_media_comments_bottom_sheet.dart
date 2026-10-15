import 'dart:async';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:sparrowkaizen/core/constants/app_strings.dart';
import 'package:sparrowkaizen/core/services/video_playback_service.dart';
import 'package:sparrowkaizen/core/widgets/fast_circular_progress.dart';
import 'package:video_player/video_player.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/preference/app_preference.dart';
import '../../../../core/utils/custom_functions.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_overlay_close_button.dart';
import '../../../../core/widgets/app_dialog_style.dart';
import '../../../../core/widgets/app_text_view.dart';
import '../../../compliance/presentation/pages/document/full_screen_doc.dart';
import '../../../compliance/presentation/pages/training/compliance_full_screen_video_view.dart';
import '../../data/datasources/audit_remote_data_source.dart';
import '../../domain/entities/audit_description_audit.dart';
import '../../domain/entities/description_comments_response.dart';
import '../providers/check_in_media_upload_controller.dart';

class CheckInMediaCommentsBottomSheet extends StatefulWidget {
  const CheckInMediaCommentsBottomSheet({
    super.key,
    required this.descriptionId,
    required this.selectedMedia,
    required this.mediaList,
    required this.onMediaChanged,
    this.isReadOnly = false,
    this.canReply = false,
    this.canDelete = false,
  });

  final String descriptionId;
  final AuditDescriptionMedia selectedMedia;
  final List<AuditDescriptionMedia> mediaList;
  final Future<void> Function() onMediaChanged;
  final bool isReadOnly;
  final bool canReply;
  final bool canDelete;

  @override
  State<CheckInMediaCommentsBottomSheet> createState() => _CheckInMediaCommentsBottomSheetState();
}

class _CheckInMediaCommentsBottomSheetState extends State<CheckInMediaCommentsBottomSheet> {
  static const int _maxUploadBytes = 80 * 1024 * 1024;
  static const Set<String> _allowedImageExtensions = {'jpg', 'jpeg', 'png'};
  static const Set<String> _allowedVideoExtensions = {'mp4', 'mov', 'h264'};

  final _remoteDataSource = AuditRemoteDataSource();
  final _imagePicker = ImagePicker();
  final _messageController = TextEditingController();
  final _viewState = ValueNotifier<_CheckInMediaCommentsViewState>(
    const _CheckInMediaCommentsViewState(),
  );
  ScrollController? _sheetScrollController;
  late String _currentMediaUrl;
  late String _currentMediaType;
  int _lastHandledAuditUploadEventSequence = 0;

  @override
  void initState() {
    super.initState();
    _currentMediaUrl = widget.selectedMedia.media;
    _currentMediaType = widget.selectedMedia.type;
    _lastHandledAuditUploadEventSequence =
        CheckInMediaUploadController.instance.latestTerminalEventSequence;
    CheckInMediaUploadController.instance.addListener(_handleAuditMediaUploadChanged);
    _viewState.value = _viewState.value.copyWith(
      isUploadingMedia: CheckInMediaUploadController.instance.isUploadActiveForAuditMedia(
        widget.selectedMedia.uuid,
      ),
    );
    _loadComments();
  }

  @override
  void dispose() {
    CheckInMediaUploadController.instance.removeListener(_handleAuditMediaUploadChanged);
    _viewState.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _loadComments() async {
    try {
      final response = await _remoteDataSource.getDescriptionComments(
        auditMediaId: widget.selectedMedia.uuid,
      );
      if (!mounted) {
        return;
      }

      _updateViewState(
        _viewState.value.copyWith(
          comments: response.comments,
          isLoadingComments: false,
          clearCommentsError: true,
        ),
      );
      _updateMediaState(response.media, response.type);
    } catch (_) {
      if (!mounted) {
        return;
      }

      _updateViewState(
        _viewState.value.copyWith(
          isLoadingComments: false,
          commentsError: 'Unable to load comments.',
        ),
      );
    }
  }

  Future<void> _loadCommentsSilently() async {
    try {
      final response = await _remoteDataSource.getDescriptionComments(
        auditMediaId: widget.selectedMedia.uuid,
      );
      if (!mounted) {
        return;
      }

      _updateViewState(
        _viewState.value.copyWith(comments: response.comments, clearCommentsError: true),
      );
      _updateMediaState(response.media, response.type);
    } catch (_) {
      if (!mounted) {
        return;
      }

      _updateViewState(_viewState.value.copyWith(commentsError: 'Unable to load comments.'));
    }
  }

  Future<void> _sendComment() async {
    final comment = _messageController.text.trim();
    final state = _viewState.value;
    if (comment.isEmpty || state.isSendingComment) {
      return;
    }

    final isReply = state.replyingTo != null;
    _updateViewState(state.copyWith(isSendingComment: true));
    try {
      final addedComment = await _remoteDataSource.addComment(
        auditMediaId: widget.selectedMedia.uuid,
        comment: comment,
        parent: state.replyingTo?.uuid,
      );
      if (!mounted) {
        return;
      }
      final updatedState = _viewState.value.copyWith(
        isSendingComment: false,
        isReplying: false,
        clearReplyingTo: true,
        comments: isReply
            ? _viewState.value.comments
            : [..._viewState.value.comments, addedComment],
      );
      _updateViewState(updatedState);
      _messageController.clear();
      if (isReply) {
        await _loadCommentsSilently();
        _scrollToLatestComment();
        return;
      }
      _scrollToLatestComment();
    } catch (_) {
      if (!mounted) {
        return;
      }
      _updateViewState(_viewState.value.copyWith(isSendingComment: false));
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasSelectedMedia = _hasSelectedMedia(
      mediaUrl: _currentMediaUrl,
      mediaType: _currentMediaType,
    );

    return DraggableScrollableSheet(
      initialChildSize: 0.86,
      minChildSize: 0.52,
      maxChildSize: 0.94,
      shouldCloseOnMinExtent: false,
      builder: (context, scrollController) {
        _sheetScrollController = scrollController;

        return Container(
          decoration: const BoxDecoration(
            color: AppColors.surfaceDark,
            borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
          ),
          child: ValueListenableBuilder<_CheckInMediaCommentsViewState>(
            valueListenable: _viewState,
            builder: (context, state, _) {
              return Column(
                children: [
                  const SizedBox(height: 10),
                  Container(
                    width: 46,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 8, 8, 8),
                    child: Row(
                      children: [
                        const Expanded(
                          child: AppTextView.body1(
                            'Comments',
                            color: AppColors.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        AppOverlayCloseButton(onTap: () => Navigator.of(context).pop()),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
                      children: [
                        Center(
                          child: hasSelectedMedia
                              ? _SheetMedia(
                                  mediaUrl: _currentMediaUrl,
                                  mediaType: _currentMediaType,
                                )
                              : widget.isReadOnly
                              ? const _SheetMediaPlaceholder(width: 220, height: 220)
                              : _EmptyMediaUploadCard(
                                  isUploading: state.isUploadingMedia,
                                  onTap: state.isUploadingMedia ? null : _selectAndUploadMedia,
                                ),
                        ),
                        const SizedBox(height: 18),
                        _CommentsList(
                          isLoading: state.isLoadingComments,
                          errorMessage: state.commentsError,
                          comments: state.comments,
                          canReply: widget.canReply,
                          onReply: (comment) {
                            _updateViewState(state.copyWith(isReplying: true, replyingTo: comment));
                          },
                        ),
                      ],
                    ),
                  ),
                  if (widget.canDelete) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
                      child: AppButton(
                        text: 'Delete',
                        onPressed: state.isDeleting ? null : _confirmDelete,
                        isLoading: state.isDeleting,
                        backgroundColor: AppColors.red,
                        textColor: Colors.white,
                      ),
                    ),
                  ],
                  if (widget.canReply)
                    _SendMessageBar(
                      controller: _messageController,
                      isReplying: state.isReplying,
                      replyingTo: state.replyingTo,
                      isSending: state.isSendingComment,
                      onSend: _sendComment,
                      onCancelReply: () {
                        _updateViewState(state.copyWith(isReplying: false, clearReplyingTo: true));
                      },
                    ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  bool _hasSelectedMedia({required String mediaUrl, required String mediaType}) {
    final normalizedType = mediaType.trim().toLowerCase();
    if (normalizedType != 'image' &&
        normalizedType != 'video' &&
        normalizedType != 'screen_recording') {
      return false;
    }

    return mediaUrl.trim().isNotEmpty;
  }

  Future<void> _confirmDelete() async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surfaceDark,
              borderRadius: BorderRadius.circular(12),
              border: AppDialogStyle.border,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AppTextView.body1(
                  'Are you sure you want to Delete?',
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
                const SizedBox(height: 10),
                const AppTextView.body2(
                  'This media and the comments will not be able to recover after deletion',
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: AppButton(
                        text: 'No',
                        onPressed: () => Navigator.of(dialogContext).pop(false),
                        backgroundColor: AppColors.surfaceDark3,
                        textColor: AppColors.textPrimary,
                        borderRadius: 12,
                        minimumHeight: 42,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AppButton(
                        text: 'Yes',
                        onPressed: () => Navigator.of(dialogContext).pop(true),
                        backgroundColor: AppColors.hexc62828,
                        textColor: Colors.white,
                        borderRadius: 12,
                        minimumHeight: 42,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    if (shouldDelete != true || _viewState.value.isDeleting) {
      return;
    }

    _updateViewState(_viewState.value.copyWith(isDeleting: true));
    try {
      await _remoteDataSource.deleteAuditMedia(auditMediaId: widget.selectedMedia.uuid);
      await widget.onMediaChanged();
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (error) {
      debugPrint('Unable to delete audit media: $error');
      if (mounted) {
        _updateViewState(_viewState.value.copyWith(isDeleting: false));
      }
    }
  }

  Future<void> _selectAndUploadMedia() async {
    final state = _viewState.value;
    if (state.isUploadingMedia || state.isDeleting) {
      return;
    }

    final selectedMedia = await _pickUploadMediaFile();
    if (!mounted || selectedMedia == null) {
      return;
    }

    await _uploadSelectedMedia(selectedMedia);
  }

  Future<_SelectedUploadMedia?> _pickUploadMediaFile() async {
    final shouldPickImage = await _showMediaTypePicker();
    if (!mounted || shouldPickImage == null) {
      return null;
    }

    try {
      final pickedFile = shouldPickImage
          ? await _imagePicker.pickImage(source: ImageSource.gallery, imageQuality: 90)
          : await _imagePicker.pickVideo(source: ImageSource.gallery);
      if (!mounted || pickedFile == null) {
        return null;
      }

      final mediaFile = File(pickedFile.path);
      final fileSize = await mediaFile.length();
      if (fileSize > _maxUploadBytes) {
        _showSnackBar('Max file size is 80 MB.');
        return null;
      }

      final extension = CustomFunctions.fileNameFromPath(
        mediaFile.path,
      ).split('.').last.trim().toLowerCase();

      final isImage = _allowedImageExtensions.contains(extension);
      final isVideo = _allowedVideoExtensions.contains(extension);
      if (!isImage && !isVideo) {
        _showSnackBar('Only JPG, PNG, MP4, MOV, and H264 files are supported.');
        return null;
      }

      return _SelectedUploadMedia(file: mediaFile, mediaType: isImage ? 'image' : 'video');
    } catch (error) {
      debugPrint('Unable to pick audit media file: $error');
      if (mounted) {
        _showSnackBar('Unable to pick a media file right now. Please try again.');
      }
      return null;
    }
  }

  Future<bool?> _showMediaTypePicker() {
    return showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.surfaceDark,
            borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
          ),
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AppTextView.body1(
                  'Select upload type',
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
                const SizedBox(height: 14),
                _MediaSelectionOption(
                  icon: Icons.image_outlined,
                  title: 'Image',
                  subtitle: 'JPG or PNG',
                  onTap: () => Navigator.of(context).pop(true),
                ),
                const SizedBox(height: 10),
                _MediaSelectionOption(
                  icon: Icons.videocam_outlined,
                  title: 'Video',
                  subtitle: 'MP4, MOV, or H264',
                  onTap: () => Navigator.of(context).pop(false),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _uploadSelectedMedia(_SelectedUploadMedia selectedMedia) async {
    if (selectedMedia.mediaType == 'video') {
      await _enqueueSelectedVideoUpload(selectedMedia);
      return;
    }

    _updateViewState(_viewState.value.copyWith(isUploadingMedia: true));
    try {
      final mediaFile = selectedMedia.file;
      final fileName = CustomFunctions.fileNameFromPath(mediaFile.path);
      final uploadUrl = await _remoteDataSource.generateAuditDescriptionMediaUploadUrl(
        fileName: fileName,
      );

      await _remoteDataSource.uploadAuditDescriptionMediaFile(
        uploadUrl: uploadUrl,
        fileName: fileName,
        fileBytes: await mediaFile.readAsBytes(),
        contentType: CustomFunctions.contentTypeFromPath(mediaFile.path),
      );

      final querySeparatorIndex = uploadUrl.indexOf('?');
      final mediaUrl = querySeparatorIndex == -1
          ? uploadUrl
          : uploadUrl.substring(0, querySeparatorIndex);

      await _remoteDataSource.updateAuditMedia(
        auditMediaId: widget.selectedMedia.uuid,
        mediaUrl: mediaUrl,
        mediaType: selectedMedia.mediaType,
      );
      _updateMediaState(mediaUrl, selectedMedia.mediaType);
      await widget.onMediaChanged();
      if (!mounted) {
        return;
      }
      _updateViewState(_viewState.value.copyWith(isUploadingMedia: false));
    } catch (error) {
      debugPrint('Unable to upload audit media file: $error');
      if (mounted) {
        _updateViewState(_viewState.value.copyWith(isUploadingMedia: false));
        CustomFunctions.showCustomAlert(
          context,
          'Failed',
          'File failed to upload!, Try again later!',
        );
      }
    }
  }

  Future<void> _enqueueSelectedVideoUpload(_SelectedUploadMedia selectedMedia) async {
    _updateViewState(_viewState.value.copyWith(isUploadingMedia: true));
    final didStart = await CheckInMediaUploadController.instance.startUploadForAuditMediaAttachment(
      auditMediaId: widget.selectedMedia.uuid,
      sourceFile: selectedMedia.file,
      mediaType: selectedMedia.mediaType,
    );
    if (didStart) {
      return;
    }

    _updateViewState(_viewState.value.copyWith(isUploadingMedia: false));
    final message = CheckInMediaUploadController.instance.startErrorMessage?.trim();
    if (message != null && message.isNotEmpty) {
      _showSnackBar(message);
      return;
    }

    _showSnackBar(AppStrings.auditMediaUploadFailed);
  }

  void _handleAuditMediaUploadChanged() {
    unawaited(_syncAuditMediaUploadState());
  }

  Future<void> _syncAuditMediaUploadState() async {
    if (!mounted) {
      return;
    }

    final isUploadingMedia = CheckInMediaUploadController.instance.isUploadActiveForAuditMedia(
      widget.selectedMedia.uuid,
    );
    if (_viewState.value.isUploadingMedia != isUploadingMedia) {
      _updateViewState(_viewState.value.copyWith(isUploadingMedia: isUploadingMedia));
    }

    final terminalTasks = CheckInMediaUploadController.instance.terminalTasksSince(
      _lastHandledAuditUploadEventSequence,
    );
    if (terminalTasks.isEmpty) {
      return;
    }

    _lastHandledAuditUploadEventSequence = terminalTasks.last.terminalEventSequence;
    CheckInMediaUploadResult? completedResult;
    String? failureMessage;
    for (final task in terminalTasks) {
      if (task.flow != CheckInMediaUploadFlow.mediaAttachment ||
          task.auditMediaId != widget.selectedMedia.uuid) {
        continue;
      }

      if (task.isCompleted) {
        completedResult ??= task.resultPayload;
        continue;
      }

      if (task.isFailed && failureMessage == null) {
        final message = task.errorMessage?.trim();
        if (message != null && message.isNotEmpty) {
          failureMessage = message;
        }
      }
    }

    if (completedResult != null) {
      _updateMediaState(completedResult.mediaUrl, completedResult.mediaType);
      await widget.onMediaChanged();
      await _loadCommentsSilently();
    }

    if (failureMessage != null) {
      _showSnackBar(failureMessage);
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  void _updateViewState(_CheckInMediaCommentsViewState nextState) {
    if (!mounted) {
      return;
    }

    _viewState.value = nextState;
  }

  void _updateMediaState(String mediaUrl, String mediaType) {
    if (!mounted) {
      return;
    }

    setState(() {
      _currentMediaUrl = mediaUrl;
      _currentMediaType = mediaType;
    });
  }

  void _scrollToLatestComment() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final controller = _sheetScrollController;
      if (!mounted || controller == null || !controller.hasClients) {
        return;
      }

      controller.animateTo(
        controller.position.maxScrollExtent,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    });
  }
}

class _CheckInMediaCommentsViewState {
  const _CheckInMediaCommentsViewState({
    this.comments = const <DescriptionComment>[],
    this.isLoadingComments = true,
    this.isSendingComment = false,
    this.isUploadingMedia = false,
    this.isDeleting = false,
    this.isReplying = false,
    this.commentsError,
    this.replyingTo,
  });

  final List<DescriptionComment> comments;
  final bool isLoadingComments;
  final bool isSendingComment;
  final bool isUploadingMedia;
  final bool isDeleting;
  final bool isReplying;
  final String? commentsError;
  final DescriptionComment? replyingTo;

  _CheckInMediaCommentsViewState copyWith({
    List<DescriptionComment>? comments,
    bool? isLoadingComments,
    bool? isSendingComment,
    bool? isUploadingMedia,
    bool? isDeleting,
    bool? isReplying,
    String? commentsError,
    DescriptionComment? replyingTo,
    bool clearCommentsError = false,
    bool clearReplyingTo = false,
  }) {
    return _CheckInMediaCommentsViewState(
      comments: comments ?? this.comments,
      isLoadingComments: isLoadingComments ?? this.isLoadingComments,
      isSendingComment: isSendingComment ?? this.isSendingComment,
      isUploadingMedia: isUploadingMedia ?? this.isUploadingMedia,
      isDeleting: isDeleting ?? this.isDeleting,
      isReplying: isReplying ?? this.isReplying,
      commentsError: clearCommentsError ? null : commentsError ?? this.commentsError,
      replyingTo: clearReplyingTo ? null : replyingTo ?? this.replyingTo,
    );
  }
}

class _SelectedUploadMedia {
  const _SelectedUploadMedia({required this.file, required this.mediaType});

  final File file;
  final String mediaType;
}

class _MediaSelectionOption extends StatelessWidget {
  const _MediaSelectionOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surfaceDark3,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.grey2.withValues(alpha: 0.4)),
          ),
          child: Row(
            children: [
              Icon(icon, color: AppColors.lightPurple1, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppTextView.body2(
                      title,
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                    const SizedBox(height: 3),
                    AppTextView.body2(
                      subtitle,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                      fontSize: 12,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyMediaUploadCard extends StatelessWidget {
  const _EmptyMediaUploadCard({required this.isUploading, required this.onTap});

  final bool isUploading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final previewWidth = width > 560 ? 440.0 : width * 0.82;

    return Container(
      width: previewWidth,
      constraints: const BoxConstraints(minHeight: 220),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: CustomPaint(
            painter: const _DashedBorderPainter(color: AppColors.hex9b9ead, radius: 18),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.mainBg,
                borderRadius: BorderRadius.circular(18),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 76,
                      height: 76,
                      decoration: const BoxDecoration(
                        color: AppColors.lightPurple1,
                        shape: BoxShape.circle,
                      ),
                      child: isUploading
                          ? Padding(
                              padding: EdgeInsets.all(22),
                              child: FastCircularProgressIndicator(),
                            )
                          : const Icon(Icons.file_upload_outlined, color: Colors.white, size: 34),
                    ),
                    const SizedBox(height: 20),
                    AppTextView.body1(
                      isUploading ? 'Uploading media...' : 'Click to upload',
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 10),
                    AppTextView.body2(
                      'File Format: JPG, PNG, MP4, MOV, H264',
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                      fontSize: 13,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    AppTextView.body2(
                      'Max file size is 80 MB',
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                      fontSize: 13,
                      textAlign: TextAlign.center,
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

class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({required this.color, required this.radius});

  final Color color;
  final double radius;
  static const double _strokeWidth = 1.2;
  static const double _dashWidth = 7;
  static const double _dashSpace = 5;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(radius));
    final path = Path()..addRRect(rrect);
    final dashedPath = Path();

    for (final metric in path.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        final nextDistance = distance + _dashWidth;
        dashedPath.addPath(
          metric.extractPath(distance, nextDistance.clamp(0, metric.length)),
          Offset.zero,
        );
        distance += _dashWidth + _dashSpace;
      }
    }

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = _strokeWidth;
    canvas.drawPath(dashedPath, paint);
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.radius != radius;
  }
}

class _SheetMedia extends StatelessWidget {
  const _SheetMedia({required this.mediaUrl, required this.mediaType});

  final String mediaUrl;
  final String? mediaType;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final previewWidth = width > 560 ? 440.0 : width * 0.82;
    final normalizedType = mediaType?.trim().toLowerCase();

    return switch (normalizedType) {
      'video' ||
      'screen_recording' => _SheetVideoPlayer(mediaUrl: mediaUrl, width: previewWidth, height: 220),
      'image' => _SheetCachedImage(mediaUrl: mediaUrl, width: previewWidth, height: 220),
      _ => _SheetMediaPlaceholder(width: previewWidth, height: 220),
    };
  }
}

class _SheetCachedImage extends StatelessWidget {
  const _SheetCachedImage({required this.mediaUrl, required this.width, required this.height});

  final String mediaUrl;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final imageUrl = CustomFunctions.resolveImageUrl(mediaUrl);

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: width,
        height: height,
        child: imageUrl == null
            ? const _SheetMediaPlaceholder()
            : InkWell(
                onTap: () => Navigator.of(context).push<void>(
                  MaterialPageRoute(
                    builder: (_) => ViewFullScreenDoc(title: 'Image', imageUrl: imageUrl),
                  ),
                ),
                child: CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.contain,
                  placeholder: (_, __) => const _SheetMediaPlaceholder(),
                  errorWidget: (_, __, ___) => const _SheetMediaPlaceholder(),
                ),
              ),
      ),
    );
  }
}

class _SheetVideoPlayer extends StatefulWidget {
  const _SheetVideoPlayer({required this.mediaUrl, required this.width, required this.height});

  final String mediaUrl;
  final double width;
  final double height;

  @override
  State<_SheetVideoPlayer> createState() => _SheetVideoPlayerState();
}

class _SheetVideoPlayerState extends State<_SheetVideoPlayer> {
  VideoPlayerController? _controller;
  Future<void>? _initializeFuture;
  Object? _initializationError;
  int _initializationGeneration = 0;

  @override
  void initState() {
    super.initState();
    _setupController();
  }

  @override
  void didUpdateWidget(covariant _SheetVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mediaUrl != widget.mediaUrl) {
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
    _initializationError = null;
    final generation = ++_initializationGeneration;
    _initializeFuture = _initializeController(generation);
  }

  Future<void> _initializeController(int generation) async {
    final resolvedVideoUrl = CustomFunctions.resolveNetworkUrl(widget.mediaUrl);
    if (resolvedVideoUrl == null) {
      _initializationError = ArgumentError('Invalid video URL');
      throw _initializationError!;
    }

    final headers = _buildVideoHeaders(resolvedVideoUrl);
    VideoPlayerController? controller;
    controller = await VideoPlaybackService.acquireInitializedController(
      widget.mediaUrl,
      headers: headers,
    );
    if (controller == null) {
      _initializationError = ArgumentError('Unable to resolve video source');
      throw _initializationError!;
    }

    try {
      if (!mounted || !_isActiveGeneration(generation)) {
        await VideoPlaybackService.releaseController(controller);
        return;
      }

      await controller.setLooping(false);
      await controller.setVolume(1);
      if (!mounted || !_isActiveGeneration(generation)) {
        await VideoPlaybackService.releaseController(controller);
        return;
      }
      _controller = controller;
      if (mounted) {
        setState(() {});
      }
    } catch (error) {
      debugPrint('Audit video initialization failed for $resolvedVideoUrl: $error');
      _initializationError = error;
      await VideoPlaybackService.releaseController(controller);
      if (mounted) {
        setState(() {});
      }
      rethrow;
    }
  }

  bool _isActiveGeneration(int generation) {
    return generation == _initializationGeneration;
  }

  Map<String, String> _buildVideoHeaders(String resolvedVideoUrl) {
    final authToken = AppPreference.getAuthToken().trim();
    if (authToken.isEmpty) {
      return const <String, String>{};
    }

    final apiHost = Uri.tryParse(ApiEndPoints.baseUrl)?.host;
    final mediaHost = Uri.tryParse(resolvedVideoUrl)?.host;
    if (apiHost == null || mediaHost == null || apiHost != mediaHost) {
      return const <String, String>{};
    }

    return <String, String>{'Authorization': 'Bearer $authToken'};
  }

  void _disposeController() {
    _initializationGeneration++;
    final controller = _controller;
    _controller = null;
    _initializeFuture = null;
    _initializationError = null;
    if (controller != null) {
      unawaited(VideoPlaybackService.releaseController(controller));
    }
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
      return;
    }

    final position = controller.value.position;
    final duration = controller.value.duration;
    if (duration > Duration.zero && position >= duration) {
      await controller.seekTo(Duration.zero);
    }

    unawaited(VideoPlaybackService.prepareAudiblePlaybackAudioSession());
    await controller.play();
  }

  Future<void> _openFullScreenVideo() async {
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

    if (!mounted || !controller.value.isInitialized) {
      return;
    }

    final initialPosition = controller.value.position;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => ComplianceFullScreenVideoView(
          controller: controller,
          title: '',
          initialPosition: initialPosition,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _initializeFuture,
      builder: (context, snapshot) {
        final controller = _controller;
        if (controller == null) {
          return _buildPlayerContent(snapshot: snapshot, controller: null, controllerValue: null);
        }

        return ValueListenableBuilder<VideoPlayerValue>(
          valueListenable: controller,
          builder: (context, controllerValue, child) {
            return _buildPlayerContent(
              snapshot: snapshot,
              controller: controller,
              controllerValue: controllerValue,
            );
          },
        );
      },
    );
  }

  Widget _buildPlayerContent({
    required AsyncSnapshot<void> snapshot,
    required VideoPlayerController? controller,
    required VideoPlayerValue? controllerValue,
  }) {
    final initializationError = _initializationError ?? snapshot.error;
    final isReady =
        controller != null && controllerValue?.isInitialized == true && initializationError == null;
    final isBuffering = isReady && (controllerValue?.isBuffering ?? false);

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: widget.width,
        height: widget.height,
        color: Colors.black,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (isReady)
              FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: controllerValue!.size.width,
                  height: controllerValue.size.height,
                  child: VideoPlayer(controller),
                ),
              )
            else
              const SizedBox(),

            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.08),
                    Colors.black.withValues(alpha: 0.32),
                  ],
                ),
              ),
            ),
            if (isReady)
              Positioned(
                top: 12,
                right: 12,
                child: InkWell(
                  onTap: _openFullScreenVideo,
                  borderRadius: BorderRadius.circular(18),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.58),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                    ),
                    child: const Icon(Icons.open_in_full_rounded, color: Colors.white, size: 18),
                  ),
                ),
              ),
            if (isReady && isBuffering)
              Center(
                child: SizedBox(width: 26, height: 26, child: FastCircularProgressIndicator()),
              ),
            if (initializationError != null)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24),
                  child: AppTextView.body(
                    'Video could not be loaded.',
                    color: AppColors.textPrimary,
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            else if (isReady)
              Positioned(
                left: 12,
                right: 12,
                bottom: 12,
                child: Row(
                  children: [
                    InkWell(
                      onTap: _togglePlayback,
                      borderRadius: BorderRadius.circular(22),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.58),
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              controllerValue!.isPlaying
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                            const SizedBox(width: 6),
                            AppTextView.body2(
                              controllerValue.isPlaying ? 'Pause' : 'Play',
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
              Center(
                child: InkWell(
                  onTap: isReady ? _togglePlayback : null,
                  borderRadius: BorderRadius.circular(30),
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.42),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: snapshot.connectionState != ConnectionState.done
                        ? SizedBox(width: 24, height: 24, child: FastCircularProgressIndicator())
                        : Icon(
                            controllerValue?.isPlaying ?? false
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                            color: Colors.white,
                            size: 32,
                          ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SheetMediaPlaceholder extends StatelessWidget {
  const _SheetMediaPlaceholder({this.width, this.height});

  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: Image.asset('${AppStrings.imagePath}no_image.png', fit: BoxFit.cover),
    );
  }
}

class _CommentsList extends StatelessWidget {
  const _CommentsList({
    required this.isLoading,
    required this.errorMessage,
    required this.comments,
    required this.canReply,
    required this.onReply,
  });

  final bool isLoading;
  final String? errorMessage;
  final List<DescriptionComment> comments;
  final bool canReply;
  final ValueChanged<DescriptionComment> onReply;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: 18),
        child: Center(
          child: SizedBox(width: 26, height: 26, child: FastCircularProgressIndicator()),
        ),
      );
    }

    if (errorMessage != null) {
      return AppTextView.body2(
        errorMessage!,
        color: AppColors.textSecondary,
        fontWeight: FontWeight.w400,
        fontSize: 12,
      );
    }

    if (comments.isEmpty) {
      return const AppTextView.body2(
        'No comments available.',
        color: AppColors.textSecondary,
        fontWeight: FontWeight.w400,
        fontSize: 12,
      );
    }

    return Column(
      children: [
        for (var index = 0; index < comments.length; index++) ...[
          _CommentCard(
            comment: comments[index],
            canReply: canReply,
            onReply: () => onReply(comments[index]),
          ),
          if (index != comments.length - 1) const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _CommentCard extends StatefulWidget {
  const _CommentCard({required this.comment, required this.canReply, required this.onReply});

  final DescriptionComment comment;
  final bool canReply;
  final VoidCallback onReply;

  @override
  State<_CommentCard> createState() => _CommentCardState();
}

class _CommentCardState extends State<_CommentCard> {
  var _showReplies = false;

  @override
  Widget build(BuildContext context) {
    final author = widget.comment.author;
    final authorName = CustomFunctions.displayCommentAuthorName(
      name: author?.name,
      email: author?.email,
    );
    final repliesCount = widget.comment.replies.length;

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark3,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.grey2.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ProfileAvatar(imageUrl: author?.image),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: AppTextView.body2(
                        authorName,
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    AppTextView.body4(
                      CustomFunctions.formatCommentTimeAgo(widget.comment.createdAt),
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                AppTextView.body2(
                  CustomFunctions.displayCommentText(widget.comment.comment),
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w500,
                  fontSize: 12,
                ),
                const SizedBox(height: 3),
                if (widget.canReply) _ReplyAction(onTap: widget.onReply),
                if (repliesCount > 0) ...[
                  const SizedBox(height: 6),
                  _RepliesToggle(
                    repliesCount: repliesCount,
                    isExpanded: _showReplies,
                    onTap: () {
                      setState(() => _showReplies = !_showReplies);
                    },
                  ),
                ],
                if (_showReplies && widget.comment.replies.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _RepliesList(replies: widget.comment.replies),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RepliesList extends StatelessWidget {
  const _RepliesList({required this.replies});

  final List<DescriptionComment> replies;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 2,
            margin: const EdgeInsets.only(left: 6, right: 12, top: 4, bottom: 4),
            decoration: BoxDecoration(
              color: AppColors.grey2.withValues(alpha: 0.75),
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          Expanded(
            child: Column(
              children: [
                for (var index = 0; index < replies.length; index++) ...[
                  _ReplyComment(comment: replies[index]),
                  if (index != replies.length - 1) const SizedBox(height: 10),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RepliesToggle extends StatelessWidget {
  const _RepliesToggle({required this.repliesCount, required this.isExpanded, required this.onTap});

  final int repliesCount;
  final bool isExpanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: AppTextView.body4(
          isExpanded ? 'Hide all replies' : 'Show all replies ($repliesCount)',
          color: AppColors.secondaryColor,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _ReplyComment extends StatelessWidget {
  const _ReplyComment({required this.comment});

  final DescriptionComment comment;

  @override
  Widget build(BuildContext context) {
    final author = comment.author;
    final authorName = CustomFunctions.displayCommentAuthorName(
      name: author?.name,
      email: author?.email,
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ProfileAvatar(imageUrl: author?.image, size: 30),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: AppTextView.body3(
                      authorName,
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  AppTextView.body4(
                    CustomFunctions.formatCommentTimeAgo(comment.createdAt),
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ],
              ),
              const SizedBox(height: 3),
              AppTextView.body3(
                CustomFunctions.displayCommentText(comment.comment),
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w500,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({required this.imageUrl, this.size = 38});

  final String? imageUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    final resolvedImageUrl = CustomFunctions.resolveImageUrl(imageUrl);

    return ClipOval(
      child: SizedBox(
        width: size,
        height: size,
        child: resolvedImageUrl == null
            ? Image.asset('lib/assets/images/dumy_pic.png', fit: BoxFit.cover)
            : Image.network(
                resolvedImageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) {
                  return Image.asset('lib/assets/images/dumy_pic.png', fit: BoxFit.cover);
                },
              ),
      ),
    );
  }
}

class _ReplyAction extends StatelessWidget {
  const _ReplyAction({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.reply, color: AppColors.secondaryColor, size: 16),
          SizedBox(width: 4),
          AppTextView.body4('Reply', color: AppColors.secondaryColor, fontWeight: FontWeight.w600),
        ],
      ),
    );
  }
}

class _SendMessageBar extends StatelessWidget {
  const _SendMessageBar({
    required this.controller,
    required this.isReplying,
    required this.replyingTo,
    required this.isSending,
    required this.onSend,
    required this.onCancelReply,
  });

  final TextEditingController controller;
  final bool isReplying;
  final DescriptionComment? replyingTo;
  final bool isSending;
  final VoidCallback onSend;
  final VoidCallback onCancelReply;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
        decoration: BoxDecoration(
          color: AppColors.surfaceDark,
          border: Border(top: BorderSide(color: AppColors.grey2.withValues(alpha: 0.45))),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isReplying) ...[
              Row(
                children: [
                  Expanded(
                    child: AppTextView.body3(
                      _replyingLabel,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  InkWell(
                    onTap: onCancelReply,
                    borderRadius: BorderRadius.circular(12),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                      child: AppTextView.body3(
                        'Cancel',
                        color: AppColors.secondaryColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 50,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: AppColors.mainBg,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: AppColors.fieldBorder.withValues(alpha: 0.75)),
                    ),
                    child: TextField(
                      controller: controller,
                      cursorColor: AppColors.textPrimary,
                      cursorHeight: 16,
                      style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: isReplying ? 'Reply' : 'Send message',
                        hintStyle: const TextStyle(
                          color: AppColors.grey1,
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                        ),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Material(
                  color: AppColors.secondaryColor,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: isSending ? null : onSend,
                    child: SizedBox(
                      width: 44,
                      height: 44,
                      child: isSending
                          ? Padding(
                              padding: EdgeInsets.all(10),
                              child: FastCircularProgressIndicator(),
                            )
                          : Icon(Icons.send_rounded, color: AppColors.textPrimary, size: 20),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String get _replyingLabel {
    final author = replyingTo?.author;
    final name = author?.name.trim();
    if (name != null && name.isNotEmpty) {
      return 'Replying to $name';
    }

    return 'Replying to Comment';
  }
}
