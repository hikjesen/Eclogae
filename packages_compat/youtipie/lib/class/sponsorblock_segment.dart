class SponsorBlockSegment {
  const SponsorBlockSegment({required this.category, required this.uuid, required this.segmentStartMS, required this.segmentEndMS, this.actionType = 'skip'});

  final String category, uuid, actionType;
  final int segmentStartMS, segmentEndMS;
  int get durationMS => segmentEndMS - segmentStartMS;
}
