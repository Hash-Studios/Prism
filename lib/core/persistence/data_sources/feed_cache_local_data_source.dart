import 'dart:convert';

import 'package:Prism/core/offline/durable_json_store.dart';
import 'package:Prism/core/persistence/persistence_keys.dart';
import 'package:Prism/core/persistence/store_adapters/lazy_file_cache.dart';
import 'package:Prism/core/utils/json_utils.dart';
import 'package:injectable/injectable.dart';

class FeedSnapshot {
  const FeedSnapshot({required this.payload, required this.cachedAtUtc, required this.ttlHours});

  final Object? payload;
  final DateTime cachedAtUtc;
  final int ttlHours;

  bool get isStale => DateTime.now().toUtc().difference(cachedAtUtc) > Duration(hours: ttlHours);
}

@lazySingleton
class FeedCacheLocalDataSource {
  FeedCacheLocalDataSource({@ignoreParam DurableJsonStore? store, @ignoreParam LazyFileCache? legacyCache})
    : _store = store ?? DurableJsonStore('feed_cache'),
      _legacyCache = legacyCache ?? LazyFileCache('feed_cache');

  static const int maxSnapshots = 100;
  static const int maxSnapshotBytes = 512 * 1024;
  static const int maxTotalBytes = 4 * 1024 * 1024;

  final DurableJsonStore _store;
  final LazyFileCache _legacyCache;
  final Map<String, _FeedCacheRecord> _records = <String, _FeedCacheRecord>{};
  Future<void>? _loading;
  Future<void> _mutationTail = Future<void>.value();

  Future<FeedSnapshot?> read({required String source, required String scope}) => _serialize(() async {
    await _ensureLoaded();
    final String key = PersistenceKeys.cacheFeed(source, scope);
    Map<String, Object?>? raw = await _store.read(key);
    if (raw == null) {
      final Object? legacy = await _legacyCache.get(key);
      if (legacy is Map) {
        final Map<String, Object?> migrated = toJsonMap(legacy).cast<String, Object?>();
        if (_snapshotBytes(migrated) <= maxSnapshotBytes && _decode(migrated) != null) {
          raw = migrated;
          await _store.write(key, migrated);
          _record(key, migrated);
          await _evictOverBudget();
        }
      }
    }
    return _decode(raw);
  });

  Future<void> write({
    required String source,
    required String scope,
    required Object? payload,
    required int ttlHours,
  }) => _serialize(() async {
    await _ensureLoaded();
    final String key = PersistenceKeys.cacheFeed(source, scope);
    final Map<String, Object?> value = <String, Object?>{
      'cachedAtUtc': DateTime.now().toUtc().toIso8601String(),
      'ttlHours': ttlHours,
      'payload': payload,
    };
    final int bytes = _snapshotBytes(value);
    if (bytes > maxSnapshotBytes) {
      throw const DurableJsonStoreLimitException('The feed snapshot is larger than the feed cache budget.');
    }
    await _store.write(key, value);
    _record(key, value);
    await _evictOverBudget();
  });

  Future<void> clearAllFeedCaches() => _serialize(() async {
    await _ensureLoaded();
    await _store.clear();
    _records.clear();
    await _legacyCache.clearPrefix(PersistenceKeys.cacheFeedPrefix);
  });

  Future<T> _serialize<T>(Future<T> Function() action) {
    final Future<T> result = _mutationTail.then((_) => action());
    _mutationTail = result.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return result;
  }

  Future<void> _ensureLoaded() async {
    final Future<void> loading = _loading ??= _load();
    try {
      await loading;
    } catch (_) {
      if (identical(_loading, loading)) _loading = null;
      rethrow;
    }
  }

  Future<void> _load() async {
    final Map<String, Map<String, Object?>> stored = await _store.readAll();
    for (final MapEntry<String, Map<String, Object?>> entry in stored.entries) {
      if (!entry.key.startsWith(PersistenceKeys.cacheFeedPrefix)) continue;
      _record(entry.key, entry.value);
    }
    await _evictOverBudget();
  }

  void _record(String key, Map<String, Object?> value) {
    final FeedSnapshot? snapshot = _decode(value);
    if (snapshot == null) return;
    _records[key] = _FeedCacheRecord(cachedAtUtc: snapshot.cachedAtUtc, bytes: _snapshotBytes(value));
  }

  Future<void> _evictOverBudget() async {
    final List<MapEntry<String, _FeedCacheRecord>> oldestFirst = _records.entries.toList(growable: false)
      ..sort((a, b) => a.value.cachedAtUtc.compareTo(b.value.cachedAtUtc));
    var bytes = _records.values.fold<int>(0, (total, record) => total + record.bytes);
    var count = _records.length;
    for (final MapEntry<String, _FeedCacheRecord> entry in oldestFirst) {
      if (count <= maxSnapshots && bytes <= maxTotalBytes) break;
      if (_records.length == 1) break;
      await _store.delete(entry.key);
      _records.remove(entry.key);
      count--;
      bytes -= entry.value.bytes;
    }
  }

  FeedSnapshot? _decode(Map<String, Object?>? raw) {
    if (raw == null) return null;
    if (_snapshotBytes(raw) > maxSnapshotBytes) return null;
    final Map<String, dynamic> map = toJsonMap(raw);
    final DateTime? cachedAt = DateTime.tryParse(map['cachedAtUtc']?.toString() ?? '')?.toUtc();
    if (cachedAt == null) return null;
    final Object? ttlHours = map['ttlHours'];
    if (ttlHours != null && ttlHours is! num) return null;
    return FeedSnapshot(payload: map['payload'], cachedAtUtc: cachedAt, ttlHours: (ttlHours as num?)?.toInt() ?? 1);
  }

  int _snapshotBytes(Map<String, Object?> value) => utf8.encode(jsonEncode(value)).length;
}

class _FeedCacheRecord {
  const _FeedCacheRecord({required this.cachedAtUtc, required this.bytes});

  final DateTime cachedAtUtc;
  final int bytes;
}
