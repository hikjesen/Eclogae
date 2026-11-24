import '../comments/comment_info_item_base.dart';
import 'list_wrapper_base.dart';

class YoutiPieCommentReplyResult extends YoutiPieListWrapper<CommentInfoItemBase> {
  const YoutiPieCommentReplyResult({required this.commentId, required super.items, super.cacheKey, super.continuation});

  final String commentId;

  void transferLocalItemsTo(YoutiPieCommentReplyResult result) {}
}
