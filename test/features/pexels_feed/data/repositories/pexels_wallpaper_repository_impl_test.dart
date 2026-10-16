import 'dart:async';
import 'dart:convert';

import 'package:Prism/core/utils/result.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/features/pexels_feed/data/repositories/pexels_wallpaper_repository_impl.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../../../../support/fake_feed_cache_local_data_source.dart';

void main() {
  test('the home feed asks Pexels for 30 photos a page and the category grids ask for 80', () async {
    final List<String> perPage = <String>[];
    final http.Client client = MockClient((http.Request request) async {
      perPage.add(request.url.queryParameters['per_page']!);
      return http.Response('{"page":1,"per_page":30,"total_results":0,"photos":[]}', 200);
    });
    final repository = PexelsWallpaperRepositoryImpl(FakeFeedCacheLocalDataSource());

    await http.runWithClient(() async {
      await repository.fetchFeed(categoryName: 'Nature', refresh: true, paginationKey: 'personalized:Nature');
      await repository.fetchFeed(categoryName: 'Nature', refresh: true);
    }, () => client);

    expect(perPage, <String>['30', '80']);
  });

  test('category and personalized searches keep independent pagination', () async {
    final List<int> pages = <int>[];
    final http.Client client = MockClient((http.Request request) async {
      pages.add(int.parse(request.url.queryParameters['page']!));
      return http.Response(
        jsonEncode(<String, Object>{'page': pages.last, 'per_page': 80, 'total_results': 240, 'photos': <Object>[]}),
        200,
      );
    });
    final cache = FakeFeedCacheLocalDataSource();
    final repository = PexelsWallpaperRepositoryImpl(cache);

    await http.runWithClient(() async {
      await repository.fetchFeed(categoryName: 'Nature', refresh: true);
      await repository.fetchFeed(
        categoryName: 'Nature',
        refresh: true,
        startPage: 3,
        paginationKey: 'personalized:Nature',
      );
      await repository.fetchFeed(categoryName: 'Nature', refresh: false);
      await repository.fetchFeed(categoryName: 'Nature', refresh: false, paginationKey: 'personalized:Nature');
    }, () => client);

    expect(pages, <int>[1, 3, 2, 4]);
    expect(cache.scopes.toSet(), hasLength(2));
    expect(repository.hasMoreForCategory('Nature'), isTrue);
    expect(repository.hasMoreForCategory('Nature', paginationKey: 'personalized:Nature'), isFalse);
  });

  test('a failed refresh falls back to the cached first page and keeps its candidate pool', () async {
    final List<int> pages = <int>[];
    final cache = FakeFeedCacheLocalDataSource();
    final http.Client client = MockClient((http.Request request) async {
      final int page = int.parse(request.url.queryParameters['page']!);
      pages.add(page);
      if (pages.length == 3) return http.Response('offline', 503);
      return _page(page);
    });
    final repository = PexelsWallpaperRepositoryImpl(cache);

    final results = await http.runWithClient(() async {
      final category = await repository.fetchFeed(categoryName: 'Nature', refresh: true);
      await repository.fetchFeed(
        categoryName: 'Nature',
        refresh: true,
        startPage: 3,
        paginationKey: 'personalized:Nature',
      );
      final fallback = await repository.fetchFeed(categoryName: 'Nature', refresh: true);
      final categoryNext = await repository.fetchFeed(categoryName: 'Nature', refresh: false);
      final homeNext = await repository.fetchFeed(
        categoryName: 'Nature',
        refresh: false,
        paginationKey: 'personalized:Nature',
      );
      return (category, fallback, categoryNext, homeNext);
    }, () => client);

    expect(results.$1.data!.single.id, '1');
    expect(results.$2.data!.single.id, '1');
    expect(results.$3.data!.single.id, '2');
    expect(results.$4.data!.single.id, '4');
    expect(pages, <int>[1, 3, 1, 2, 4]);
  });

  test('a failed fetch-more returns an error instead of the cached first page', () async {
    final cache = FakeFeedCacheLocalDataSource();
    bool offline = false;
    final http.Client client = MockClient((http.Request request) async {
      if (offline) return http.Response('offline', 503);
      return _page(int.parse(request.url.queryParameters['page']!));
    });
    final repository = PexelsWallpaperRepositoryImpl(cache);

    final result = await http.runWithClient(() async {
      await repository.fetchFeed(categoryName: 'Nature', refresh: true);
      offline = true;
      return repository.fetchFeed(categoryName: 'Nature', refresh: false);
    }, () => client);

    expect(result.isFailure, isTrue);
    expect(cache.scopes, hasLength(1), reason: 'only the refresh writes the snapshot');
  });

  test('requests ask for portrait photos unless the caller opts out, and the scope records it', () async {
    final List<Map<String, String>> queries = <Map<String, String>>[];
    final http.Client client = MockClient((http.Request request) async {
      queries.add(request.url.queryParameters);
      return _page(1);
    });
    final cache = FakeFeedCacheLocalDataSource();
    final repository = PexelsWallpaperRepositoryImpl(cache);

    await http.runWithClient(() async {
      await repository.fetchFeed(categoryName: 'Nature', refresh: true);
      await repository.fetchFeed(categoryName: 'Nature', refresh: true, portraitOnly: false);
    }, () => client);

    expect(queries[0]['orientation'], 'portrait');
    expect(queries[1].containsKey('orientation'), isFalse);
    expect(cache.scopes.toSet(), <String>{'pexels/nature.portrait', 'pexels/nature'});
  });

  testWidgets('a request that never answers fails with a timeout instead of hanging', (tester) async {
    final http.Client client = MockClient((http.Request request) => Completer<http.Response>().future);
    final repository = PexelsWallpaperRepositoryImpl(FakeFeedCacheLocalDataSource());

    final Future<Result<List<PexelsWallpaper>>> pending = http.runWithClient(
      () => repository.fetchFeed(categoryName: 'Nature', refresh: true),
      () => client,
    );
    await tester.pump(const Duration(seconds: 11));

    expect((await pending).isFailure, isTrue);
  });

  test('the thumbnail prefers the portrait crop', () async {
    final http.Client client = MockClient(
      (http.Request request) async => http.Response(
        jsonEncode(<String, Object>{
          'page': 1,
          'per_page': 80,
          'total_results': 1,
          'photos': <Object>[
            <String, Object>{
              'id': 7,
              'url': 'https://example.com/7',
              'src': <String, Object>{
                'original': 'https://example.com/original',
                'medium': 'https://example.com/medium',
                'portrait': 'https://example.com/portrait',
              },
            },
          ],
        }),
        200,
      ),
    );
    final repository = PexelsWallpaperRepositoryImpl(FakeFeedCacheLocalDataSource());

    final result = await http.runWithClient(
      () => repository.fetchFeed(categoryName: 'Nature', refresh: true),
      () => client,
    );

    expect(result.data!.single.core.thumbnailUrl, 'https://example.com/portrait');
  });

  test('a search with a colour sends the Pexels colour name and keeps the query', () async {
    final List<Uri> requests = <Uri>[];
    final http.Client client = MockClient((http.Request request) async {
      requests.add(request.url);
      return http.Response('{"page":1,"per_page":80,"total_results":0,"photos":[]}', 200);
    });
    final repository = PexelsWallpaperRepositoryImpl(FakeFeedCacheLocalDataSource());

    await http.runWithClient(() async {
      await repository.fetchFeed(categoryName: 'forest', refresh: true, color: 'violet');
      await repository.fetchFeed(categoryName: 'forest', refresh: true);
    }, () => client);

    expect(requests.map((uri) => (uri.queryParameters['query'], uri.queryParameters['color'])), <(String?, String?)>[
      ('forest', 'violet'),
      ('forest', null),
    ]);
  });
}

http.Response _page(int page) => http.Response(
  jsonEncode(<String, Object>{
    'page': page,
    'per_page': 80,
    'total_results': 800,
    'photos': <Object>[
      <String, Object>{
        'id': page,
        'url': 'https://example.com/$page',
        'src': <String, Object>{'original': 'https://example.com/$page'},
      },
    ],
  }),
  200,
);
