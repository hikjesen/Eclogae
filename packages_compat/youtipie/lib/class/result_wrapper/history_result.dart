import '../chunks/history_chunk.dart';
import 'list_wrapper_base.dart';

class YoutiPieHistoryResult extends YoutiPieListWrapper<YoutiPieHistoryChunk> {
  const YoutiPieHistoryResult({super.items = const [], super.cacheKey, super.continuation});
}
