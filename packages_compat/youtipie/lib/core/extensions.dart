import '../class/streams/codec_info.dart';
import '../class/streams/video_stream.dart';
import '../class/thumbnail.dart';

extension ThumbnailPickerExt on Iterable<YoutiPieThumbnail> {
  YoutiPieThumbnail? pick() => isEmpty ? null : first;
}

extension CodecInfoUtils on CodecInfo {
  String codecCleaned() => codec.split('.').first;

  bool isExperimentalCodec() => codecCleaned() == 'av01';

  String? codecIdentifierIfCustom() => switch (codecCleaned()) {
    'avc1' || 'mp4a' || 'vp9' || 'opus' || '' => null,
    final identifier => identifier,
  };
}

extension StreamFilterVideoUtils on List<VideoStream> {
  List<VideoStream> withoutWebmIfNeccessaryOrExperimentalCodecs({required bool allowExperimentalCodecs}) {
    final eligible = where((stream) => allowExperimentalCodecs || !stream.codecInfo.isExperimentalCodec()).toList();
    final nonWebm = eligible.where((stream) => !stream.isWebm).toList();
    return nonWebm.isEmpty ? eligible : nonWebm;
  }
}
