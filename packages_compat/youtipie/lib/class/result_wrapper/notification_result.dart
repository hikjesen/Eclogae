import '../stream_info_item/stream_info_item_notification.dart';
import 'list_wrapper_base.dart';

class YoutiPieNotificationResult extends YoutiPieListWrapper<StreamInfoItemNotification> {
  const YoutiPieNotificationResult({super.items = const [], super.cacheKey, super.continuation});
}
