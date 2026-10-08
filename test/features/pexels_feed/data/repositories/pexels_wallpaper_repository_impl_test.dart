import 'dart:async';
import 'dart:convert';

import 'package:Prism/core/persistence/data_sources/feed_cache_local_data_source.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/features/pexels_feed/data/repositories/pexels_wallpaper_repository_impl.dart';
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
      pages.add(int.parse(request.url.queryParameters['page']!));
      return http.Response(
        jsonEncode(<String, Object>{'page': pages.last, 'per_page': 80, 'total_results': 240, 'photos': <Object>[]}),
        200,
      );
    });
    final cache = _NoFeedCache();
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

  test('color searches normalize cache keys and keep paging isolated across colors', () async {
    final List<Uri> requests = <Uri>[];
    final http.Client client = MockClient((http.Request request) async {
      requests.add(request.url);
      final int page = int.parse(request.url.queryParameters['page']!);
      final bool red = request.url.queryParameters['query'] == 'red wallpaper';
      final int id = (red ? 100 : 200) + page;
      return http.Response(
        jsonEncode(<String, Object>{
          'page': page,
          'per_page': 1,
          'total_results': 3,
          'photos': <Object>[
            <String, Object>{
              'id': id,
              'url': 'https://example.com/$id',
              'src': <String, Object>{'original': 'https://example.com/$id'},
            },
          ],
        }),
        200,
      );
    });
    final cache = _NoFeedCache();
    final repository = PexelsWallpaperRepositoryImpl(cache);

    final results = await http.runWithClient(() async {
      final redFirst = await repository.fetchColorFeed(hex: 'B71C1C', name: ' Red ', refresh: true);
      final blueFirst = await repository.fetchColorFeed(hex: '#0000FF', name: 'Blue', refresh: true);
      final redNext = await repository.fetchColorFeed(hex: '#b71c1c', name: 'RED', refresh: false);
      final blueNext = await repository.fetchColorFeed(hex: '0000ff', name: ' BLUE ', refresh: false);
      final redRefresh = await repository.fetchColorFeed(hex: '#B71C1C', name: 'red', refresh: true);
      return <String>[
        redFirst.data!.single.id,
        blueFirst.data!.single.id,
        redNext.data!.single.id,
        blueNext.data!.single.id,
        redRefresh.data!.single.id,
      ];
    }, () => client);

    expect(results, <String>['101', '201', '102', '202', '101']);
    expect(
      requests.map(
        (uri) => <String?>[uri.queryParameters['query'], uri.queryParameters['color'], uri.queryParameters['page']],
      ),
      <List<String?>>[
        <String?>['red wallpaper', '#b71c1c', '1'],
        <String?>['blue wallpaper', '#0000ff', '1'],
        <String?>['red wallpaper', '#b71c1c', '2'],
        <String?>['blue wallpaper', '#0000ff', '2'],
        <String?>['red wallpaper', '#b71c1c', '1'],
      ],
    );
    expect(cache.snapshots.keys.toSet(), <String>{'pexels:color_b71c1c.portrait', 'pexels:color_0000ff.portrait'});
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
    final cache = _NoFeedCache();
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
    final cache = _NoFeedCache();
    final repository = PexelsWallpaperRepositoryImpl(cache);

    await http.runWithClient(() async {
      await repository.fetchFeed(categoryName: 'Nature', refresh: true);
      await repository.fetchFeed(categoryName: 'Nature', refresh: true, portraitOnly: false);
    }, () => client);

    expect(queries[0]['orientation'], 'portrait');
    expect(queries[1].containsKey('orientation'), isFalse);
    expect(cache.scopes.toSet(), <String>{'pexels:nature.portrait', 'pexels:nature'});
  });

  testWidgets('a request that never answers fails with a timeout instead of hanging', (tester) async {
    final http.Client client = MockClient((http.Request request) => Completer<http.Response>().future);
    final repository = PexelsWallpaperRepositoryImpl(_NoFeedCache());

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
    final repository = PexelsWallpaperRepositoryImpl(_NoFeedCache());

    final result = await http.runWithClient(
      () => repository.fetchFeed(categoryName: 'Nature', refresh: true),
      () => client,
    );

    expect(result.data!.single.core.thumbnailUrl, 'https://example.com/portrait');
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
