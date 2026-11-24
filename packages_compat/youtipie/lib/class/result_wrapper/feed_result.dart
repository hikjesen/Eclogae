import '../stream_info_item/stream_info_item.dart';
import '../stream_info_item/stream_info_item_short.dart';
import '../youtipie_feed/yt_feed_base.dart';
import 'feedback_holder.dart';
import 'list_wrapper_base.dart';

class YoutiPieFeedResult extends YoutiPieListWrapper<YoutubeFeed> with YoutiPieFeedbackHolder {
  const YoutiPieFeedResult({super.items = const [], super.cacheKey, super.continuation});

  ShortsSection get shortsSection => const ShortsSection();
}

class ShortsSection {
  const ShortsSection();

  Map<int, List<int>> get relatedItemsShortsData => const {};
  Map<int, bool> get shortsIndicesLookup => const {};

  StreamInfoItemShort getAsShort(YoutubeFeed item) => switch (item) {
    StreamInfoItemShort short => short,
    StreamInfoItem video => StreamInfoItemShort(
      id: video.id,
      title: video.title,
      viewsText: video.viewsText ?? '',
      viewsCount: video.viewsCount,
      liveThumbs: video.liveThumbs,
    ),
    _ => throw UnsupportedError('YouTube disabled in Namida LX build'),
  };
}
