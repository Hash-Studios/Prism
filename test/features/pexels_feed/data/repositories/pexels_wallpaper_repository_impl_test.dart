import 'dart:async';
import 'dart:convert';
import 'dart:io' show HandshakeException, SocketException;

import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/persistence/data_sources/feed_cache_local_data_source.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/features/pexels_feed/data/repositories/pexels_wallpaper_repository_impl.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../../../../support/fake_feed_cache_local_data_source.dart';

class _ThrowingFeedCache extends FakeFeedCacheLocalDataSource {
  @override
  Future<void> write({
    required String source,
    required String scope,
    required Object? payload,
    required int ttlHours,
  }) => Future<void>.error(StateError('cache unavailable'));
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

void main() {
  test('refresh invalidates a page already awaiting its cache append read', () async {
    final cache = _DelayedReadCache();
    final repository = PexelsWallpaperRepositoryImpl(cache);
    final pages = <int>[];
    await http.runWithClient(
      () async {
        await repository.fetchFeed(categoryName: 'A', refresh: true);
        cache.hold = true;
        final pending = repository.fetchFeed(categoryName: 'A', refresh: false);
        await cache.started.future;
        await repository.fetchFeed(categoryName: 'A', refresh: true);
        cache.release.complete();
        await pending;
        expect((cache.snapshots.values.single.payload! as Map)['pages'] as List, hasLength(1));
        await repository.fetchFeed(categoryName: 'A', refresh: false);
      },
      () => MockClient((request) async {
        pages.add(int.parse(request.url.queryParameters['page']!));
        return _page(pages.last);
      }),
    );
    expect(pages, <int>[1, 2, 1, 2]);
  });
  test('stale pages and A-B-A refreshes cannot replace the current cursor or snapshot', () async {
    final cache = FakeFeedCacheLocalDataSource();
    final repository = PexelsWallpaperRepositoryImpl(cache);
    final old = Completer<http.Response>();
    final started = Completer<void>();
    final pages = <int>[];
    await http.runWithClient(
      () async {
        await repository.fetchFeed(categoryName: 'A', refresh: true);
        final pending = repository.fetchFeed(categoryName: 'A', refresh: false);
        await started.future;
        await repository.fetchFeed(categoryName: 'B', refresh: true);
        await repository.fetchFeed(categoryName: 'A', refresh: true);
        old.complete(_page(2));
        await pending;
        expect((cache.snapshots['pexels/a.portrait']!.payload! as Map)['pages'] as List, hasLength(1));
        await repository.fetchFeed(categoryName: 'A', refresh: false);
      },
      () => MockClient((request) async {
        final page = int.parse(request.url.queryParameters['page']!);
        pages.add(page);
        if (pages.length == 2) {
          started.complete();
          return old.future;
        }
        return _page(page);
      }),
    );
    expect(pages, <int>[1, 2, 1, 1, 2]);
  });
  test('single lookup returns the photo and retains transport failure categories', () async {
    final repository = PexelsWallpaperRepositoryImpl(FakeFeedCacheLocalDataSource());
    final found = await http.runWithClient(
      () => repository.fetchById('7'),
      () => MockClient((request) async {
        expect(request.url.path, '/v1/photos/7');
        return http.Response(
          '{"id":7,"src":{"original":"https://example.com/full","portrait":"https://example.com/thumb"}}',
          200,
        );
      }),
    );
    expect(found.data!.id, '7');
    expect(found.data!.core.fullUrl, 'https://example.com/full');
    expect(found.data!.core.thumbnailUrl, 'https://example.com/thumb');
    for (final entry in <(Object, String)>[
      (const HandshakeException('tls'), 'tls_error'),
      (TimeoutException('slow'), 'timeout'),
      (http.ClientException('closed'), 'http_client_error'),
      (const FormatException('bad payload'), 'FormatException'),
    ]) {
      final result = await http.runWithClient(
        () => repository.fetchById('7'),
        () => MockClient((_) async => throw entry.$1),
      );
      expect(result.failure!.code, entry.$2);
      expect(result.failure, entry.$1 is FormatException ? isA<ServerFailure>() : isA<NetworkFailure>());
    }
  });

  test('a transport failure restores cached feed data on refresh only', () async {
    final cache = FakeFeedCacheLocalDataSource();
    final repository = PexelsWallpaperRepositoryImpl(cache);
    await http.runWithClient(
      () => repository.fetchFeed(categoryName: 'forest', refresh: true),
      () => MockClient((_) async => _page(1)),
    );
    await http.runWithClient(() async {
      expect((await repository.fetchFeed(categoryName: 'forest', refresh: true)).data!.single.id, '1');
      expect((await repository.fetchFeed(categoryName: 'forest', refresh: false)).failure, isA<ServerFailure>());
    }, () => MockClient((_) async => throw const SocketException('offline')));
  });

  test('a detail visit pages in memory only, while the curated feed keeps its durable snapshot', () async {
    final cache = FakeFeedCacheLocalDataSource();
    const detailKey = 'detail:7:pexels';
    // A snapshot an older build or launch left under this visit's scope must never come back.
    cache.snapshots['pexels/curated_detail_7_pexels.portrait'] = FeedSnapshot(
      payload: <String, Object?>{
        'pages': <Object?>[jsonDecode(_page(9).body)],
        'nextPage': 10,
        'hasMore': true,
      },
      cachedAtUtc: DateTime.now().toUtc(),
      ttlHours: 6,
    );
    final pages = <int>[];
    await http.runWithClient(
      () async {
        final repository = PexelsWallpaperRepositoryImpl(cache);
        await repository.fetchFeed(categoryName: 'Curated', refresh: true);
        final first = await repository.fetchFeed(categoryName: 'Curated', refresh: true, paginationKey: detailKey);
        final next = await repository.fetchFeed(categoryName: 'Curated', refresh: false, paginationKey: detailKey);
        expect(first.data!.single.id, '1');
        expect(next.data!.single.id, '2');
        expect(repository.hasMoreForCategory('Curated', paginationKey: detailKey), isTrue);
      },
      () => MockClient((request) async {
        pages.add(int.parse(request.url.queryParameters['page']!));
        return _page(pages.last);
      }),
    );
    expect(pages, <int>[1, 1, 2], reason: 'the visit pages from its own cursor in memory');
    expect(cache.scopes, <String>['pexels/curated.portrait'], reason: 'only the curated feed is written');

    final relaunched = PexelsWallpaperRepositoryImpl(cache);
    for (final Future<http.Response> Function() fail in <Future<http.Response> Function()>[
      () async => throw const SocketException('offline'),
      () async => http.Response('offline', 503),
    ]) {
      await http.runWithClient(() async {
        final detail = await relaunched.fetchFeed(categoryName: 'Curated', refresh: true, paginationKey: detailKey);
        expect(detail.isFailure, isTrue, reason: 'a failed first page falls back to local discovery, not old pages');
        expect((await relaunched.fetchFeed(categoryName: 'Curated', refresh: true)).data!.single.id, '1');
      }, () => MockClient((_) => fail()));
    }
  });

  group('fetchById failures', () {
    Future<Result<PexelsWallpaper?>> fetchWith(http.Client client) {
      final repository = PexelsWallpaperRepositoryImpl(FakeFeedCacheLocalDataSource());
      return http.runWithClient(() => repository.fetchById('123'), () => client);
    }

    test('a thrown transport error is a network failure for detail fallback', () async {
      final result = await fetchWith(MockClient((_) async => throw const SocketException('offline')));

      expect(result.failure, isA<NetworkFailure>());
    });

    test('a missing photo remains a server failure and does not permit detail fallback', () async {
      final result = await fetchWith(MockClient((_) async => http.Response('not found', 404)));

      expect(result.failure, isA<ServerFailure>());
    });
  });

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

  test('a successful remote page is returned when cache persistence fails', () async {
    final PexelsWallpaperRepositoryImpl repository = PexelsWallpaperRepositoryImpl(_ThrowingFeedCache());
    final http.Client client = MockClient((_) async => _page(1));

    final result = await http.runWithClient(
      () => repository.fetchFeed(categoryName: 'Nature', refresh: true),
      () => client,
    );

    expect(result.data, hasLength(1));
    expect(repository.hasMoreForCategory('Nature'), isTrue);
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
