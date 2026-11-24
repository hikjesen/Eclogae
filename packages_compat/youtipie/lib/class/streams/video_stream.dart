import 'codec_info.dart';
import 'stream_base.dart';

class VideoStream extends StreamBase {
  const VideoStream({
    required super.itag,
    required super.codecInfo,
    required super.bitrate,
    required super.sizeInBytes,
    required super.quality,
    super.lastModified,
    super.averageBitrate,
    super.duration,
    super.url,
    super.sig,
    super.nsig,
    super.requestedWithCookies,
    required this.width,
    required this.height,
    required this.fps,
    required this.qualityLabel,
  });

  final int width, height, fps;
  final String qualityLabel;

  factory VideoStream.fromMap(Map<Object?, Object?> map) {
    final modified = map['lastModified'] as int?;
    final duration = map['duration'] as int?;
    return VideoStream(
      itag: map['itag'] as int? ?? 0,
      codecInfo: CodecInfo.fromMap(map['codecInfo'] as Map<Object?, Object?>? ?? const {}),
      bitrate: map['bitrate'] as int? ?? 0,
      sizeInBytes: map['sizeInBytes'] as int? ?? 0,
      quality: map['quality'] as String? ?? '',
      lastModified: modified == null ? null : DateTime.fromMillisecondsSinceEpoch(modified),
      averageBitrate: map['averageBitrate'] as int?,
      duration: duration == null ? null : Duration(milliseconds: duration),
      url: map['url'] as String?,
      sig: map['sig'] as String?,
      nsig: map['nsig'] as String?,
      requestedWithCookies: map['requestedWithCookies'] as bool? ?? false,
      width: map['width'] as int? ?? 0,
      height: map['height'] as int? ?? 0,
      fps: map['fps'] as int? ?? 0,
      qualityLabel: map['qualityLabel'] as String? ?? '',
    );
  }

  @override
  Map<String, Object?> toMap() => {
    ...super.toMap(),
    'width': width,
    'height': height,
    'fps': fps,
    'qualityLabel': qualityLabel,
  };
}
