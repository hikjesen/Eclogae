import '../youtipie_feed/yt_feed_base.dart';
import 'list_wrapper_base.dart';

class YoutiPieUserChannelsAllVideosResult extends YoutiPieListWrapper<YoutubeFeed> with YoutiPieListSorterMixin<YoutubeFeed> {
  const YoutiPieUserChannelsAllVideosResult({super.items = const [], super.cacheKey, super.continuation});
}
