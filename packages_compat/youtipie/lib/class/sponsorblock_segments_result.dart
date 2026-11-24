import 'dart:math' as math;

import 'sponsorblock_segment.dart';

class SponsorBlockSegmentsResult {
  factory SponsorBlockSegmentsResult({List<SponsorBlockSegment> segments = const [], int videoDurationMS = 0}) {
    final ranges = <SponsorBlockSegment>[];
    SponsorBlockSegment? highlight;
    int? first;
    int? last;
    for (final segment in segments) {
      if (segment.category == 'poi_highlight') {
        highlight ??= segment;
        continue;
      }
      ranges.add(segment);
      first = first == null ? segment.segmentStartMS : math.min(first, segment.segmentStartMS);
      last = last == null ? segment.segmentEndMS : math.max(last, segment.segmentEndMS);
    }
    return SponsorBlockSegmentsResult._(ranges, videoDurationMS, highlight, first, last);
  }

  const SponsorBlockSegmentsResult._(this.segments, this.videoDurationMS, this.poi_highlight, this.firstMS, this.lastMS);

  final List<SponsorBlockSegment> segments;
  final int videoDurationMS;
  // ignore: non_constant_identifier_names
  final SponsorBlockSegment? poi_highlight;
  final int? firstMS, lastMS;
}
