import '../../../../core/utils/custom_functions.dart';
import '../../domain/entities/description_comments_response.dart';

class CheckInMediaCommentsState {
  const CheckInMediaCommentsState({
    this.mediaUrl = '',
    this.mediaType = '',
    this.comments = const <DescriptionComment>[],
    this.isLoadingComments = true,
    this.isSendingComment = false,
    this.isUploadingMedia = false,
    this.isDeleting = false,
    this.isReplying = false,
    this.commentsError,
    this.replyingTo,
  });

  final String mediaUrl;
  final String mediaType;
  final List<DescriptionComment> comments;
  final bool isLoadingComments;
  final bool isSendingComment;
  final bool isUploadingMedia;
  final bool isDeleting;
  final bool isReplying;
  final String? commentsError;
  final DescriptionComment? replyingTo;

  CheckInMediaCommentsState copyWith({
    String? mediaUrl,
    String? mediaType,
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
    return CheckInMediaCommentsState(
      mediaUrl: mediaUrl ?? this.mediaUrl,
      mediaType: mediaType ?? this.mediaType,
      comments: comments ?? this.comments,
      isLoadingComments: isLoadingComments ?? this.isLoadingComments,
      isSendingComment: isSendingComment ?? this.isSendingComment,
      isUploadingMedia: isUploadingMedia ?? this.isUploadingMedia,
      isDeleting: isDeleting ?? this.isDeleting,
      isReplying: isReplying ?? this.isReplying,
      commentsError: clearCommentsError
          ? null
          : commentsError ?? this.commentsError,
      replyingTo: clearReplyingTo ? null : replyingTo ?? this.replyingTo,
    );
  }
}

/// Display-ready comment content shared by top-level comments and replies.
class CheckInMediaCommentViewData {
  CheckInMediaCommentViewData(DescriptionComment comment)
    : source = comment,
      authorName = CustomFunctions.displayCommentAuthorName(
        name: comment.author?.name,
        email: comment.author?.email,
      ),
      authorImage = comment.author?.image,
      text = CustomFunctions.displayCommentText(comment.comment),
      timeAgo = CustomFunctions.formatCommentTimeAgo(comment.createdAt),
      replies = comment.replies
          .map(CheckInMediaCommentViewData.new)
          .toList(growable: false);

  final DescriptionComment source;
  final String authorName;
  final String? authorImage;
  final String text;
  final String timeAgo;
  final List<CheckInMediaCommentViewData> replies;
}

class CheckInMediaCommentsFeedback {
  const CheckInMediaCommentsFeedback(this.message, {this.showAlert = false});

  final String message;
  final bool showAlert;
}
