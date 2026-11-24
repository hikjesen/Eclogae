enum VideoPlayabiltyStatus { ok, unavailable }

class VideoPlayabilty {
  const VideoPlayabilty({this.status = VideoPlayabiltyStatus.unavailable, this.reason, this.messages});
  final VideoPlayabiltyStatus status;
  final String? reason;
  final List<String>? messages;
}
