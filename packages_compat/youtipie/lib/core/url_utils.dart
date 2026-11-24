export 'playlist_id_utils.dart';

abstract final class YTUrlUtils {
  static String buildVideoUrl(String id, {int? timestampSeconds}) => Uri.https(
    'www.youtube.com',
    '/watch',
    {'v': id, if (timestampSeconds != null) 't': '${timestampSeconds}s'},
  ).toString();

  static String buildChannelUrl(String id) => Uri.https('www.youtube.com', '/channel/$id').toString();

  static String buildPlaylistUrl(String id) => Uri.https('www.youtube.com', '/playlist', {'list': id}).toString();
}

extension YTStringUtils on String {
  static final _videoId = RegExp(r'^[A-Za-z0-9_-]{11}$');

  bool get isDummyVideoId => isEmpty || this == 'null' || contains(' ');

  bool isYTTitleFaulty() {
    if (isEmpty || _videoId.hasMatch(this)) return true;
    final host = Uri.tryParse(this)?.host.toLowerCase();
    return host == 'youtu.be' || host == 'youtube.com' || host?.endsWith('.youtube.com') == true;
  }
}
