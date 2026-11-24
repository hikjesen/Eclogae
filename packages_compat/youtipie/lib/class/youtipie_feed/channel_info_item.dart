import '../thumbnail.dart';
import 'yt_feed_base.dart';

class ChannelInfoItem extends YoutubeFeed {
  const ChannelInfoItem({required this.id, this.handler, this.title, this.thumbnails = const []});
  const ChannelInfoItem.anonymous() : this(id: '');

  final String id;
  final String? handler, title;
  final List<YoutiPieThumbnail> thumbnails;

  factory ChannelInfoItem.fromMap(Map<Object?, Object?> map) => ChannelInfoItem(
    id: map['id'] as String? ?? '',
    handler: map['handler'] as String?,
    title: map['title'] as String?,
    thumbnails: YoutiPieThumbnail.listFromMap(map['thumbnails']),
  );

  @override
  Map<String, Object?> toMap() => {
    'id': id,
    'handler': handler,
    'title': title,
    'thumbnails': thumbnails.map((item) => item.toMap()).toList(),
  };
}
