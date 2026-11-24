import '../map_serializable.dart';
import '../youtipie_feed/playlist_info_item.dart';
import '../youtipie_feed/yt_feed_base.dart';

class YoutiPieHistoryChunk extends MapSerializable {
  const YoutiPieHistoryChunk({this.title = '', this.items = const []});

  final String title;
  final List<YoutubeFeed> items;

  ({int value}) get shortsItemsCount => (value: items.where((item) => item.isShortContent).length,);
  ({int value}) get mixesPlaylistCount => (value: items.where((item) => item is PlaylistInfoItem && item.isMix).length,);

  @override
  Map<String, Object?> toMap() => {'title': title, 'items': items.map((item) => item.toMap()).toList()};
}
