import '../youtipie_feed/yt_feed_base.dart';
import 'feedback_holder.dart';
import 'feed_result.dart' show ShortsSection;
import 'list_wrapper_base.dart';

class YoutiPieRelatedVideosResult extends YoutiPieListWrapper<YoutubeFeed> with YoutiPieFeedbackHolder {
  const YoutiPieRelatedVideosResult({
    required this.videoId,
    required this.isPersonalized,
    required super.items,
    super.cacheKey,
    super.continuation,
  });

  final String videoId;
  final bool isPersonalized;
  ShortsSection get shortsSection => const ShortsSection();
}
