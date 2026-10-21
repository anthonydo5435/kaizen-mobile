part of '../pages/check_in_single_description.dart';

class _CommentsCard extends StatefulWidget {
  const _CommentsCard({
    required this.controller,
    required this.onCommentsSheetClosed,
  });

  final CheckInSingleDescriptionController controller;
  final VoidCallback onCommentsSheetClosed;

  @override
  State<_CommentsCard> createState() => _CommentsCardState();
}

class _CommentsCardState extends State<_CommentsCard> {
  late final ValueNotifier<bool> _isExpandedNotifier = ValueNotifier<bool>(
    false,
  );

  @override
  void dispose() {
    _isExpandedNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final comments = controller.comments;
    return ValueListenableBuilder<bool>(
      valueListenable: _isExpandedNotifier,
      builder: (context, isExpanded, _) {
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          decoration: BoxDecoration(
            color: AppColors.surfaceDark,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: AppTextView.body(
                      AppStrings.comments,
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (controller.canCreateComments) ...[
                    _CommentIconButton(
                      isEnabled: controller.hasLoadedAudit,
                      icon: Icons.camera_alt_outlined,
                      onTap: controller.hasLoadedAudit
                          ? () => _openCreateCommentDialog()
                          : null,
                    ),
                  ],
                ],
              ),
              if (controller.isLoading) ...[
                const SizedBox(height: 12),
                Center(
                  child: SizedBox(
                    width: 26,
                    height: 26,
                    child: FastCircularProgressIndicator(),
                  ),
                ),
              ] else if (controller.hasLoadError) ...[
                const SizedBox(height: 12),
                AppTextView.body2(
                  AppStrings.unableToLoadComments,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w400,
                  fontSize: 12,
                ),
              ] else if (comments.isEmpty) ...[
                const SizedBox(height: 12),
                AppTextView.body2(
                  AppStrings.noCommentsAvailable,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w400,
                  fontSize: 12,
                ),
              ] else ...[
                if (isExpanded) ...[
                  const SizedBox(height: 12),
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: comments.length,
                    padding: EdgeInsets.zero,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      return _CommentMediaCard(
                        descriptionId: controller.description.uuid,
                        comment: comments[index],
                        mediaList: controller.media,
                        isReadOnly: !controller.canManageComments,
                        canReply: controller.canCreateComments,
                        canDelete: controller.canCreateComments,
                        onCommentsChanged: controller.refreshComments,
                        onSheetClosed: widget.onCommentsSheetClosed,
                      );
                    },
                  ),
                ],
                const SizedBox(height: 12),
                InkWell(
                  onTap: () {
                    _isExpandedNotifier.value = !isExpanded;
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AppTextView.body2(
                        isExpanded
                            ? AppStrings.auditHideComments
                            : AppStrings.auditExpandComments,
                        color: AppColors.lightPurple1,
                        fontWeight: FontWeight.w500,
                        fontSize: 12,
                      ),
                      Icon(
                        isExpanded
                            ? Icons.arrow_drop_up
                            : Icons.arrow_drop_down,
                        size: 20,
                        color: AppColors.textPrimary,
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Future<void> _openCreateCommentDialog() async {
    await _showMediaTypeSelectionSheet();
  }

  Future<bool> _openSelectedMediaCommentDialog(
    DescriptionMediaCommentContentType selectedType,
  ) async {
    if (selectedType == DescriptionMediaCommentContentType.screenRecording) {
      return _openScreenRecordingCommentDialog();
    }

    final didSave = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return DescriptionMediaCommentBottomSheet(
          contentType: selectedType,
          onSave: (comment, mediaFile, mediaType) =>
              widget.controller.saveMediaComment(comment, mediaFile, mediaType),
        );
      },
    );

    return didSave ?? false;
  }

  Future<bool> _openTextOnlyCommentDialog() async {
    final didSave = await showDialog<bool>(
      context: context,
      builder: (_) => DescriptionTextCommentDialog(
        onSave: widget.controller.saveTextComment,
      ),
    );

    return didSave ?? false;
  }

  Future<bool> _openScreenRecordingCommentDialog() async {
    final recordedMedia = await Navigator.of(context).push<File?>(
      MaterialPageRoute(
        builder: (_) => const CheckInScreenRecordingCaptureScreen(),
      ),
    );

    if (!mounted || recordedMedia == null) {
      return false;
    }

    final didSave = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return DescriptionMediaCommentBottomSheet(
          contentType: DescriptionMediaCommentContentType.screenRecording,
          initialMediaFile: recordedMedia,
          initialMediaType: 'screen_recording',
          allowInitialMediaRemoval: false,
          onSave: (comment, mediaFile, mediaType) =>
              widget.controller.saveMediaComment(comment, mediaFile, mediaType),
        );
      },
    );

    return didSave ?? false;
  }

  Future<void> _showMediaTypeSelectionSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return _MediaTypeSelectionBottomSheet(
          showScreenRecording: false,
          onTypeSelected: (selectedType) =>
              _openSelectedMediaCommentDialog(selectedType),
          onCommentOnlySelected: () => _openTextOnlyCommentDialog(),
        );
      },
    );

    if (!mounted) {
      return;
    }

    widget.onCommentsSheetClosed();
  }
}

