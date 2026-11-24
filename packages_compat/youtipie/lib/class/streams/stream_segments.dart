class StreamSegment {
  const StreamSegment({required this.title, this.startSeconds});
  final String title;
  final int? startSeconds;
}

extension StreamSegmentLookup on List<StreamSegment> {
  StreamSegment? findByMillisecond(int positionMs) {
    StreamSegment? current;
    for (final segment in this) {
      final start = segment.startSeconds;
      if (start == null) continue;
      if (start * 1000 > positionMs + 1) break;
      current = segment;
    }
    return current;
  }
}
