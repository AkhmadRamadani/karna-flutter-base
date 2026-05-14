/// Defines how a repository resolves data between local and remote sources.
enum DataStrategy {
  /// Show cached data only. Hit network only if cache is empty.
  /// Best for: data that rarely changes, offline-heavy apps.
  localFirst,

  /// Show cached data immediately, then fetch fresh data from network
  /// and replace it. The caller gets notified twice (cache hit + network hit).
  /// Best for: feeds, dashboards, data that changes frequently.
  staleWhileRevalidate,

  /// Always fetch from network. Cache the result for offline fallback.
  /// Best for: real-time data, transactions, auth tokens.
  remoteFirst,
}
