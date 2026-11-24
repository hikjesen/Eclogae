enum YoutiPieSection { streamInfoItem, videoStreams, missingInfo }

class CacheDetailsBase {
  const CacheDetailsBase(YoutiPieSection section, String? key, String? Function() accountId);

  void loadEverythingExtractedSync(List<String> paths, void Function(String, List<Object?>) onRow) {}
  void loadEverythingSync(void Function(Map<String, dynamic>) onRow) {}
  List<Map<String, dynamic>> readAllMapsSync(List<String> keys) => const [];
  void close() {}
}

class CacheDetails<T> {
  const CacheDetails();

  // The offline backend has no cache entries to age or read.
  CacheDetails<T> withMaxPeriod({required Duration allowedDuration}) => this;
  (T, bool)? readSyncRaw() => null;

  Future<T?> read() async => null;
  T? readSync() => null;
}
