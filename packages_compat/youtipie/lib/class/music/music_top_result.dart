import '../youtipie_feed/yt_feed_base.dart';

class YoutiPieMusicTopResult {
  const YoutiPieMusicTopResult({required this.item, required this.subtitle, this.items = const []});

  final YoutubeFeed item;
  final String subtitle;
  final List<YoutubeFeed> items;
}
