import 'package:Prism/core/persistence/local_store.dart';
import 'package:Prism/core/persistence/persistence_keys.dart';
import 'package:injectable/injectable.dart';

class FeedSnapshot {
  const FeedSnapshot({required this.payload, required this.cachedAtUtc, required this.ttlHours});

  final Object? payload;
  final DateTime cachedAtUtc;
  final int ttlHours;

  bool get isExpired => DateTime.now().toUtc().isAfter(cachedAtUtc.add(Duration(hours: ttlHours)));
}

@lazySingleton
class FeedCacheLocalDataSource {
  FeedCacheLocalDataSource(this._store);

  final LocalStore _store;

  FeedSnapshot? read({required String source, required String scope}) {
    final raw = _store.get(PersistenceKeys.cacheFeed(source, scope));
    if (raw is! Map) {
      return null;
    }
    final map = raw.map<String, dynamic>((key, value) => MapEntry(key.toString(), value));
    final cachedAt = DateTime.tryParse((map['cachedAtUtc'] as String?) ?? '')?.toUtc();
    if (cachedAt == null) {
      return null;
    }
    return FeedSnapshot(payload: map['payload'], cachedAtUtc: cachedAt, ttlHours: (map['ttlHours'] as int?) ?? 1);
  }

  Future<void> write({required String source, required String scope, required Object? payload, required int ttlHours}) {
    return _store.set(PersistenceKeys.cacheFeed(source, scope), <String, Object?>{
      'cachedAtUtc': DateTime.now().toUtc().toIso8601String(),
      'ttlHours': ttlHours,
      'payload': payload,
    });
  }

  Future<void> clearAllFeedCaches() {
    return _store.clearPrefix(PersistenceKeys.cacheFeedPrefix);
  }
}
