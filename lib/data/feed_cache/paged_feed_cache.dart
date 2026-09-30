import 'dart:convert';

import 'package:Prism/core/persistence/data_sources/feed_cache_local_data_source.dart';
import 'package:Prism/core/utils/json_utils.dart';

/// Lower-case, underscore-separated form of [value] for feed cache scopes.
String feedCacheSlug(String value) => value.trim().toLowerCase().replaceAll(RegExp('[^a-z0-9]+'), '_');

/// Page cursor, "has more" flag and on-disk snapshot of a paged remote feed, keyed by category.
class PagedFeedCache {
  PagedFeedCache(this._local, {required this.source});

  static const int ttlHours = 6;

  final FeedCacheLocalDataSource _local;
  final String source;
  final Map<String, int> _pageNumbers = <String, int>{};
  final Map<String, bool> _hasMoreMap = <String, bool>{};

  int pageFor(String key) => _pageNumbers[key] ?? 1;

  bool hasMore(String key) => _hasMoreMap[key] ?? true;

  void reset(String key) {
    _pageNumbers[key] = 1;
    _hasMoreMap[key] = true;
  }

  /// Advances the cursor and stores [payload] (a DTO's `toJson()`) under [scope].
  Future<void> write(
    String key, {
    required String scope,
    required Map<String, dynamic> payload,
    required int nextPage,
    required bool hasMore,
  }) {
    _pageNumbers[key] = nextPage;
    _hasMoreMap[key] = hasMore;
    return _local.write(
      source: source,
      scope: scope,
      ttlHours: ttlHours,
      payload: <String, Object?>{'payload': jsonDecode(jsonEncode(payload)), 'nextPage': nextPage, 'hasMore': hasMore},
    );
  }

  /// Decodes the snapshot under [scope] with [decode]. A snapshot that decodes to nothing counts as a miss.
  /// A hit also restores the cursor saved with it, so paging continues from the cached page.
  Future<List<T>?> read<T>(
    String key, {
    required String scope,
    required List<T> Function(Map<String, dynamic> payload) decode,
  }) async {
    final FeedSnapshot? snapshot = await _local.read(source: source, scope: scope);
    final Map<String, dynamic> map = toJsonMap(snapshot?.payload);
    final Map<String, dynamic> payload = toJsonMap(map['payload']);
    if (payload.isEmpty) {
      return null;
    }
    final List<T> items = decode(payload);
    if (items.isEmpty) {
      return null;
    }
    _pageNumbers[key] = (map['nextPage'] as num?)?.toInt() ?? pageFor(key);
    _hasMoreMap[key] = map['hasMore'] == true;
    return items;
  }
}
