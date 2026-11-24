import '../../core/enum.dart';
import '../../core/url_utils.dart';
import '../publish_time.dart';
import '../youtipie_description/youtipie_description.dart';

class YoutiPieVideoInfo {
  const YoutiPieVideoInfo({
    required this.id,
    required this.title,
    this.channelId,
    this.channelName,
    this.publishedAt = const PublishTime.unknown(),
    this.durSeconds,
    this.description,
    this.engagement,
    this.viewsCount,
    this.viewsText,
    this.viewCountTextShort,
    this.viewCountTextLong,
  });

  final String id, title;
  final String? channelId, channelName, viewsText, viewCountTextShort, viewCountTextLong;
  final int? durSeconds, viewsCount;
  final PublishTime publishedAt;
  final YoutipieDescription? description;
  final VideoEngagement? engagement;

  String buildUrl() => YTUrlUtils.buildVideoUrl(id);
}

class VideoEngagement {
  const VideoEngagement({this.likeStatus, this.likesCount, this.likesCountText});
  final LikeStatus? likeStatus;
  final int? likesCount;
  final String? likesCountText;
}
