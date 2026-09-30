import 'package:Prism/data/feed_cache/paged_feed_cache.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_feed_cache_local_data_source.dart';

void main() {
  test('feedCacheSlug lower-cases and joins runs of other characters with one underscore', () {
    expect(feedCacheSlug('  Dark & Moody!! '), 'dark_moody_');
    expect(feedCacheSlug('color: ff0000'), 'color_ff0000');
  });

  test('cursor starts at page 1 with more pages, and reset restores that', () async {
    final cache = PagedFeedCache(FakeFeedCacheLocalDataSource(), source: 'test');

    expect(cache.pageFor('nature'), 1);
    expect(cache.hasMore('nature'), isTrue);

    await cache.write('nature', scope: 'nature', payload: <String, dynamic>{'n': 1}, nextPage: 3, hasMore: false);
    expect((cache.pageFor('nature'), cache.hasMore('nature')), (3, false));

    cache.reset('nature');
    expect((cache.pageFor('nature'), cache.hasMore('nature')), (1, true));
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
    cache.reset('nature');

    expect(await cache.read<int>('nature', scope: 'nature', decode: (_) => <int>[]), isNull);
    expect((cache.pageFor('nature'), cache.hasMore('nature')), (1, true));
  });
}
