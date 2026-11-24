import 'comment_info_item_base.dart';

class CommentInfoItem extends CommentInfoItemBase {
  const CommentInfoItem({
    required super.commentId,
    super.content,
    super.author,
    super.authorAvatarUrl,
    super.publishedAt,
    super.publishedTimeText,
    super.voiceReplyTranscript,
    super.isHearted,
    super.isEdited,
    super.likesCount,
    super.likeStatus,
    this.isPinned = false,
    this.repliesCount,
    this.replyContinuation,
  });

  final bool isPinned;
  final int? repliesCount;
  final String? replyContinuation;
}
