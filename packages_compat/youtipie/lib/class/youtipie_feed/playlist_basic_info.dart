import '../../core/url_utils.dart';
import '../thumbnail.dart';
import 'yt_feed_base.dart';

class PlaylistBasicInfo extends YoutubeFeed {
  const PlaylistBasicInfo({required this.id, required this.title, this.videosCountText, this.videosCount, this.thumbnails = const []});

  final String id, title;
  @override
  String get cacheKey => id;
  final String? videosCountText;
  final int? videosCount;
  final List<YoutiPieThumbnail> thumbnails;

  String buildUrl() => YTUrlUtils.buildPlaylistUrl(id);

  factory PlaylistBasicInfo.fromMap(Map<Object?, Object?> map) => PlaylistBasicInfo(
    id: map['id'] as String,
    title: map['title'] as String,
    videosCountText: map['videosCountText'] as String?,
    videosCount: map['videosCount'] as int?,
    thumbnails: YoutiPieThumbnail.listFromMap(map['thumbnails']),
  );

  @override
  Map<String, Object?> toMap() => {
    'id': id,
    'title': title,
    'videosCountText': videosCountText,
    'videosCount': videosCount,
    'thumbnails': thumbnails.map((item) => item.toMap()).toList(),
  };
}
