import '../comments/comment_info_item_base.dart';
import 'comment_result.dart';

class YoutiPieNotificationCommentResult extends YoutiPieCommentResult {
  const YoutiPieNotificationCommentResult({
    super.items,
    super.cacheKey,
    super.continuation,
    this.linkedMainCommentId,
    this.linkedReply,
  });

  final String? linkedMainCommentId;
  final CommentInfoItemBase? linkedReply;
}
