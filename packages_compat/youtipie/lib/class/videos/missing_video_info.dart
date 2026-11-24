import '../publish_time.dart';
import 'video_result.dart';

class MissingVideoInfo {
  const MissingVideoInfo({
    required this.videoId,
    this.title,
    this.channelName,
    this.channelId,
    this.date = const PublishTime.unknown(),
    this.durSeconds,
    this.description,
    this.videoPage,
    this.sources = const [],
    this.subsource,
  });

  final String videoId;
  final String? title, channelName, channelId, description, subsource;
  final PublishTime date;
  final int? durSeconds;
  final YoutiPieVideoPageResult? videoPage;
  final List<Uri> sources;

  factory MissingVideoInfo.fromMap(Map<Object?, Object?> map) => MissingVideoInfo(
    videoId: map['videoId'] as String? ?? '',
    title: map['title'] as String?,
    channelName: map['channelName'] as String?,
    channelId: map['channelId'] as String?,
    date: PublishTime.fromMap(map['date'] as Map<Object?, Object?>? ?? const {}),
    durSeconds: map['durSeconds'] as int?,
    description: map['description'] as String?,
    sources: (map['sources'] as List<Object?>?)?.cast<String>().map(Uri.parse).toList() ?? const [],
    subsource: map['subsource'] as String?,
  );
}
