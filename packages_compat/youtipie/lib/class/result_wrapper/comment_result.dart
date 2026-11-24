import '../../core/enum.dart';
import '../comments/comment_info_item.dart';
import 'list_wrapper_base.dart';

class YoutiPieCommentResult extends YoutiPieListWrapper<CommentInfoItem> {
  const YoutiPieCommentResult({
    super.items = const [],
    super.cacheKey,
    super.continuation,
    this.videoId,
    this.commentsCount,
    this.pausedMessage,
    this.createParams,
    this.sorters = const {},
  });

  final String? videoId, pausedMessage;
  final int? commentsCount;
  final String? createParams;
  final Map<CommentsSortType, String> sorters;

  CommentInfoItem? operator [](int index) => index >= 0 && index < items.length ? items[index] : null;

  void transferLocalItemsTo(YoutiPieCommentResult result) {}
}
