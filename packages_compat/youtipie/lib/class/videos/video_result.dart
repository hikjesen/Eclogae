import '../channels/channel_info.dart';
import '../map_serializable.dart';
import '../result_wrapper/comment_result.dart';
import '../result_wrapper/related_videos_result.dart';
import '../streams/stream_segments.dart';
import 'video_heat_map.dart';
import 'video_info.dart';

class YoutiPieVideoPageResult extends MapSerializable {
  const YoutiPieVideoPageResult({
    required this.videoId,
    this.videoInfo,
    this.channelInfo,
    this.relatedVideosResult,
    this.commentResult = const YoutiPieCommentResult(),
    this.streamSegments,
    this.heatMap,
    this.timestamp,
  });

  final String videoId;
  final YoutiPieVideoInfo? videoInfo;
  final YoutiPieChannelInfo? channelInfo;
  final YoutiPieRelatedVideosResult? relatedVideosResult;
  final YoutiPieCommentResult commentResult;
  final List<StreamSegment>? streamSegments;
  final List<YoutiPieVideoHeatMap>? heatMap;
  @override
  final DateTime? timestamp;

  @override
  Map<String, Object?> toMap() => {
    'videoId': videoId,
    if (timestamp != null) MapSerializable.timestampKey: timestamp!.millisecondsSinceEpoch,
  };
}
