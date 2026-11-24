import '../../core/enum.dart';
import 'playlist_info_item.dart';

class PlaylistInfoItemUser extends PlaylistInfoItem {
  const PlaylistInfoItemUser({
    required super.id,
    required super.title,
    super.videosCountText,
    super.videosCount,
    super.thumbnails,
    this.privacy,
    this.infoTexts,
  });

  final PlaylistPrivacy? privacy;
  final List<String>? infoTexts;
}
