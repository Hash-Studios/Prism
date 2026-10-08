// ignore_for_file: depend_on_referenced_packages

import 'dart:convert';
import 'dart:io';

import 'package:Prism/core/persistence/data_sources/feed_cache_local_data_source.dart';
import 'package:Prism/core/persistence/persistence_keys.dart';
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

  test('scopes older than 30 days are pruned on first load and newer ones stay', () async {
    final String oldKey = PersistenceKeys.cacheFeed('prism', 'old');
    final String newKey = PersistenceKeys.cacheFeed('prism', 'recent');
    File('${dir.path}/feed_cache.json').writeAsStringSync(
      jsonEncode(<String, Object?>{
        oldKey: _entry(DateTime.now().subtract(const Duration(days: 31))),
        newKey: _entry(DateTime.now().subtract(const Duration(days: 29))),
      }),
    );
    final source = FeedCacheLocalDataSource();

    expect(await source.read(source: 'prism', scope: 'old'), isNull);
    expect(await source.read(source: 'prism', scope: 'recent'), isNotNull);
  });
}
