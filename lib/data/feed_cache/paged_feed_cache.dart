import 'dart:convert';
import 'dart:math' show max;

import 'package:Prism/core/offline/durable_json_store.dart';
import 'package:Prism/core/persistence/data_sources/feed_cache_local_data_source.dart';
import 'package:Prism/core/utils/json_utils.dart';

/// Lower-case, underscore-separated form of [value] for feed cache scopes.
String feedCacheSlug(String value) => value.trim().toLowerCase().replaceAll(RegExp('[^a-z0-9]+'), '_');

/// Page cursor, "has more" flag and on-disk snapshot of a paged remote feed, keyed by category.
class PagedFeedCache {
  PagedFeedCache(this._local, {required this.source});

  static const int ttlHours = 6;
  static const int _maxPages = 8;
  static const int _maxItems = 240;
  static const int _maxSnapshotBytes = FeedCacheLocalDataSource.maxSnapshotBytes;

  final FeedCacheLocalDataSource _local;
  final String source;
  final Map<String, int> _pageNumbers = <String, int>{};
  final Map<String, bool> _hasMoreMap = <String, bool>{};

  int pageFor(String key) => _pageNumbers[key] ?? 1;

  bool hasMore(String key) => _hasMoreMap[key] ?? true;

  /// Moves the cursor without touching the on-disk snapshot. Used for pages after the first.
  void advance(String key, {required int nextPage, required bool hasMore}) {
    _pageNumbers[key] = nextPage;
    _hasMoreMap[key] = hasMore;
  }

  /// Advances the cursor and stores [payload] (a DTO's `toJson()`) under [scope].
  /// [isCurrent] rejects invalidated requests after an append's cache read and before committing the cursor.
  Future<void> write(
    String key, {
    required String scope,
    required Map<String, dynamic> payload,
    required int nextPage,
    required bool hasMore,
    bool append = false,
    bool Function()? isCurrent,
  }) async {
    final List<Object?> pages = <Object?>[];
    if (append) {
      final FeedSnapshot? snapshot = await _local.read(source: source, scope: scope);
      final Map<String, dynamic> cached = toJsonMap(snapshot?.payload);
      final Object? previousPages = cached['pages'];
      if (previousPages is List) {
        pages.addAll(previousPages);
      } else if (cached['payload'] is Map) {
        pages.add(cached['payload']);
      }
    }
    if (isCurrent != null && !isCurrent()) return;
    pages.add(jsonDecode(jsonEncode(payload)));
    while (pages.length > _maxPages ||
        _itemCount(pages) > _maxItems ||
        _snapshotBytes(pages, nextPage, hasMore) > _maxSnapshotBytes) {
      if (pages.length > 1) {
        pages.removeAt(0);
        continue;
      }
      final Object? trimmedPage = _trimPage(pages.single);
      if (trimmedPage == null) {
        throw const DurableJsonStoreLimitException('The feed page is larger than the feed cache budget.');
      }
      pages[0] = trimmedPage;
    }
    await _local.write(
      source: source,
      scope: scope,
      ttlHours: ttlHours,
      payload: <String, Object?>{'pages': pages, 'nextPage': nextPage, 'hasMore': hasMore},
    );
    if (isCurrent == null || isCurrent()) advance(key, nextPage: nextPage, hasMore: hasMore);
  }

  int _snapshotBytes(List<Object?> pages, int nextPage, bool hasMore) => utf8
      .encode(
        jsonEncode(<String, Object?>{
          'cachedAtUtc': DateTime.now().toUtc().toIso8601String(),
          'ttlHours': ttlHours,
          'payload': <String, Object?>{'pages': pages, 'nextPage': nextPage, 'hasMore': hasMore},
        }),
      )
      .length;

  Object? _trimPage(Object? page) {
    final Map<String, dynamic> candidate = toJsonMap(page);
    final List<List<Object?>> lists = candidate.values.whereType<List<Object?>>().toList(growable: false);
    if (lists.isEmpty || lists.every((list) => list.isEmpty)) return null;
    final List<Object?> largest = lists.reduce((a, b) => a.length >= b.length ? a : b);
    final int removeCount = largest.length > 1 ? largest.length ~/ 2 : 1;
    largest.removeRange(0, removeCount);
    return candidate;
  }

  int _itemCount(List<Object?> pages) => pages.fold<int>(
    0,
    (total, page) => total + toJsonMap(page).values.whereType<List>().map((items) => items.length).fold<int>(0, max),
  );

  /// Decodes the snapshot under [scope] with [decode]. A snapshot that decodes to nothing counts as a miss.
  /// A hit also restores the cursor saved with it, so paging continues from the cached page.
  Future<List<T>?> read<T>(
    String key, {
    required String scope,
    required List<T> Function(Map<String, dynamic> payload) decode,
  }) async {
    final FeedSnapshot? snapshot = await _local.read(source: source, scope: scope);
    final Map<String, dynamic> map = toJsonMap(snapshot?.payload);
    final Object? rawPages = map['pages'];
    final Map<String, dynamic> legacyPayload = toJsonMap(map['payload']);
    final List<Map<String, dynamic>> pages = rawPages is List
        ? rawPages.map(toJsonMap).where((page) => page.isNotEmpty).toList(growable: false)
        : legacyPayload.isEmpty
        ? <Map<String, dynamic>>[]
        : <Map<String, dynamic>>[legacyPayload];
    if (pages.isEmpty) return null;
    final List<T> items = <T>[];
    for (final Map<String, dynamic> page in pages) {
      final decoded = decode(page);
      if (decoded.isNotEmpty) items.addAll(decoded);
    }
    if (items.isEmpty) {
      return null;
    }
    _pageNumbers[key] = (map['nextPage'] as num?)?.toInt() ?? pageFor(key);
    _hasMoreMap[key] = map['hasMore'] == true;
    return items;
  }
}
