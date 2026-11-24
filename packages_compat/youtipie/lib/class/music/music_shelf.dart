import '../map_serializable.dart';
import '../thumbnail.dart';
import '../youtipie_feed/yt_feed_base.dart';
import 'music_browse_endpoint.dart';

enum YoutiPieMusicShelfLayout { carousel, rows, list, grid }

class YoutiPieMusicShelf extends MapSerializable {
  const YoutiPieMusicShelf({
    this.title = '',
    this.strapline,
    this.layout = YoutiPieMusicShelfLayout.list,
    this.items = const [],
    this.thumbnails = const [],
    this.moreEndpoint,
    this.rowsPerColumn = 1,
  });

  final String title;
  final String? strapline;
  final YoutiPieMusicShelfLayout layout;
  final List<YoutubeFeed> items;
  final List<YoutiPieThumbnail> thumbnails;
  final YoutiPieMusicBrowseEndpoint? moreEndpoint;
  final int rowsPerColumn;

  @override
  Map<String, Object?> toMap() => {'title': title, 'items': items.map((item) => item.toMap()).toList()};
}
