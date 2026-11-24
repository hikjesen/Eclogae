import '../map_serializable.dart';
import 'codec_info.dart';

abstract class StreamBase extends MapSerializable {
  const StreamBase({
    required this.itag,
    required this.codecInfo,
    required this.bitrate,
    required this.sizeInBytes,
    required this.quality,
    this.lastModified,
    this.averageBitrate,
    this.duration,
    this.url,
    this.sig,
    this.nsig,
    this.requestedWithCookies = false,
  });

  final int itag, bitrate, sizeInBytes;
  final int? averageBitrate;
  final DateTime? lastModified;
  final CodecInfo codecInfo;
  final String quality;
  final String? url, sig, nsig;
  final Duration? duration;
  final bool requestedWithCookies;

  bool get isWebm => codecInfo.container == 'webm';

  Uri? buildUrl() => url == null ? null : Uri.tryParse(url!);

  String bitrateText() => '${bitrate ~/ 1000} kbps';

  @override
  Map<String, Object?> toMap() => {
    'itag': itag,
    'codecInfo': codecInfo.toMap(),
    'bitrate': bitrate,
    'sizeInBytes': sizeInBytes,
    'quality': quality,
    'lastModified': lastModified?.millisecondsSinceEpoch,
    'averageBitrate': averageBitrate,
    'duration': duration?.inMilliseconds,
    'url': url,
    'sig': sig,
    'nsig': nsig,
    'requestedWithCookies': requestedWithCookies,
  };
}
