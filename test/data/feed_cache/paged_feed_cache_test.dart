import 'dart:async';
import 'dart:convert';

import 'package:Prism/data/feed_cache/paged_feed_cache.dart';
import 'package:Prism/core/persistence/data_sources/feed_cache_local_data_source.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_feed_cache_local_data_source.dart';

void main() {
  test('an invalidated append cannot write or advance after its cache read completes', () async {
    final local = _DelayedReadCache();
    final old = PagedFeedCache(local, source: 'test');
    await old.write('A', scope: 'A', payload: <String, dynamic>{'id': 1}, nextPage: 2, hasMore: true);
    bool current = true;
    local.hold = true;
    final append = old.write(
      'A',
      scope: 'A',
      payload: <String, dynamic>{'id': 2},
      nextPage: 3,
      hasMore: false,
      append: true,
      isCurrent: () => current,
    );
    await local.started.future;
    current = false;
    final fresh = PagedFeedCache(local, source: 'test');
    await fresh.write('A', scope: 'A', payload: <String, dynamic>{'id': 10}, nextPage: 2, hasMore: true);
    local.release.complete();
    await append;
    expect(old.pageFor('A'), 2);
    expect(old.hasMore('A'), isTrue);
    final snapshot = local.snapshots['test/A']!.payload! as Map;
    expect(snapshot['pages'], <Object>[
      <String, dynamic>{'id': 10},
    ]);
    expect(snapshot['nextPage'], 2);
  });
  test('feedCacheSlug lower-cases and joins runs of other characters with one underscore', () {
    expect(feedCacheSlug('  Dark & Moody!! '), 'dark_moody_');
    expect(feedCacheSlug('color: ff0000'), 'color_ff0000');
  });

  test('cursor starts at page 1 with more pages and a successful write advances it', () async {
    final cache = PagedFeedCache(FakeFeedCacheLocalDataSource(), source: 'test');

    expect(cache.pageFor('nature'), 1);
    expect(cache.hasMore('nature'), isTrue);

    await cache.write('nature', scope: 'nature', payload: <String, dynamic>{'n': 1}, nextPage: 3, hasMore: false);
    expect((cache.pageFor('nature'), cache.hasMore('nature')), (3, false));
  });

  test('advance moves the cursor without writing a snapshot', () {
    final local = FakeFeedCacheLocalDataSource();
    final cache = PagedFeedCache(local, source: 'test');

    cache.advance('nature', nextPage: 5, hasMore: false);

    expect((cache.pageFor('nature'), cache.hasMore('nature')), (5, false));
    expect(local.snapshots, isEmpty);
  });

  test('read returns the decoded snapshot and restores the cursor saved with it', () async {
    final local = FakeFeedCacheLocalDataSource();
    await PagedFeedCache(local, source: 'test').write(
      'nature',
      scope: 'nature',
      payload: <String, dynamic>{
        'ids': <int>[1, 2],
      },
      nextPage: 4,
      hasMore: false,
    );

    final fresh = PagedFeedCache(local, source: 'test');
    final ids = await fresh.read<int>(
      'nature',
      scope: 'nature',
      decode: (payload) => (payload['ids'] as List).cast<int>(),
    );

    expect(ids, <int>[1, 2]);
    expect((fresh.pageFor('nature'), fresh.hasMore('nature')), (4, false));
  });

  test('later pages are retained with the first page and cursor after restart', () async {
    final local = FakeFeedCacheLocalDataSource();
    final first = PagedFeedCache(local, source: 'test');
    await first.write(
      'nature',
      scope: 'nature',
      payload: <String, dynamic>{
        'ids': <int>[1, 2],
      },
      nextPage: 2,
      hasMore: true,
    );
    await first.write(
      'nature',
      scope: 'nature',
      payload: <String, dynamic>{
        'ids': <int>[3, 4],
      },
      nextPage: 3,
      hasMore: false,
      append: true,
    );

    final restarted = PagedFeedCache(local, source: 'test');
    final ids = await restarted.read<int>(
      'nature',
      scope: 'nature',
      decode: (payload) => (payload['ids'] as List).cast<int>(),
    );

    expect(ids, <int>[1, 2, 3, 4]);
    expect((restarted.pageFor('nature'), restarted.hasMore('nature')), (3, false));
  });

  test('oversized pages are trimmed to the durable snapshot limit before advancing the cursor', () async {
    final local = FakeFeedCacheLocalDataSource();
    final cache = PagedFeedCache(local, source: 'test');

    await cache.write(
      'nature',
      scope: 'nature',
      payload: <String, dynamic>{'items': List<String>.filled(100, 'x' * 9000)},
      nextPage: 2,
      hasMore: true,
    );

    final snapshot = local.snapshots['test/nature']!;
    final int encodedBytes = utf8
        .encode(
          jsonEncode(<String, Object?>{
            'cachedAtUtc': snapshot.cachedAtUtc.toIso8601String(),
            'ttlHours': snapshot.ttlHours,
            'payload': snapshot.payload,
          }),
        )
        .length;
    expect(encodedBytes, lessThanOrEqualTo(FeedCacheLocalDataSource.maxSnapshotBytes));
    expect(cache.pageFor('nature'), 2);
  });

  test('append evicts old pages before trimming the new page at the snapshot limit', () async {
    final local = FakeFeedCacheLocalDataSource();
    final cache = PagedFeedCache(local, source: 'test');
    await cache.write(
      'nature',
      scope: 'nature',
      payload: <String, dynamic>{'items': List<String>.filled(60, 'old' * 2910)},
      nextPage: 2,
      hasMore: true,
    );

    await cache.write(
      'nature',
      scope: 'nature',
      payload: <String, dynamic>{
        'items': <String>['new-page-item'],
      },
      nextPage: 3,
      hasMore: false,
      append: true,
    );

    final restarted = PagedFeedCache(local, source: 'test');
    final items = await restarted.read<String>(
      'nature',
      scope: 'nature',
      decode: (payload) => ((payload['items'] as List?) ?? const <Object?>[]).cast<String>(),
    );
    expect(items, contains('new-page-item'));
    expect(restarted.pageFor('nature'), 3);
  });

  test('a missing or empty snapshot is a miss and leaves the cursor alone', () async {
    final local = FakeFeedCacheLocalDataSource();
    final cache = PagedFeedCache(local, source: 'test');

    expect(await cache.read<int>('nature', scope: 'nature', decode: (_) => <int>[1]), isNull);

    await cache.write(
      'nature',
      scope: 'nature',
      payload: <String, dynamic>{'ids': <int>[]},
      nextPage: 5,
      hasMore: false,
    );
    cache.advance('nature', nextPage: 2, hasMore: true);

    expect(
      await cache.read<int>(
        'nature',
        scope: 'nature',
        decode: (payload) => ((payload['ids'] as List?) ?? const <Object?>[]).cast<int>(),
      ),
      isNull,
    );
    expect((cache.pageFor('nature'), cache.hasMore('nature')), (2, true));
  });
}

class _DelayedReadCache extends FakeFeedCacheLocalDataSource {
  bool hold = false;
  final started = Completer<void>();
  final release = Completer<void>();

  @override
  Future<FeedSnapshot?> read({required String source, required String scope}) async {
    final snapshot = await super.read(source: source, scope: scope);
    if (hold) {
      hold = false;
      started.complete();
      await release.future;
    }
    return snapshot;
  }
}
