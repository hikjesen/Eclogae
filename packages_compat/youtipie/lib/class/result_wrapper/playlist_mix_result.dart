import 'playlist_result_base.dart';
import 'related_videos_result.dart';

class YoutiPieMixPlaylistResult extends YoutiPiePlaylistResultBase {
  const YoutiPieMixPlaylistResult({required super.basicInfo, super.items = const [], super.cacheKey, super.continuation, this.isPersonalized = false});

  final bool isPersonalized;
  String get mixId => basicInfo.id;

  YoutiPieRelatedVideosResult toRelatedVideosResult() => YoutiPieRelatedVideosResult(
    videoId: basicInfo.id,
    isPersonalized: isPersonalized,
    items: items,
    cacheKey: cacheKey,
    continuation: continuation,
  );
}
