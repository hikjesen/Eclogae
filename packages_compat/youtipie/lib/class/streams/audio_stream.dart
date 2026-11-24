import 'audio_track.dart';
import 'codec_info.dart';
import 'stream_base.dart';

class AudioStream extends StreamBase {
  const AudioStream({
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
    this.audioTrack,
  });

  final AudioTrack? audioTrack;

  factory AudioStream.fromMap(Map<Object?, Object?> map) {
    final modified = map['lastModified'] as int?;
    final duration = map['duration'] as int?;
    final track = map['audioTrack'] as Map<Object?, Object?>?;
    return AudioStream(
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
      audioTrack: track == null ? null : AudioTrack.fromMap(track),
    );
  }

  @override
  Map<String, Object?> toMap() => {
    ...super.toMap(),
    'audioTrack': audioTrack?.toMap(),
  };
}
