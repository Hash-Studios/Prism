import 'dart:convert';

import 'package:Prism/core/persistence/data_sources/feed_cache_local_data_source.dart';
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

  test('offline category fallback keeps its cached page and candidate pool', () async {
    final List<int> pages = <int>[];
    final cache = _NoFeedCache();
    final http.Client client = MockClient((http.Request request) async {
      final int page = int.parse(request.url.queryParameters['page']!);
      pages.add(page);
      if (pages.length == 3) return http.Response('offline', 503);
      return http.Response(
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
    });
    final repository = PexelsWallpaperRepositoryImpl(cache);

    final categoryFirst = await http.runWithClient(() async {
      final category = await repository.fetchFeed(categoryName: 'Nature', refresh: true);
      await repository.fetchFeed(
        categoryName: 'Nature',
        refresh: true,
        startPage: 3,
        paginationKey: 'personalized:Nature',
      );
      final fallback = await repository.fetchFeed(categoryName: 'Nature', refresh: false);
      final categoryNext = await repository.fetchFeed(categoryName: 'Nature', refresh: false);
      final homeNext = await repository.fetchFeed(
        categoryName: 'Nature',
        refresh: false,
        paginationKey: 'personalized:Nature',
      );
      return (category, fallback, categoryNext, homeNext);
    }, () => client);

    expect(categoryFirst.$1.data!.single.id, '1');
    expect(categoryFirst.$2.data!.single.id, '1');
    expect(categoryFirst.$3.data!.single.id, '2');
    expect(categoryFirst.$4.data!.single.id, '4');
    expect(pages, <int>[1, 3, 2, 2, 4]);
  });
}