class _CommentIconButton extends StatelessWidget {
  const _CommentIconButton({
    required this.isEnabled,
    required this.icon,
    this.onTap,
  });

  final bool isEnabled;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = isEnabled ? AppColors.secondaryColor : AppColors.grey1;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: AppColors.surfaceDark3,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.6)),
          ),
          child: Icon(icon, color: color, size: 17),
        ),
      ),
    );
  }
}

class _CommentMediaCard extends StatelessWidget {
  const _CommentMediaCard({
    required this.descriptionId,
    required this.comment,
    required this.mediaList,
    required this.isReadOnly,
    required this.canReply,
    required this.canDelete,
    required this.onCommentsChanged,
    required this.onSheetClosed,
  });

  final String descriptionId;
  final CheckInDescriptionCommentData comment;
  final List<AuditDescriptionMedia> mediaList;
  final bool isReadOnly;
  final bool canReply;
  final bool canDelete;
  final Future<void> Function() onCommentsChanged;
  final VoidCallback onSheetClosed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          _openCommentsDialog(context);
        },
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.surfaceDark3,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.grey2.withValues(alpha: 0.45)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _CommentMediaPreview(comment: comment),
              const SizedBox(width: 12),
              Expanded(
                child: AppTextView.body2(
                  comment.comment,
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w500,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openCommentsDialog(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CheckInMediaCommentsBottomSheet(
        descriptionId: descriptionId,
        selectedMedia: comment.media,
        mediaList: mediaList,
        isReadOnly: isReadOnly,
        canReply: canReply,
        canDelete: canDelete,
        onMediaChanged: onCommentsChanged,
      ),
    );

    if (!context.mounted) {
      return;
    }

    onSheetClosed();
  }
}

class _CommentMediaPreview extends StatelessWidget {
  const _CommentMediaPreview({required this.comment});

  final CheckInDescriptionCommentData comment;

  @override
  Widget build(BuildContext context) {
    if (comment.isScreenRecording) {
      return const _ScreenRecordingCommentPreview();
    }
    return CheckInMediaPreview(
      mediaUrl: comment.media.media,
      mediaType: comment.media.type,
      width: 72,
      height: 72,
      borderRadius: 12,
      placeholder: comment.hasMedia
          ? const _CommentMediaLoadingPlaceholder()
          : const CheckInTextCommentPlaceholder(),
    );
  }
}

class _ScreenRecordingCommentPreview extends StatelessWidget {
  const _ScreenRecordingCommentPreview();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        color: AppColors.hex14182a,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: AppColors.secondaryColor,
            borderRadius: BorderRadius.circular(17),
          ),
          child: const Icon(
            Icons.play_arrow_rounded,
            color: Colors.white,
            size: 22,
          ),
        ),
      ),
    );
  }
}

class _CommentMediaLoadingPlaceholder extends StatelessWidget {
  const _CommentMediaLoadingPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      '${AppStrings.imagePath}no_image.png',
      fit: BoxFit.cover,
    );
  }
}

