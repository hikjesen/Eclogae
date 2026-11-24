import '../../core/enum.dart';
import '../../core/url_utils.dart';
import '../youtipie_feed/channel_info_item.dart';

class YoutiPieChannelInfo extends ChannelInfoItem {
  const YoutiPieChannelInfo({
    required super.id,
    super.handler,
    super.title,
    super.thumbnails,
    this.subscribersCount,
    this.subscribersCountText,
    this.isVerified,
    this.channelEngagement,
    this.subscribed,
    this.notifications,
  });

  final int? subscribersCount;
  final String? subscribersCountText;
  final bool? isVerified, subscribed;
  final ChannelEngagement? channelEngagement;
  final ChannelNotifications? notifications;

  String buildUrl() => YTUrlUtils.buildChannelUrl(id);
}

class ChannelEngagement {
  const ChannelEngagement();
}
