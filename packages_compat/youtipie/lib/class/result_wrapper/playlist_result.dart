import 'package:nampack/reactive/reactive.dart';

import '../../core/enum.dart';
import '../youtipie_feed/channel_info_item.dart';
import '../youtipie_feed/playlist_basic_info.dart';
import 'playlist_result_base.dart';

class YoutiPiePlaylistResult extends YoutiPiePlaylistResultBase {
  const YoutiPiePlaylistResult({required this.info, super.items = const [], super.cacheKey, super.continuation}) : super(basicInfo: info);

  final HostedPlaylistInfo info;
  String get playlistId => info.id;
}

class HostedPlaylistInfo extends PlaylistBasicInfo {
  HostedPlaylistInfo({
    required super.id,
    required super.title,
    super.videosCountText,
    super.videosCount,
    super.thumbnails,
    this.description,
    this.uploader,
    this.privacy,
    this.viewsCount,
    this.viewsCountText,
  });

  final String? description, viewsCountText;
  final ChannelInfoItem? uploader;
  final PlaylistPrivacy? privacy;
  final int? viewsCount;
  final isInLibrary = Rxn<bool>();
  final hostedParams = (addNewVideosToTop: Rxn<bool>(),);
}
