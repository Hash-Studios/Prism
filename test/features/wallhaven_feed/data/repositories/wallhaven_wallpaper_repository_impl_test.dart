import 'dart:async';
import 'dart:convert';

import 'package:Prism/core/persistence/data_sources/feed_cache_local_data_source.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/features/wallhaven_feed/data/repositories/wallhaven_wallpaper_repository_impl.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class _NoFeedCache extends Fake implements FeedCacheLocalDataSource {
  final List<String> scopes = <String>[];
  final Map<String, FeedSnapshot> snapshots = <String, FeedSnapshot>{};

  @override
  Future<FeedSnapshot?> read({required String source, required String scope}) async => snapshots['$source:$scope'];

  @override
  Future<void> write({
    required String source,
    required String scope,
    required Object? payload,
    required int ttlHours,
  }) async {
    scopes.add('$source:$scope');
    snapshots['$source:$scope'] = FeedSnapshot(
      payload: payload,
      cachedAtUtc: DateTime.now().toUtc(),
      ttlHours: ttlHours,
    );
  }
}

void main() {
  test('category and personalized searches keep independent pagination', () async {
    final List<int> pages = <int>[];
    final http.Client client = MockClient((http.Request request) async {
      final int page = int.parse(request.url.queryParameters['page']!);
      pages.add(page);
      return http.Response(
        jsonEncode(<String, Object>{
          'data': <Object>[],
          'meta': <String, Object>{'current_page': page, 'last_page': 3},
        }),
        200,
      );
    });
    final cache = _NoFeedCache();
    final repository = WallhavenWallpaperRepositoryImpl(cache);

    await http.runWithClient(() async {
      await repository.fetchFeed(categoryName: 'nature', refresh: true);
      await repository.fetchFeed(
        categoryName: 'nature',
        refresh: true,
        startPage: 3,
        paginationKey: 'personalized:nature',
      );
      await repository.fetchFeed(categoryName: 'nature', refresh: false);
      await repository.fetchFeed(categoryName: 'nature', refresh: false, paginationKey: 'personalized:nature');
    }, () => client);

    expect(pages, <int>[1, 3, 2, 4]);
    expect(cache.scopes.toSet(), hasLength(2));
    expect(repository.hasMoreForCategory('nature'), isTrue);
    expect(repository.hasMoreForCategory('nature', paginationKey: 'personalized:nature'), isFalse);
  });

  test('a failed refresh falls back to the cached first page and keeps its candidate pool', () async {
    final List<int> pages = <int>[];
    final cache = _NoFeedCache();
    final http.Client client = MockClient((http.Request request) async {
      final int page = int.parse(request.url.queryParameters['page']!);
      pages.add(page);
      if (pages.length == 3) return http.Response('offline', 503);
      return _page(page);
    });
    final repository = WallhavenWallpaperRepositoryImpl(cache);

    final results = await http.runWithClient(() async {
      final category = await repository.fetchFeed(categoryName: 'nature', refresh: true);
      await repository.fetchFeed(
        categoryName: 'nature',
        refresh: true,
        startPage: 3,
        paginationKey: 'personalized:nature',
      );
      final fallback = await repository.fetchFeed(categoryName: 'nature', refresh: true);
      final categoryNext = await repository.fetchFeed(categoryName: 'nature', refresh: false);
      final homeNext = await repository.fetchFeed(
        categoryName: 'nature',
        refresh: false,
        paginationKey: 'personalized:nature',
      );
      return (category, fallback, categoryNext, homeNext);
    }, () => client);

    expect(results.$1.data!.single.id, 'wall-1');
    expect(results.$2.data!.single.id, 'wall-1');
    expect(results.$3.data!.single.id, 'wall-2');
    expect(results.$4.data!.single.id, 'wall-4');
    expect(pages, <int>[1, 3, 1, 2, 4]);
  });

  test('a failed fetch-more returns an error instead of the cached first page', () async {
    final cache = _NoFeedCache();
    bool offline = false;
    final http.Client client = MockClient((http.Request request) async {
      if (offline) return http.Response('offline', 503);
      return _page(int.parse(request.url.queryParameters['page']!));
    });
    final repository = WallhavenWallpaperRepositoryImpl(cache);

    final result = await http.runWithClient(() async {
      await repository.fetchFeed(categoryName: 'nature', refresh: true);
      offline = true;
      return repository.fetchFeed(categoryName: 'nature', refresh: false);
    }, () => client);

    expect(result.isFailure, isTrue);
    expect(cache.scopes, hasLength(1), reason: 'only the refresh writes the snapshot');
  });

  test('later pages move the cursor without overwriting the first-page snapshot', () async {
    final cache = _NoFeedCache();
    final http.Client client = MockClient(
      (http.Request request) async => _page(int.parse(request.url.queryParameters['page']!)),
    );
    final repository = WallhavenWallpaperRepositoryImpl(cache);

    await http.runWithClient(() async {
      await repository.fetchFeed(categoryName: 'nature', refresh: true);
      await repository.fetchFeed(categoryName: 'nature', refresh: false);
      await repository.fetchFeed(categoryName: 'nature', refresh: false);
    }, () => client);

    expect(cache.scopes, hasLength(1));
    final Map<String, Object?> stored = cache.snapshots.values.single.payload! as Map<String, Object?>;
    expect(stored['nextPage'], 2);
  });

  test('requests are portrait by default and filters map to query params', () async {
    final List<Map<String, String>> queries = <Map<String, String>>[];
    final http.Client client = MockClient((http.Request request) async {
      queries.add(request.url.queryParameters);
      return _page(1);
    });
    final cache = _NoFeedCache();
    final repository = WallhavenWallpaperRepositoryImpl(cache);

    await http.runWithClient(() async {
      await repository.fetchFeed(categoryName: 'nature', refresh: true);
      await repository.fetchFeed(
        categoryName: 'nature',
        refresh: true,
        portraitOnly: false,
        minResolution: '1440x2560',
        sorting: 'toplist',
      );
      await repository.fetchToplist();
    }, () => client);

    expect(queries[0]['ratios'], 'portrait');
    expect(queries[0].containsKey('atleast'), isFalse);
    expect(queries[0].containsKey('sorting'), isFalse);
    expect(queries[1].containsKey('ratios'), isFalse);
    expect(queries[1]['atleast'], '1440x2560');
    expect(queries[1]['sorting'], 'toplist');
    expect(queries[1]['topRange'], '1y', reason: 'the default one month toplist leaves most searches empty');
    expect(queries[0].containsKey('topRange'), isFalse);
    expect(queries[2]['ratios'], 'portrait');
    expect(cache.scopes.toSet(), hasLength(3), reason: 'portrait, filters and toplist use different scopes');
    expect(cache.scopes.first, contains('portrait'));
  });

  testWidgets('a request that never answers fails with a timeout instead of hanging', (tester) async {
    final http.Client client = MockClient((http.Request request) => Completer<http.Response>().future);
    final repository = WallhavenWallpaperRepositoryImpl(_NoFeedCache());

    final Future<Result<List<WallhavenWallpaper>>> pending = http.runWithClient(
      () => repository.fetchFeed(categoryName: 'nature', refresh: true),
      () => client,
    );
    await tester.pump(const Duration(seconds: 11));

    expect((await pending).isFailure, isTrue);
  });
}

http.Response _page(int page) => http.Response(
  jsonEncode(<String, Object>{
    'data': <Object>[
      <String, Object>{'id': 'wall-$page', 'path': 'https://example.com/$page'},
    ],
    'meta': <String, Object>{'current_page': page, 'last_page': 10},
  }),
  200,
);
