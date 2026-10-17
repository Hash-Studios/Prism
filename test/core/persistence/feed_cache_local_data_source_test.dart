// ignore_for_file: depend_on_referenced_packages

import 'dart:convert';
import 'dart:io';

import 'package:Prism/core/offline/durable_json_store.dart';
import 'package:Prism/core/persistence/data_sources/feed_cache_local_data_source.dart';
import 'package:Prism/core/persistence/persistence_keys.dart';
import 'package:Prism/data/feed_cache/paged_feed_cache.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class _FakePathProvider extends Fake with MockPlatformInterfaceMixin implements PathProviderPlatform {
  _FakePathProvider(this.path);

  final String path;

  @override
  Future<String?> getApplicationSupportPath() async => path;
}

Map<String, Object?> _entry(DateTime cachedAt, {int ttlHours = 6}) => <String, Object?>{
  'cachedAtUtc': cachedAt.toUtc().toIso8601String(),
  'ttlHours': ttlHours,
  'payload': <String, Object?>{'walls': <Object?>[]},
};

void main() {
  late Directory dir;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('feed_cache_local_test');
    PathProviderPlatform.instance = _FakePathProvider(dir.path);
  });

  tearDown(() => dir.deleteSync(recursive: true));

  test('a fresh snapshot is not stale', () async {
    final source = FeedCacheLocalDataSource();
    await source.write(source: 'prism', scope: 'all', payload: <String, Object?>{}, ttlHours: 6);

    final FeedSnapshot? snapshot = await source.read(source: 'prism', scope: 'all');

    expect(snapshot, isNotNull);
    expect(snapshot!.isStale, isFalse);
  });

  test('a snapshot past its TTL is still returned and is marked stale', () async {
    final String key = PersistenceKeys.cacheFeed('prism', 'all');
    File(
      '${dir.path}/feed_cache.json',
    ).writeAsStringSync(jsonEncode(<String, Object?>{key: _entry(DateTime.now().subtract(const Duration(hours: 7)))}));

    final FeedSnapshot? snapshot = await FeedCacheLocalDataSource().read(source: 'prism', scope: 'all');

    expect(snapshot, isNotNull);
    expect(snapshot!.isStale, isTrue);
    expect(snapshot.payload, isNotNull);
  });

  test('useful scopes older than 30 days are retained as stale fallback', () async {
    final String oldKey = PersistenceKeys.cacheFeed('prism', 'old');
    final String newKey = PersistenceKeys.cacheFeed('prism', 'recent');
    File('${dir.path}/feed_cache.json').writeAsStringSync(
      jsonEncode(<String, Object?>{
        oldKey: _entry(DateTime.now().subtract(const Duration(days: 31))),
        newKey: _entry(DateTime.now().subtract(const Duration(days: 29))),
      }),
    );
    final source = FeedCacheLocalDataSource();

    final FeedSnapshot? stale = await source.read(source: 'prism', scope: 'old');
    expect(stale, isNotNull);
    expect(stale!.isStale, isTrue);
    expect(await source.read(source: 'prism', scope: 'recent'), isNotNull);
  });

  test('oversized legacy snapshots are ignored and are not migrated', () async {
    final String key = PersistenceKeys.cacheFeed('prism', 'large-legacy');
    final Map<String, Object?> oversized = <String, Object?>{
      ..._entry(DateTime.now().subtract(const Duration(hours: 7))),
      'payload': <String, Object?>{
        'content': List<String>.filled(FeedCacheLocalDataSource.maxSnapshotBytes + 1, 'x').join(),
      },
    };
    File('${dir.path}/feed_cache.json').writeAsStringSync(jsonEncode(<String, Object?>{key: oversized}));
    final DurableJsonStore store = DurableJsonStore('feed_cache', directory: Directory('${dir.path}/durable'));

    final FeedSnapshot? snapshot = await FeedCacheLocalDataSource(
      store: store,
    ).read(source: 'prism', scope: 'large-legacy');

    expect(snapshot, isNull);
    expect(await store.read(key), isNull);
  });

  test('oversized durable snapshots are ignored without deleting the record', () async {
    final String key = PersistenceKeys.cacheFeed('prism', 'large-durable');
    final Map<String, Object?> oversized = <String, Object?>{
      ..._entry(DateTime.now()),
      'payload': <String, Object?>{
        'content': List<String>.filled(FeedCacheLocalDataSource.maxSnapshotBytes + 1, 'x').join(),
      },
    };
    final DurableJsonStore store = DurableJsonStore('feed_cache', directory: Directory('${dir.path}/durable'));
    await store.write(key, oversized);

    final FeedSnapshot? snapshot = await FeedCacheLocalDataSource(
      store: store,
    ).read(source: 'prism', scope: 'large-durable');

    expect(snapshot, isNull);
    expect(await store.read(key), oversized);
  });

  test('valid stale legacy snapshots are still returned and migrated', () async {
    final String key = PersistenceKeys.cacheFeed('prism', 'stale-legacy');
    final Map<String, Object?> stale = _entry(DateTime.now().subtract(const Duration(hours: 7)));
    File('${dir.path}/feed_cache.json').writeAsStringSync(jsonEncode(<String, Object?>{key: stale}));
    final DurableJsonStore store = DurableJsonStore('feed_cache', directory: Directory('${dir.path}/durable'));

    final FeedSnapshot? snapshot = await FeedCacheLocalDataSource(
      store: store,
    ).read(source: 'prism', scope: 'stale-legacy');

    expect(snapshot, isNotNull);
    expect(snapshot!.isStale, isTrue);
    expect(await store.read(key), stale);
  });

  test('paged cache JSON restores pages and cursor after datasource restart', () async {
    final PagedFeedCache first = PagedFeedCache(FeedCacheLocalDataSource(), source: 'test');
    await first.write(
      'nature',
      scope: 'nature',
      payload: <String, dynamic>{
        'items': <String>['first'],
      },
      nextPage: 2,
      hasMore: true,
    );
    await first.write(
      'nature',
      scope: 'nature',
      payload: <String, dynamic>{
        'items': <String>['second'],
      },
      nextPage: 3,
      hasMore: false,
      append: true,
    );

    final PagedFeedCache restarted = PagedFeedCache(FeedCacheLocalDataSource(), source: 'test');
    final List<String>? items = await restarted.read<String>(
      'nature',
      scope: 'nature',
      decode: (payload) => ((payload['items'] as List?) ?? const <Object?>[]).cast<String>(),
    );

    expect(items, <String>['first', 'second']);
    expect((restarted.pageFor('nature'), restarted.hasMore('nature')), (3, false));
  });
}
