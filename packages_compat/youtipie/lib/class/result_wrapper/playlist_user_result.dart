import '../youtipie_feed/playlist_info_item_user.dart';
import 'list_wrapper_base.dart';

class YoutiPieUserPlaylistsResult extends YoutiPieListWrapper<PlaylistInfoItemUser> with YoutiPieListSorterMixin<PlaylistInfoItemUser> {
  const YoutiPieUserPlaylistsResult({super.items = const [], super.cacheKey, super.continuation});
}
