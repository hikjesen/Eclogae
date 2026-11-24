import '../core/enum.dart';

class PlaylistForVideoItem {
  const PlaylistForVideoItem({required this.playlistId, this.playlistTitle, this.privacy, this.containsVideo});

  final String playlistId;
  final String? playlistTitle;
  final PlaylistPrivacy? privacy;
  final bool? containsVideo;
}
