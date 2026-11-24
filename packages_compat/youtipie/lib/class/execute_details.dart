enum CacheDecision { cacheOnly }

class ExecuteDetails {
  const ExecuteDetails.normal();
  const ExecuteDetails.forceRequest();
  const ExecuteDetails.cache(CacheDecision decision);

  static const kForceRequest = ExecuteDetails.forceRequest();

}
