// Hash-Studios/Prism#539
import 'dart:convert';

import 'package:Prism/core/persistence/data_sources/feed_cache_local_data_source.dart';

import 'package:Prism/features/pexels_feed/data/repositories/pexels_wallpaper_repository_impl.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../../../../support/fake_feed_cache_local_data_source.dart';

http.Response _curatedPage(List<int> ids) => http.Response(
  jsonEncode(<String, Object>{
    'page': 1,
    'per_page': 24,
    'total_results': ids.isEmpty ? 0 : 48,
    'photos': <Object>[
      for (final int id in ids)
        <String, Object>{
          'id': id,
          'url': 'https://example.com/$id',
          'src': <String, Object>{'original': 'https://example.com/$id'},
        },
    ],
  }),
  200,
);

class _UnreadableFeedCache extends FakeFeedCacheLocalDataSource {
  @override
  Future<FeedSnapshot?> read({required String source, required String scope}) async =>
      throw StateError('cache unavailable');
}

void main() {
  test('an empty first page on refresh does not replace the cached curated walls with an empty success', () async {
    final PexelsWallpaperRepositoryImpl repository = PexelsWallpaperRepositoryImpl(FakeFeedCacheLocalDataSource());
    bool empty = false;
    final http.Client client = MockClient((http.Request request) async {
      if (empty) return http.Response('{"page":1,"per_page":24,"total_results":0,"photos":[]}', 200);
      return _curatedPage(<int>[1, 2]);
    });

    final results = await http.runWithClient(() async {
      final first = await repository.fetchFeed(categoryName: 'Curated', refresh: true);
      empty = true;
      final second = await repository.fetchFeed(categoryName: 'Curated', refresh: true);
      return (first, second);
    }, () => client);

    expect(results.$1.data, hasLength(2));
    expect(results.$2.isSuccess, isTrue);
    expect(results.$2.data!.map((wall) => wall.id), <String>['1', '2']);
  });

  test('a search with no cache and zero results remains an empty success', () async {
    final repository = PexelsWallpaperRepositoryImpl(FakeFeedCacheLocalDataSource());
    final result = await http.runWithClient(
      () => repository.fetchFeed(categoryName: 'no results', refresh: true),
      () => MockClient((_) async => _curatedPage(<int>[])),
    );
    expect(result.isSuccess, isTrue);
    expect(result.data, isEmpty);
    expect(repository.hasMoreForCategory('no results'), isFalse);
  });

  test('an unreadable cache does not turn a successful empty search into an exception', () async {
    final repository = PexelsWallpaperRepositoryImpl(_UnreadableFeedCache());
    final result = await http.runWithClient(
      () => repository.fetchFeed(categoryName: 'no results', refresh: true),
      () => MockClient((_) async => _curatedPage(<int>[])),
    );

    expect(result.isSuccess, isTrue);
    expect(result.data, isEmpty);
    expect(repository.hasMoreForCategory('no results'), isFalse);
  });

  test('a corrupt cached photo does not turn a successful empty search into an exception', () async {
    final cache = FakeFeedCacheLocalDataSource();
    cache.snapshots['pexels/no_results.portrait'] = FeedSnapshot(
      payload: <String, Object?>{
        'pages': <Object?>[
          <String, Object?>{
            'photos': <Object?>[
              <String, Object?>{'id': 'corrupt'},
            ],
          },
        ],
        'nextPage': 9,
        'hasMore': true,
      },
      cachedAtUtc: DateTime.now().toUtc(),
      ttlHours: 6,
    );
    final repository = PexelsWallpaperRepositoryImpl(cache);
    final result = await http.runWithClient(
      () => repository.fetchFeed(categoryName: 'no results', refresh: true),
      () => MockClient((_) async => _curatedPage(<int>[])),
    );

    expect(result.isSuccess, isTrue);
    expect(result.data, isEmpty);
    expect(repository.hasMoreForCategory('no results'), isFalse);
  });

  test('an empty random start still lets the personalized caller retry the first page', () async {
    final cache = FakeFeedCacheLocalDataSource();
    final repository = PexelsWallpaperRepositoryImpl(cache);
    const key = 'personalized:Nature';
    final pages = <int>[];
    await http.runWithClient(
      () async {
        await repository.fetchFeed(categoryName: 'Nature', refresh: true, paginationKey: key);
        final randomStart = await repository.fetchFeed(
          categoryName: 'Nature',
          refresh: true,
          startPage: 4,
          paginationKey: key,
        );
        expect(randomStart.data, isEmpty);
        if (randomStart.data!.isEmpty) {
          final retry = await repository.fetchFeed(categoryName: 'Nature', refresh: true, paginationKey: key);
          expect(retry.data!.single.id, '3');
        }
      },
      () => MockClient((request) async {
        final page = int.parse(request.url.queryParameters['page']!);
        pages.add(page);
        return _curatedPage(page == 4 ? <int>[] : <int>[pages.length]);
      }),
    );
    expect(pages, <int>[1, 4, 1]);
  });

  for (final status in <int>[200, 503]) {
    test('an empty random start preserves the snapshot when the first-page retry returns $status', () async {
      final cache = FakeFeedCacheLocalDataSource();
      final repository = PexelsWallpaperRepositoryImpl(cache);
      const key = 'personalized:Nature';
      final pages = <int>[];
      await http.runWithClient(
        () async {
          await repository.fetchFeed(categoryName: 'Nature', refresh: true, paginationKey: key);
          final snapshot = cache.snapshots.values.single;
          final randomStart = await repository.fetchFeed(
            categoryName: 'Nature',
            refresh: true,
            startPage: 4,
            paginationKey: key,
          );
          expect(randomStart.data, isEmpty);
          final retry = await repository.fetchFeed(categoryName: 'Nature', refresh: true, paginationKey: key);
          expect(retry.data!.single.id, '7');
          expect(cache.scopes, hasLength(1));
          expect(cache.snapshots.values.single, same(snapshot));
        },
        () => MockClient((request) async {
          pages.add(int.parse(request.url.queryParameters['page']!));
          if (pages.length == 1) return _curatedPage(<int>[7]);
          if (pages.length == 3 && status != 200) return http.Response('rate limited', status);
          return _curatedPage(<int>[]);
        }),
      );
      expect(pages, <int>[1, 4, 1]);
    });
  }

  for (final hasMore in <bool>[true, false]) {
    test('empty refresh restores cached cursor and hasMore=$hasMore without writing', () async {
      final cache = FakeFeedCacheLocalDataSource();
      final snapshot = FeedSnapshot(
        payload: <String, Object?>{
          'pages': <Object?>[
            jsonDecode(_curatedPage(<int>[7]).body),
          ],
          'nextPage': 6,
          'hasMore': hasMore,
        },
        cachedAtUtc: DateTime.now().toUtc(),
        ttlHours: 6,
      );
      cache.snapshots['pexels/curated.portrait'] = snapshot;
      final repository = PexelsWallpaperRepositoryImpl(cache);
      final pages = <int>[];
      await http.runWithClient(
        () async {
          final result = await repository.fetchFeed(categoryName: 'Curated', refresh: true);
          expect(result.data!.single.id, '7');
          expect(repository.hasMoreForCategory('Curated'), hasMore);
          expect(cache.scopes, isEmpty);
          expect(cache.snapshots['pexels/curated.portrait'], same(snapshot));
          await repository.fetchFeed(categoryName: 'Curated', refresh: false);
        },
        () => MockClient((request) async {
          pages.add(int.parse(request.url.queryParameters['page']!));
          return _curatedPage(<int>[]);
        }),
      );
      expect(pages, <int>[1, 6]);
    });
  }

  test('empty detail refresh never returns an old durable snapshot', () async {
    final cache = FakeFeedCacheLocalDataSource();
    cache.snapshots['pexels/curated_detail_7_pexels.portrait'] = FeedSnapshot(
      payload: <String, Object?>{
        'pages': <Object?>[
          jsonDecode(_curatedPage(<int>[7]).body),
        ],
        'nextPage': 6,
        'hasMore': true,
      },
      cachedAtUtc: DateTime.now().toUtc(),
      ttlHours: 6,
    );
    final repository = PexelsWallpaperRepositoryImpl(cache);
    final result = await http.runWithClient(
      () => repository.fetchFeed(categoryName: 'Curated', refresh: true, paginationKey: 'detail:7:pexels'),
      () => MockClient((_) async => _curatedPage(<int>[])),
    );
    expect(result.isSuccess, isTrue);
    expect(result.data, isEmpty);
    expect(repository.hasMoreForCategory('Curated', paginationKey: 'detail:7:pexels'), isFalse);
    expect(cache.scopes, isEmpty);
  });
}
