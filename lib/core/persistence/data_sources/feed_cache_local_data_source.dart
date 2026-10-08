import 'package:Prism/core/persistence/persistence_keys.dart';
import 'package:Prism/core/persistence/store_adapters/lazy_file_cache.dart';
import 'package:Prism/core/utils/json_utils.dart';
import 'package:injectable/injectable.dart';

class FeedSnapshot {
  const FeedSnapshot({required this.payload, required this.cachedAtUtc, required this.ttlHours});

  final Object? payload;
  final DateTime cachedAtUtc;
  final int ttlHours;

  /// True once the snapshot is older than its TTL. A stale snapshot is still the offline fallback, so reads return it.
  bool get isStale => DateTime.now().toUtc().difference(cachedAtUtc) > Duration(hours: ttlHours);
}

/// Feed scopes the user has not opened for this long are removed when the cache first loads.
const Duration feedCacheMaxAge = Duration(days: 30);

bool _isAbandonedFeedScope(String key, Object? value) {
  if (value is! Map) return false;
  final DateTime? cachedAt = DateTime.tryParse((value['cachedAtUtc'] as String?) ?? '')?.toUtc();
  return cachedAt != null && DateTime.now().toUtc().difference(cachedAt) > feedCacheMaxAge;
}

@lazySingleton
class FeedCacheLocalDataSource {
  FeedCacheLocalDataSource();

  final LazyFileCache _cache = LazyFileCache('feed_cache', pruneOnLoad: _isAbandonedFeedScope);

  Future<FeedSnapshot?> read({required String source, required String scope}) async {
    final raw = await _cache.get(PersistenceKeys.cacheFeed(source, scope));
    if (raw is! Map) {
      return null;
    }
    final map = toJsonMap(raw);
    final cachedAt = DateTime.tryParse((map['cachedAtUtc'] as String?) ?? '')?.toUtc();
    if (cachedAt == null) {
      return null;
    }
    return FeedSnapshot(payload: map['payload'], cachedAtUtc: cachedAt, ttlHours: (map['ttlHours'] as int?) ?? 1);
  }

  Future<void> write({required String source, required String scope, required Object? payload, required int ttlHours}) {
    return _cache.set(PersistenceKeys.cacheFeed(source, scope), <String, Object?>{
      'cachedAtUtc': DateTime.now().toUtc().toIso8601String(),
      'ttlHours': ttlHours,
      'payload': payload,
    });
  }

  Future<void> clearAllFeedCaches() {
    return _cache.clearPrefix(PersistenceKeys.cacheFeedPrefix);
  }
}
