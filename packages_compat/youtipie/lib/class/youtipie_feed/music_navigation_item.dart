import 'dart:ui';

import '../music/music_browse_endpoint.dart';
import 'yt_feed_base.dart';

class MusicNavigationItem extends YoutubeFeed {
  const MusicNavigationItem({required this.title, required this.endpoint, this.color});

  final String title;
  final YoutiPieMusicBrowseEndpoint endpoint;
  final Color? color;

  @override
  Map<String, Object?> toMap() => {'title': title, 'browseId': endpoint.browseId};
}
