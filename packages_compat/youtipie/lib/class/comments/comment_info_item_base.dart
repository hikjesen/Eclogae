import '../../core/enum.dart';
import '../map_serializable.dart';
import '../publish_time.dart';
import '../youtipie_description/youtipie_description.dart';

class CommentInfoItemBase extends MapSerializable {
  const CommentInfoItemBase({
    required this.commentId,
    this.content = const YoutipieDescription(),
    this.author,
    this.authorAvatarUrl,
    this.publishedAt = const PublishTime.unknown(),
    this.publishedTimeText,
    this.voiceReplyTranscript,
    this.isHearted = false,
    this.isEdited = false,
    this.likesCount,
    this.likeStatus,
  });

  final String commentId;
  final YoutipieDescription content;
  final CommentAuthor? author;
  final String? authorAvatarUrl, publishedTimeText, voiceReplyTranscript;
  final PublishTime publishedAt;
  final bool isHearted, isEdited;
  final int? likesCount;
  final LikeStatus? likeStatus;
  ({String? createReplyParams}) get engagement => (createReplyParams: null,);

  @override
  Map<String, Object?> toMap() => {'commentId': commentId, 'content': content.rawText};
}

class CommentAuthor {
  const CommentAuthor({
    this.channelId,
    this.displayName,
    this.avatarThumbnailUrl,
    this.isCurrentUser = false,
    this.isArtist = false,
    this.memberBadgeText,
  });

  final String? channelId, displayName, avatarThumbnailUrl, memberBadgeText;
  final bool isCurrentUser, isArtist;
}
