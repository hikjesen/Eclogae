import '../map_serializable.dart';
import '../publish_time.dart';
import '../thumbnail.dart';

class VideoStreamInfo extends MapSerializable {
  const VideoStreamInfo({
    required this.id,
    required this.title,
    this.durSeconds,
    this.keywords = const [],
    this.channelName,
    this.channelId,
    this.description,
    this.thumbnails = const [],
    this.viewsCount,
    this.isPrivate,
    this.isUnlisted,
    this.isLiveNow,
    this.isLiveContent,
    this.category,
    this.publishDate = const PublishTime.unknown(),
    this.uploadDate = const PublishTime.unknown(),
  });

  final String id, title;
  final String? channelName, channelId, description, category;
  final int? durSeconds, viewsCount;
  final List<String> keywords;
  final List<YoutiPieThumbnail> thumbnails;
  final bool? isPrivate, isUnlisted, isLiveNow, isLiveContent;
  final PublishTime publishDate, uploadDate;

  String? get availableDescription => description;
  PublishTime get publishedAt => publishDate.date != null ? publishDate : uploadDate;

  static VideoStreamInfo merge(String id, VideoStreamInfo cache, VideoStreamInfo streams) => VideoStreamInfo(
    id: id,
    title: streams.title.isEmpty ? cache.title : streams.title,
    durSeconds: streams.durSeconds ?? cache.durSeconds,
    keywords: streams.keywords,
    channelName: streams.channelName ?? cache.channelName,
    channelId: streams.channelId ?? cache.channelId,
    description: streams.description ?? cache.description,
    thumbnails: streams.thumbnails.isEmpty ? cache.thumbnails : streams.thumbnails,
    viewsCount: streams.viewsCount ?? cache.viewsCount,
    isPrivate: streams.isPrivate,
    isUnlisted: streams.isUnlisted,
    isLiveNow: streams.isLiveNow,
    isLiveContent: streams.isLiveContent,
    category: streams.category,
    publishDate: streams.publishDate.date != null ? streams.publishDate : cache.publishDate,
    uploadDate: streams.uploadDate.date != null ? streams.uploadDate : cache.uploadDate,
  );

  factory VideoStreamInfo.fromMap(Map<Object?, Object?> map) => VideoStreamInfo(
    id: map['id'] as String? ?? '',
    title: map['title'] as String? ?? '',
    durSeconds: map['durSeconds'] as int?,
    keywords: (map['keywords'] as List<Object?>?)?.cast<String>() ?? const [],
    channelName: map['channelName'] as String?,
    channelId: map['channelId'] as String?,
    description: map['description'] as String?,
    thumbnails: YoutiPieThumbnail.listFromMap(map['thumbnails']),
    viewsCount: map['viewsCount'] as int?,
    isPrivate: map['isPrivate'] as bool?,
    isUnlisted: map['isUnlisted'] as bool?,
    isLiveNow: map['isLiveNow'] as bool?,
    isLiveContent: map['isLiveContent'] as bool?,
    category: map['category'] as String?,
    publishDate: PublishTime.fromMap(map['publishDate'] as Map<Object?, Object?>? ?? const {}),
    uploadDate: PublishTime.fromMap(map['uploadDate'] as Map<Object?, Object?>? ?? const {}),
  );

  @override
  Map<String, Object?> toMap() => {
    'id': id,
    'title': title,
    'durSeconds': durSeconds,
    'keywords': keywords,
    'channelName': channelName,
    'channelId': channelId,
    'description': description,
    'thumbnails': thumbnails.map((item) => item.toMap()).toList(),
    'viewsCount': viewsCount,
    'isPrivate': isPrivate,
    'isUnlisted': isUnlisted,
    'isLiveNow': isLiveNow,
    'isLiveContent': isLiveContent,
    'category': category,
    'publishDate': publishDate.toMap(),
    'uploadDate': uploadDate.toMap(),
  };
}
