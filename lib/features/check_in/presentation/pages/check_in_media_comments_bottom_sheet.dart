import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/utils/custom_functions.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_overlay_close_button.dart';
import '../../../../core/widgets/app_text_view.dart';
import '../../domain/entities/audit_description_audit.dart';
import '../providers/check_in_media_comments_controller.dart';
import '../widgets/check_in_media_comments_composer.dart';
import '../widgets/check_in_media_comments_dialogs.dart';
import '../widgets/check_in_media_comments_list.dart';
import '../widgets/check_in_media_comments_media.dart';

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
  State<CheckInMediaCommentsBottomSheet> createState() =>
      _CheckInMediaCommentsBottomSheetState();
}

class _CheckInMediaCommentsBottomSheetState
    extends State<CheckInMediaCommentsBottomSheet> {
  late CheckInMediaCommentsController _controller;
  ScrollController? _sheetScrollController;

  @override
  void initState() {
    super.initState();
    _initializeController();
  }

  void _initializeController() {
    _controller = CheckInMediaCommentsController(
      selectedMedia: widget.selectedMedia,
      onMediaChanged: widget.onMediaChanged,
      isReadOnly: widget.isReadOnly,
      canReply: widget.canReply,
      canDelete: widget.canDelete,
    )..addListener(_handleFeedback);
    unawaited(_controller.loadComments());
  }

  @override
  void didUpdateWidget(covariant CheckInMediaCommentsBottomSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.descriptionId != widget.descriptionId ||
        oldWidget.selectedMedia.uuid != widget.selectedMedia.uuid) {
      _disposeController();
      _initializeController();
      return;
    }
    _controller.updateConfiguration(
      isReadOnly: widget.isReadOnly,
      canReply: widget.canReply,
      canDelete: widget.canDelete,
      onMediaChanged: widget.onMediaChanged,
    );
    if (oldWidget.selectedMedia.media != widget.selectedMedia.media ||
        oldWidget.selectedMedia.type != widget.selectedMedia.type) {
      _controller.updateMedia(
        widget.selectedMedia.media,
        widget.selectedMedia.type,
      );
    }
  }

  void _disposeController() {
    _controller.removeListener(_handleFeedback);
    _controller.dispose();
  }

  @override
  void dispose() {
    _disposeController();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
          child: ListenableBuilder(
            listenable: _controller,
            builder: (context, _) =>
                _buildContents(_controller, scrollController),
          ),
        );
      },
    );
  }

  Widget _buildContents(
    CheckInMediaCommentsController controller,
    ScrollController scrollController,
  ) {
    final state = controller.state;
    return Column(
      children: [
        const _CommentsSheetHeader(),
        Expanded(child: _buildCommentsContent(controller, scrollController)),
        if (controller.canDelete)
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
            child: AppButton(
              text: AppStrings.auditDelete,
              onPressed: state.isDeleting ? null : _confirmDelete,
              isLoading: state.isDeleting,
              backgroundColor: AppColors.red,
              textColor: Colors.white,
            ),
          ),
        if (controller.canReply)
          CheckInMediaCommentsComposer(
            controller: controller.messageController,
            isReplying: state.isReplying,
            replyingLabel: controller.replyingLabel,
            isSending: state.isSendingComment,
            onSend: _sendComment,
            onCancelReply: controller.cancelReply,
          ),
      ],
    );
  }

  Widget _buildCommentsContent(
    CheckInMediaCommentsController controller,
    ScrollController scrollController,
  ) {
    final state = controller.state;
    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
      children: [
        Center(
          child: controller.hasSelectedMedia
              ? CheckInMediaCommentsPreview(
                  mediaUrl: state.mediaUrl,
                  mediaType: state.mediaType,
                )
              : controller.isReadOnly
              ? const CheckInMediaCommentsPlaceholder(width: 220, height: 220)
              : CheckInMediaCommentsUploadCard(
                  isUploading: state.isUploadingMedia,
                  onTap: controller.canUploadMedia
                      ? _selectAndUploadMedia
                      : null,
                ),
        ),
        const SizedBox(height: 18),
        CheckInMediaCommentsList(
          isLoading: state.isLoadingComments,
          errorMessage: state.commentsError,
          comments: controller.commentItems,
          canReply: controller.canReply,
          onReply: controller.startReply,
        ),
      ],
    );
  }

  Future<void> _sendComment() async {
    final controller = _controller;
    if (await controller.sendComment() && mounted) _scrollToLatestComment();
  }

  Future<void> _confirmDelete() async {
    final controller = _controller;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => const CheckInMediaDeleteDialog(),
    );
    if (confirmed != true || !mounted) return;
    if (await controller.deleteMedia() && mounted) Navigator.of(context).pop();
  }

  Future<void> _selectAndUploadMedia() async {
    final controller = _controller;
    if (!controller.canUploadMedia) return;
    final pickImage = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => const CheckInMediaUploadTypeSheet(),
    );
    if (mounted && pickImage != null) {
      await controller.pickAndUploadMedia(pickImage: pickImage);
    }
  }

  void _handleFeedback() {
    final feedback = _controller.takeFeedback();
    if (!mounted || feedback == null) return;
    if (feedback.showAlert) {
      CustomFunctions.showCustomAlert(
        context,
        AppStrings.auditMediaUploadErrorTitle,
        feedback.message,
      );
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(feedback.message)));
    }
  }

  void _scrollToLatestComment() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final controller = _sheetScrollController;
      if (!mounted || controller == null || !controller.hasClients) return;
      controller.animateTo(
        controller.position.maxScrollExtent,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    });
  }
}

class _CommentsSheetHeader extends StatelessWidget {
  const _CommentsSheetHeader();

  @override
  Widget build(BuildContext context) {
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
                  AppStrings.commentsSheetTitle,
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              AppOverlayCloseButton(onTap: () => Navigator.of(context).pop()),
            ],
          ),
        ),
      ],
    );
  }
}
