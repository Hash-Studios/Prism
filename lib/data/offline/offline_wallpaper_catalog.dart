import 'dart:async';
import 'dart:convert';

import 'package:Prism/core/offline/durable_json_store.dart';
import 'package:Prism/core/user_blocks/blocked_creators_filter.dart';
import 'package:Prism/core/utils/json_utils.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/features/category_feed/data/feed_item_cache_codec.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/user_blocks/domain/repositories/user_block_repository.dart';
import 'package:get_it/get_it.dart';

class OfflineWallpaperCatalog {
  OfflineWallpaperCatalog({DurableJsonStore? store, FutureOr<Set<String>> Function()? blockedEmails})
    : _store = store ?? DurableJsonStore('wallpaper_catalog'),
      _blockedEmails = blockedEmails ?? _currentBlockedEmails;

  static final OfflineWallpaperCatalog _instance = OfflineWallpaperCatalog();
  static OfflineWallpaperCatalog get instance => _instance;

  static const int maxRecords = 500;
  static const int maxBytes = 2 * 1024 * 1024;

  final DurableJsonStore _store;
  final FutureOr<Set<String>> Function() _blockedEmails;
  final Map<String, _CatalogRecord> _records = <String, _CatalogRecord>{};
  Future<void>? _loading;
  Future<void> _mutationTail = Future<void>.value();

  Future<void> remember(Iterable<FeedItemEntity> items) => _serialize(() async {
    await _ensureLoaded();
    for (final FeedItemEntity item in items) {
      final String key = _key(item.source, item.id);
      if (item.id.trim().isEmpty || !_isPublicCatalogSource(item.source)) continue;
      final DateTime savedAt = DateTime.now().toUtc();
      final Map<String, Object?> itemJson = encodeFeedItem(item);
      final Map<String, Object?> value = <String, Object?>{'savedAtUtc': savedAt.toIso8601String(), 'item': itemJson};
      final _CatalogRecord? existing = _records[key];
      if (existing != null && jsonEncode(encodeFeedItem(existing.item)) == jsonEncode(itemJson)) continue;
      await _store.write(key, value);
      _records[key] = _CatalogRecord(item: item, savedAtUtc: savedAt, bytes: utf8.encode(jsonEncode(value)).length);
      await _evictOverBudget();
    }
  });

  Future<FeedItemEntity?> find(WallpaperSource source, String id) async {
    await _ensureLoaded();
    if (!_isPublicCatalogSource(source) || id.trim().isEmpty) return null;
    final FeedItemEntity? item = _records[_key(source, id)]?.item;
    return item != null && !BlockedCreatorsFilter.hidesFeedItem(item, await _blockedEmails()) ? item : null;
  }

  Future<List<FeedItemEntity>> search(String query, {int limit = 100}) async {
    await _ensureLoaded();
    final String normalizedQuery = query.trim().toLowerCase();
    if (normalizedQuery.isEmpty || limit <= 0) return const <FeedItemEntity>[];
    final List<_CatalogRecord> matches =
        _records.values.where((record) => record.searchText.contains(normalizedQuery)).toList(growable: false)
          ..sort((a, b) => b.savedAtUtc.compareTo(a.savedAtUtc));
    final Set<String> blocked = await _blockedEmails();
    return matches
        .where((record) => !BlockedCreatorsFilter.hidesFeedItem(record.item, blocked))
        .take(limit)
        .map((record) => record.item)
        .toList(growable: false);
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
      try {
        final Map<String, dynamic> value = entry.value;
        final Map<String, dynamic> encodedItem = _jsonMap(value['item']);
        final FeedItemEntity? item = decodeFeedItem(encodedItem);
        final DateTime? savedAt = DateTime.tryParse(value['savedAtUtc']?.toString() ?? '')?.toUtc();
        if (item == null || savedAt == null || !_isPublicCatalogSource(item.source)) continue;
        final String expectedKey = _key(item.source, item.id);
        if (entry.key != expectedKey) continue;
        _records[entry.key] = _CatalogRecord(
          item: item,
          savedAtUtc: savedAt,
          bytes: utf8.encode(jsonEncode(entry.value)).length,
        );
      } on FormatException {
        continue;
      } on TypeError {
        continue;
      }
    }
    await _evictOverBudget();
  }

  Future<void> _evictOverBudget() async {
    final List<MapEntry<String, _CatalogRecord>> oldestFirst = _records.entries.toList(growable: false)
      ..sort((a, b) => a.value.savedAtUtc.compareTo(b.value.savedAtUtc));
    var bytes = _records.values.fold<int>(0, (total, record) => total + record.bytes);
    var count = _records.length;
    for (final MapEntry<String, _CatalogRecord> entry in oldestFirst) {
      if (count <= maxRecords && bytes <= maxBytes) break;
      if (_records.length == 1) break;
      await _store.delete(entry.key);
      _records.remove(entry.key);
      count--;
      bytes -= entry.value.bytes;
    }
  }

  Future<void> _serialize(Future<void> Function() action) {
    final Future<void> result = _mutationTail.then((_) => action());
    _mutationTail = result.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return result;
  }

  static Future<Set<String>> _currentBlockedEmails() => GetIt.instance.isRegistered<UserBlockRepository>()
      ? GetIt.instance<UserBlockRepository>().getBlockedCreatorEmails(waitForInitialLoad: true)
      : Future<Set<String>>.value(const <String>{});

  static bool _isPublicCatalogSource(WallpaperSource source) =>
      source == WallpaperSource.prism || source == WallpaperSource.wallhaven || source == WallpaperSource.pexels;

  static String _key(WallpaperSource source, String id) => '${source.wireValue}/${Uri.encodeComponent(id.trim())}';

  static Map<String, dynamic> _jsonMap(Object? value) => toJsonMap(value);
}

class _CatalogRecord {
  _CatalogRecord({required this.item, required this.savedAtUtc, required this.bytes})
    : searchText = _searchableText(item);

  final FeedItemEntity item;
  final DateTime savedAtUtc;
  final int bytes;
  final String searchText;

  static String _searchableText(FeedItemEntity item) {
    final List<String> terms = <String>[
      item.id,
      item.source.wireValue,
      item.wallpaperCore.authorName ?? '',
      item.wallpaperCore.category ?? '',
      item.wallpaperCore.resolution ?? '',
      ...item.when(
        prism: (_, wall) => <String>[wall.title ?? '', ...?wall.collections, ...?wall.tags, ...?wall.colors],
        wallhaven: (_, wall) => <String>[...?wall.tags, ...?wall.colors],
        pexels: (_, wall) => <String>[wall.photographer ?? ''],
      ),
    ];
    return terms.join(' ').toLowerCase();
  }
}
