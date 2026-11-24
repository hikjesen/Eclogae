import '../channels/channel_info.dart';
import 'list_wrapper_base.dart';

class YoutiPieUserChannelsResult extends YoutiPieListWrapper<YoutiPieChannelInfo> with YoutiPieListSorterMixin<YoutiPieChannelInfo> {
  const YoutiPieUserChannelsResult({super.items = const [], super.cacheKey, super.continuation});
}
