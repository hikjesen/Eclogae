import '../../core/http.dart';
import '../map_serializable.dart';
import '../thumbnail.dart';
import '../videos/video_playability.dart';
import 'audio_stream.dart';
import 'caption.dart';
import 'endscreens/endscreen_item_base.dart';
import 'video_stream.dart';
import 'video_stream_info.dart';

class VideoStreamsResult extends MapSerializable {
  const VideoStreamsResult();

  String get videoId => '';
  InnertubeClients? get client => null;
  List<AudioStream> get audioStreams => const [];
  Map<String, AudioStream> get audioStreamsOrganizedByLanguage => const {};
  List<VideoStream> get videoStreams => const [];
  List<VideoStream> get mixedStreams => const [];
  List<Caption> get captions => const [];
  List<EndScreenItemBase> get endscreens => const [];
  VideoStreamInfo? get info => null;
  VideoPlayabilty get playability => const VideoPlayabilty();
  String? get hlsManifestUrl => null;
  String? get dashManifestUrl => null;
  String? get statsPlaybackUrl => null;
  String? get statsWatchtimeUrl => null;
  ({double loudnessDb})? get loudnessDBData => null;
  ({List<YoutiPieThumbnail> overlays})? get overlay => null;
  StreamFailureReport? get failureReport => null;
  bool hasExpired() => true;

  @override
  Map<String, Object?> toMap() => {};
}

class StreamFailureReport {
  const StreamFailureReport();
  String toText() => 'YouTube disabled in Namida LX build';
}
