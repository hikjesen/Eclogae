import '../../thumbnail.dart';
import '../../youtipie_feed/playlist_basic_info.dart';

enum VideoEndScreenItemType { video, playlist, channel, unknown }

sealed class EndScreenItemBase {
  const EndScreenItemBase(this.type);

  final VideoEndScreenItemType type;
  int get startMs => 0;
  int get endMs => 0;
  List<YoutiPieThumbnail> get thumbnails => const [];
  String? get title => null;
  ({double left, double top, double width, double aspectRatio}) get display => (left: 0, top: 0, width: 0, aspectRatio: 1);
}

final class EndScreenItemVideo extends EndScreenItemBase {
  const EndScreenItemVideo(this.videoId, {this.viewsCount, this.viewsCountText}) : super(VideoEndScreenItemType.video);
  final String? videoId, viewsCountText;
  final int? viewsCount;
}

final class EndScreenItemChannel extends EndScreenItemBase {
  const EndScreenItemChannel(this.channelId) : super(VideoEndScreenItemType.channel);
  final String? channelId;
}

final class EndScreenItemPlaylist extends EndScreenItemBase {
  const EndScreenItemPlaylist(this.basicInfo) : super(VideoEndScreenItemType.playlist);
  final PlaylistBasicInfo basicInfo;
}
