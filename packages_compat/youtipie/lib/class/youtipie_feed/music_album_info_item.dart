import '../thumbnail.dart';
import 'channel_info_item.dart';
import 'yt_feed_base.dart';

class MusicAlbumInfoItem extends YoutubeFeed {
  const MusicAlbumInfoItem({required this.id, required this.title, this.subtitle = '', this.thumbnails = const [], this.artists = const []});

  final String id, title, subtitle;
  final List<YoutiPieThumbnail> thumbnails;
  final List<ChannelInfoItem> artists;

  @override
  Map<String, Object?> toMap() => {'id': id, 'title': title, 'subtitle': subtitle};
}
