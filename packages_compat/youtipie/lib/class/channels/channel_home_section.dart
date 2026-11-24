import '../thumbnail.dart';
import '../youtipie_feed/yt_feed_base.dart';

class YoutiPieChannelHomeSection extends YoutubeFeed {
  const YoutiPieChannelHomeSection({required this.title, this.playlistId, this.thumbnails = const [], this.items = const []});

  final String title;
  final String? playlistId;
  final List<YoutiPieThumbnail> thumbnails;
  final List<YoutubeFeed> items;

  @override
  Map<String, Object?> toMap() => {
    'title': title,
    'playlistId': playlistId,
    'thumbnails': thumbnails.map((item) => item.toMap()).toList(),
    'items': items.map((item) => item.toMap()).toList(),
  };
}
