import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/widgets/app_text_view.dart';
import '../../../../core/utils/custom_functions.dart';
import '../../../../core/widgets/fast_circular_progress.dart';
import '../../domain/entities/description_comments_response.dart';
import '../providers/check_in_media_comments_state.dart';

class CheckInMediaCommentsList extends StatelessWidget {
  const CheckInMediaCommentsList({
    super.key,
    required this.isLoading,
    required this.errorMessage,
    required this.comments,
    required this.canReply,
    required this.onReply,
  });

  final bool isLoading;
  final String? errorMessage;
  final List<CheckInMediaCommentViewData> comments;
  final bool canReply;
  final ValueChanged<DescriptionComment> onReply;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: 18),
        child: Center(
          child: SizedBox(
            width: 26,
            height: 26,
            child: FastCircularProgressIndicator(),
          ),
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
        AppStrings.noCommentsAvailable,
        color: AppColors.textSecondary,
        fontWeight: FontWeight.w400,
        fontSize: 12,
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      primary: false,
      padding: EdgeInsets.zero,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: comments.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) => _CommentCard(
        key: ValueKey(comments[index].source.uuid),
        comment: comments[index],
        canReply: canReply,
        onReply: () => onReply(comments[index].source),
      ),
    );
  }
}

class _CommentCard extends StatefulWidget {
  const _CommentCard({
    super.key,
    required this.comment,
    required this.canReply,
    required this.onReply,
  });

  final CheckInMediaCommentViewData comment;
  final bool canReply;
  final VoidCallback onReply;

  @override
  State<_CommentCard> createState() => _CommentCardState();
}

class _CommentCardState extends State<_CommentCard> {
  final _showReplies = ValueNotifier<bool>(false);

  @override
  void dispose() {
    _showReplies.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: _showReplies,
      builder: (context, showReplies, _) => _buildCard(showReplies),
    );
  }

  Widget _buildCard(bool showReplies) {
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
          _ProfileAvatar(imageUrl: widget.comment.authorImage),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: AppTextView.body2(
                        widget.comment.authorName,
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    AppTextView.body4(
                      widget.comment.timeAgo,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                AppTextView.body2(
                  widget.comment.text,
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
                    isExpanded: showReplies,
                    onTap: () {
                      _showReplies.value = !_showReplies.value;
                    },
                  ),
                ],
                if (showReplies && widget.comment.replies.isNotEmpty) ...[
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

  final List<CheckInMediaCommentViewData> replies;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 2,
            margin: const EdgeInsets.only(
              left: 6,
              right: 12,
              top: 4,
              bottom: 4,
            ),
            decoration: BoxDecoration(
              color: AppColors.grey2.withValues(alpha: 0.75),
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          Expanded(
            child: Column(
              children: replies
                  .asMap()
                  .entries
                  .map(
                    (entry) => Padding(
                      padding: EdgeInsets.only(top: entry.key == 0 ? 0 : 10),
                      child: _ReplyComment(comment: entry.value),
                    ),
                  )
                  .toList(growable: false),
            ),
          ),
        ],
      ),
    );
  }
}

class _RepliesToggle extends StatelessWidget {
  const _RepliesToggle({
    required this.repliesCount,
    required this.isExpanded,
    required this.onTap,
  });

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
          isExpanded
              ? AppStrings.auditMediaHideReplies
              : AppStrings.auditMediaShowReplies(repliesCount),
          color: AppColors.secondaryColor,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _ReplyComment extends StatelessWidget {
  const _ReplyComment({required this.comment});

  final CheckInMediaCommentViewData comment;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ProfileAvatar(imageUrl: comment.authorImage, size: 30),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: AppTextView.body3(
                      comment.authorName,
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  AppTextView.body4(
                    comment.timeAgo,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ],
              ),
              const SizedBox(height: 3),
              AppTextView.body3(
                comment.text,
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
            ? Image.asset(AppStrings.dummyProfileImagePath, fit: BoxFit.cover)
            : Image.network(
                resolvedImageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) {
                  return Image.asset(
                    AppStrings.dummyProfileImagePath,
                    fit: BoxFit.cover,
                  );
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
          AppTextView.body4(
            AppStrings.actionReply,
            color: AppColors.secondaryColor,
            fontWeight: FontWeight.w600,
          ),
        ],
      ),
    );
  }
}
