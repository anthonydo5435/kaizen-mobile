part of '../pages/seat_description_final_check_in_report.dart';

class _CommentsCard extends StatelessWidget {
  const _CommentsCard({
    required this.comments,
    required this.hasComments,
    required this.isLoading,
    required this.searchController,
    required this.onSearchChanged,
  });

  final List<FinalCheckInReportCommentData> comments;
  final bool hasComments;
  final bool isLoading;
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.grey2.withValues(alpha: 0.55)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppTextView.body1(
            AppStrings.comments,
            color: AppColors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
          if (hasComments) ...[
            const SizedBox(height: 4),
            const AppTextView.body1(
              AppStrings.finalCheckInReportCommentsSubtitle,
              color: AppColors.grey1,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
            const SizedBox(height: 12),
            _CommentsSearchBar(
              controller: searchController,
              onChanged: onSearchChanged,
            ),
            const SizedBox(height: 12),
          ] else
            const SizedBox(height: 12),
          if (isLoading)
            SizedBox(
              height: 48,
              child: Center(child: FastCircularProgressIndicator()),
            )
          else if (comments.isEmpty)
            const AppTextView.body(
              AppStrings.finalCheckInReportNoComments,
              color: AppColors.textSecondary,
              fontSize: 12,
            )
          else
            Column(
              children: comments
                  .map(
                    (comment) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _CommentListTile(comment: comment),
                    ),
                  )
                  .toList(growable: false),
            ),
        ],
      ),
    );
  }
}

class _CommentsSearchBar extends StatelessWidget {
  const _CommentsSearchBar({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark3,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.grey2.withValues(alpha: 0.45)),
      ),
      child: Row(
        children: [
          SvgPicture.asset(
            '${AppStrings.imagePath}search.svg',
            width: 18,
            height: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              cursorColor: AppColors.textPrimary,
              cursorHeight: 18,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              decoration: const InputDecoration(
                hintText: AppStrings.finalCheckInReportSearchComments,
                hintStyle: TextStyle(
                  color: AppColors.grey1,
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                ),
                border: InputBorder.none,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CommentListTile extends StatelessWidget {
  const _CommentListTile({required this.comment});

  final FinalCheckInReportCommentData comment;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: comment.canOpenComments
            ? () => _openCommentsSheet(context)
            : null,
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
                  comment.text,
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

  Future<void> _openCommentsSheet(BuildContext context) {
    final selectedMedia = comment.media;

    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (_) => CheckInMediaCommentsBottomSheet(
        descriptionId: '',
        selectedMedia: selectedMedia,
        mediaList: [selectedMedia],
        onMediaChanged: () async {},
        isReadOnly: true,
      ),
    );
  }
}

class _CommentMediaPreview extends StatelessWidget {
  const _CommentMediaPreview({required this.comment});

  final FinalCheckInReportCommentData comment;

  @override
  Widget build(BuildContext context) {
    if (comment.isVideo) {
      return _ScreenRecordingCommentPreview(thumbnailUrl: comment.thumbnailUrl);
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
  const _ScreenRecordingCommentPreview({this.thumbnailUrl});

  final String? thumbnailUrl;

  @override
  Widget build(BuildContext context) {
    if (thumbnailUrl != null) {
      return Stack(
        children: [
          CheckInMediaPreview(
            mediaUrl: thumbnailUrl,
            mediaType: 'image',
            width: 72,
            height: 72,
            borderRadius: 12,
            placeholder: const _CommentMediaLoadingPlaceholder(),
            showVideoOverlay: false,
          ),
          Positioned.fill(
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
          ),
        ],
      );
    }

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
