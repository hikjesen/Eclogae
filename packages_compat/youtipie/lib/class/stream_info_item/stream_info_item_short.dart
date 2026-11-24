import '../thumbnail.dart';
import '../youtipie_feed/yt_feed_base.dart';

class StreamInfoItemShort extends YoutubeFeed {
  const StreamInfoItemShort({required this.id, required this.title, this.viewsText = '', this.viewsCount, this.liveThumbs = const []});

  final String id, title, viewsText;
  @override
  String get cacheKey => id;
  final int? viewsCount;
  final List<YoutiPieThumbnail> liveThumbs;

  @override
  bool get isShortContent => true;

  @override
  Map<String, Object?> toMap() => {
    'id': id,
    'title': title,
    'viewsText': viewsText,
    'viewsCount': viewsCount,
    'liveThumbs': liveThumbs.map((item) => item.toMap()).toList(),
  };
}
