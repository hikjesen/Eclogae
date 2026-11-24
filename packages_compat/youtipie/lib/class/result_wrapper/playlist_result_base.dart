import '../stream_info_item/stream_info_item.dart';
import '../youtipie_feed/playlist_basic_info.dart';
import 'list_wrapper_base.dart';

class YoutiPiePlaylistResultBase extends YoutiPieListWrapper<StreamInfoItem> {
  const YoutiPiePlaylistResultBase({required this.basicInfo, required super.items, super.cacheKey, super.continuation});

  final PlaylistBasicInfo basicInfo;
}
