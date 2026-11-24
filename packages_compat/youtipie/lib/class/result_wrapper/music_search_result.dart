import '../music/music_search_chip.dart';
import '../music/music_top_result.dart';
import '../youtipie_feed/yt_feed_base.dart';
import 'list_wrapper_base.dart';

class YoutiPieMusicSearchResult extends YoutiPieListWrapper<YoutubeFeed> {
  const YoutiPieMusicSearchResult({required this.query, super.items = const [], super.cacheKey, super.continuation, this.chips = const [], this.topResult});

  final String query;
  final List<YoutiPieMusicSearchChip> chips;
  final YoutiPieMusicTopResult? topResult;
}
