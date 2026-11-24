import '../thumbnail.dart';
import 'channel_info.dart';
import 'channel_tab.dart';

class YoutiPieChannelPageResult extends YoutiPieChannelInfo {
  const YoutiPieChannelPageResult({
    required super.id,
    super.handler,
    super.title,
    super.thumbnails,
    super.subscribersCount,
    super.subscribersCountText,
    super.isVerified,
    super.channelEngagement,
    super.subscribed,
    super.notifications,
    this.tabs = const [],
    this.banners = const [],
    this.tvbanners = const [],
    this.mobileBanners = const [],
    this.videosCount,
    this.videosCountText,
  });

  final List<ChannelTab> tabs;
  final List<YoutiPieThumbnail> banners, tvbanners, mobileBanners;
  final int? videosCount;
  final String? videosCountText;
}
