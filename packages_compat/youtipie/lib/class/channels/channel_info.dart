import '../../core/enum.dart';
import '../../core/url_utils.dart';
import '../youtipie_feed/channel_info_item.dart';

class YoutiPieChannelInfo extends ChannelInfoItem {
  YoutiPieChannelInfo({
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
    this.notificationParameters,
  });

  final int? subscribersCount;
  final String? subscribersCountText;
  final bool? isVerified;
  final ChannelEngagement? channelEngagement;
  bool? subscribed;
  ChannelNotifications? notifications;
  Map<ChannelNotifications, String>? notificationParameters;

  void rebuild({
    required bool? newSubscribed,
    required ChannelNotifications? newNotifications,
    required Map<ChannelNotifications, String>? newNotificationParameters,
  }) {
    subscribed = newSubscribed;
    notifications = newNotifications;
    notificationParameters = newNotificationParameters;
  }

  String buildUrl() => YTUrlUtils.buildChannelUrl(id);
}

class ChannelEngagement {
  const ChannelEngagement();
}
