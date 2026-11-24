import '../chunks/history_chunk.dart';
import 'list_wrapper_base.dart';

class YoutiPieSearchResult extends YoutiPieListWrapper<YoutiPieHistoryChunk> {
  const YoutiPieSearchResult({super.items = const [], super.cacheKey, super.continuation, this.correctedQuery = const []});

  final List<({String text, bool corrected})> correctedQuery;
}
