import '../map_serializable.dart';
import '../notification_menu_action.dart';
import '../publish_time.dart';
import '../thumbnail.dart';

class StreamInfoItemNotification extends MapSerializable {
  const StreamInfoItemNotification({
    required this.id,
    required this.notificationId,
    required this.shortText,
    this.linkedCommentId,
    this.isRead,
    this.isComment = false,
    this.isCommentReply = false,
    this.publishedAt = const PublishTime.unknown(),
    this.possibleInfo,
    this.thumbs = const [],
    this.uploaderthumbs = const [],
    this.menuActions = const [],
  });

  final String id, notificationId, shortText;
  final String? linkedCommentId;
  final bool? isRead;
  final bool isComment, isCommentReply;
  final PublishTime publishedAt;
  final ({String title, String channelTitle})? possibleInfo;
  final List<YoutiPieThumbnail> thumbs, uploaderthumbs;
  final List<NotificationMenuAction> menuActions;

  @override
  Map<String, Object?> toMap() => {'id': id, 'notificationId': notificationId, 'shortText': shortText};
}
