import '../publish_time.dart';
import '../thumbnail.dart';
import '../youtipie_feed/channel_info_item.dart';
import '../youtipie_feed/yt_feed_base.dart';

class StreamInfoItem extends YoutubeFeed {
  const StreamInfoItem({
    required this.id,
    required this.title,
    this.shortDescription,
    this.channel,
    this.thumbnailGifUrl,
    this.publishedFromText = '',
    this.publishedAt = const PublishTime.unknown(),
    this.indexInPlaylist,
    this.durSeconds,
    this.durText,
    this.viewsText,
    this.viewsCount,
    this.percentageWatched,
    this.liveThumbs = const [],
    this.isUploaderVerified,
    this.badges,
    this.isActuallyShortContent,
  });

  final String id, title, publishedFromText;
  @override
  String get cacheKey => id;
  final String? shortDescription, thumbnailGifUrl, durText, viewsText;
  final ChannelInfoItem? channel;
  final PublishTime publishedAt;
  final int? indexInPlaylist, durSeconds, viewsCount;
  final double? percentageWatched;
  final List<YoutiPieThumbnail> liveThumbs;
  final List<String>? badges;
  final bool? isUploaderVerified, isActuallyShortContent;

  String? get channelId => channel?.id;
  String? get channelName => channel?.title;
  String? get availableDescription => shortDescription;
  @override
  bool get isShortContent => isActuallyShortContent ?? false;

  factory StreamInfoItem.fromMap(Map<Object?, Object?> map) {
    final channel = map['channel'] as Map<Object?, Object?>?;
    return StreamInfoItem(
      id: map['id'] as String? ?? '',
      title: map['title'] as String? ?? '',
      shortDescription: map['shortDescription'] as String?,
      channel: channel == null ? null : ChannelInfoItem.fromMap(channel),
      thumbnailGifUrl: map['thumbnailGifUrl'] as String?,
      publishedFromText: map['publishedFromText'] as String? ?? '',
      publishedAt: PublishTime.fromMap(map['publishedAt'] as Map<Object?, Object?>? ?? const {}),
      indexInPlaylist: map['indexInPlaylist'] as int?,
      durSeconds: map['durSeconds'] as int?,
      durText: map['durText'] as String?,
      viewsText: map['viewsText'] as String?,
      viewsCount: map['viewsCount'] as int?,
      percentageWatched: (map['percentageWatched'] as num?)?.toDouble(),
      liveThumbs: YoutiPieThumbnail.listFromMap(map['liveThumbs']),
      isUploaderVerified: map['isUploaderVerified'] as bool?,
      badges: (map['badges'] as List<Object?>?)?.cast<String>(),
      isActuallyShortContent: map['isActuallyShortContent'] as bool?,
    );
  }

  @override
  Map<String, Object?> toMap() => {
    'id': id,
    'title': title,
    'shortDescription': shortDescription,
    'channel': channel?.toMap(),
    'thumbnailGifUrl': thumbnailGifUrl,
    'publishedFromText': publishedFromText,
    'publishedAt': publishedAt.toMap(),
    'indexInPlaylist': indexInPlaylist,
    'durSeconds': durSeconds,
    'durText': durText,
    'viewsText': viewsText,
    'viewsCount': viewsCount,
    'percentageWatched': percentageWatched,
    'liveThumbs': liveThumbs.map((item) => item.toMap()).toList(),
    'isUploaderVerified': isUploaderVerified,
    'badges': badges,
    'isActuallyShortContent': isActuallyShortContent,
  };
}