class _MediaTypeSelectionBottomSheet extends StatefulWidget {
  const _MediaTypeSelectionBottomSheet({
    required this.onTypeSelected,
    required this.showScreenRecording,
    required this.onCommentOnlySelected,
  });

  final Future<bool> Function(DescriptionMediaCommentContentType selectedType)
  onTypeSelected;
  final bool showScreenRecording;
  final Future<bool> Function() onCommentOnlySelected;

  @override
  State<_MediaTypeSelectionBottomSheet> createState() =>
      _MediaTypeSelectionBottomSheetState();
}

class _MediaTypeSelectionBottomSheetState
    extends State<_MediaTypeSelectionBottomSheet> {
  late final ValueNotifier<bool> _isOpeningChildSheetNotifier =
      ValueNotifier<bool>(false);

  @override
  void dispose() {
    _isOpeningChildSheetNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.paddingOf(context).bottom;

    return ValueListenableBuilder<bool>(
      valueListenable: _isOpeningChildSheetNotifier,
      builder: (context, isOpeningChildSheet, _) {
        return SafeArea(
          top: false,
          bottom: false,
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(18, 14, 18, bottomPadding + 24),
            decoration: const BoxDecoration(
              color: AppColors.surfaceDark,
              borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 46,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                const AppTextView.body1(
                  AppStrings.auditSelectMediaType,
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
                const SizedBox(height: 14),
                _MediaTypeOption(
                  title: AppStrings.auditCommentOnly,
                  onTap: isOpeningChildSheet ? null : _openCommentOnlyDialog,
                ),
                const SizedBox(height: 10),
                _MediaTypeOption(
                  title: AppStrings.auditPhoto,
                  onTap: isOpeningChildSheet
                      ? null
                      : () => _openChildSheet(
                          DescriptionMediaCommentContentType.photo,
                        ),
                ),
                const SizedBox(height: 10),
                _MediaTypeOption(
                  title: AppStrings.auditVideo,
                  onTap: isOpeningChildSheet
                      ? null
                      : () => _openChildSheet(
                          DescriptionMediaCommentContentType.video,
                        ),
                ),
                const SizedBox(height: 10),
                _MediaTypeOption(
                  title: AppStrings.auditUpload,
                  onTap: isOpeningChildSheet
                      ? null
                      : () => _openChildSheet(
                          DescriptionMediaCommentContentType.upload,
                        ),
                ),
                if (widget.showScreenRecording) ...[
                  const SizedBox(height: 10),
                  _MediaTypeOption(
                    title: AppStrings.auditScreenRecording,
                    onTap: isOpeningChildSheet
                        ? null
                        : () => _openChildSheet(
                            DescriptionMediaCommentContentType.screenRecording,
                          ),
                  ),
                ],
                const SizedBox(height: 18),
                AppButton(
                  text: AppStrings.done,
                  onPressed: isOpeningChildSheet
                      ? null
                      : () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _openChildSheet(
    DescriptionMediaCommentContentType selectedType,
  ) async {
    if (_isOpeningChildSheetNotifier.value) {
      return;
    }

    _isOpeningChildSheetNotifier.value = true;
    try {
      final didSave = await widget.onTypeSelected(selectedType);
      if (didSave && mounted) {
        Navigator.of(context).pop();
      }
    } finally {
      if (mounted) _isOpeningChildSheetNotifier.value = false;
    }
  }

  Future<void> _openCommentOnlyDialog() async {
    if (_isOpeningChildSheetNotifier.value) {
      return;
    }

    _isOpeningChildSheetNotifier.value = true;
    try {
      final didSave = await widget.onCommentOnlySelected();
      if (didSave && mounted) {
        Navigator.of(context).pop();
      }
    } finally {
      if (mounted) _isOpeningChildSheetNotifier.value = false;
    }
  }
}

class _MediaTypeOption extends StatelessWidget {
  const _MediaTypeOption({required this.title, required this.onTap});

  final String title;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.surfaceDark3,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.grey2.withValues(alpha: 0.4)),
          ),
          child: Row(
            children: [
              Expanded(
                child: AppTextView.body2(
                  title,
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textSecondary,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
