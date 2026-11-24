import '../stream_info_item/stream_info_item.dart';
import 'playlist_basic_info.dart';
import 'yt_feed_base.dart';

class PlaylistInfoItem extends PlaylistBasicInfo {
  const PlaylistInfoItem({
    required super.id,
    required super.title,
    super.videosCountText,
    super.videosCount,
    super.thumbnails,
    this.subtitle = '',
    this.initialVideos = const [],
  });

  final String subtitle;
  final List<StreamInfoItem> initialVideos;

  static bool isMixPlaylist(String playlistId) => playlistId.startsWith('RD');

  bool get isMix => isMixPlaylist(id);
}

extension YoutubeFeedPlaylistUtils on YoutubeFeed {
  bool get isMixPlaylist {
    final item = this;
    return item is PlaylistInfoItem && item.isMix;
  }
}
