import '../result_wrapper/list_wrapper_base.dart';
import '../youtipie_feed/yt_feed_base.dart';

class YoutiPieChannelTabResult extends YoutiPieListWrapper<YoutubeFeed> with YoutiPieListSorterMixin<YoutubeFeed> {
  const YoutiPieChannelTabResult({required this.channelId, super.items = const [], super.cacheKey, super.continuation});

  final String channelId;
}
