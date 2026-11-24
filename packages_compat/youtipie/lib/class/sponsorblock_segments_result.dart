import 'sponsorblock_segment.dart';

class SponsorBlockSegmentsResult {
  const SponsorBlockSegmentsResult({this.segments = const [], this.videoDurationMS = 0});
  final List<SponsorBlockSegment> segments;
  final int videoDurationMS;
}
