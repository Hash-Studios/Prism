import 'dart:async';
import 'dart:convert';
import 'dart:io' show SocketException;

import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/persistence/data_sources/feed_cache_local_data_source.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/features/wallhaven_feed/data/repositories/wallhaven_wallpaper_repository_impl.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../../../../support/fake_feed_cache_local_data_source.dart';

class _FailingWriteCache extends FakeFeedCacheLocalDataSource {
  @override
  Future<void> write({
    required String source,
    required String scope,
    required Object? payload,
    required int ttlHours,
  }) => Future<void>.error(StateError('disk full'));
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
    final repository = WallhavenWallpaperRepositoryImpl(cache);
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
    final repository = WallhavenWallpaperRepositoryImpl(cache);
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
        final snapshot = cache.snapshots.entries.firstWhere((entry) => entry.key.startsWith('wallhaven/a.')).value;
        expect((snapshot.payload! as Map)['pages'] as List, hasLength(1));
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
  test('disk write failures keep feed pagination and toplist results usable', () async {
    final repository = WallhavenWallpaperRepositoryImpl(_FailingWriteCache());
    final pages = <String>[];
    await http.runWithClient(
      () async {
        expect((await repository.fetchFeed(categoryName: 'forest', refresh: true)).data!.single.id, 'wall-1');
        expect((await repository.fetchFeed(categoryName: 'forest', refresh: false)).data!.single.id, 'wall-2');
        expect((await repository.fetchToplist(page: 3)).data!.single.id, 'wall-3');
      },
      () => MockClient((request) async {
        pages.add(request.url.queryParameters['page']!);
        return _page(int.parse(pages.last));
      }),
    );
    expect(pages, <String>['1', '2', '3']);
    expect(repository.hasMoreForCategory('forest'), isTrue);
  });

  test('toplist refresh restores cached pages on transport or status errors but fetch-more fails', () async {
    final cache = FakeFeedCacheLocalDataSource();
    final repository = WallhavenWallpaperRepositoryImpl(cache);
    Object? error;
    var status = 200;
    await http.runWithClient(
      () async {
        expect((await repository.fetchToplist()).data!.single.id, 'wall-1');
        expect((await repository.fetchToplist(page: 2)).data!.single.id, 'wall-2');
        status = 503;
        expect((await repository.fetchToplist()).data!.map((wall) => wall.id), <String>['wall-1', 'wall-2']);
        expect((await repository.fetchToplist(page: 3)).failure, isA<ServerFailure>());
        error = const SocketException('offline');
        expect((await repository.fetchToplist()).data!.map((wall) => wall.id), <String>['wall-1', 'wall-2']);
        expect(
          (await repository.fetchToplist(page: 3)).failure!.message,
          contains('Failed to fetch WallHaven toplist'),
        );
        expect((await repository.fetchFeed(categoryName: 'uncached', refresh: true)).isFailure, isTrue);
      },
      () => MockClient((request) async {
        if (error != null) throw error!;
        return status == 200
            ? _page(int.parse(request.url.queryParameters['page']!))
            : http.Response('offline', status);
      }),
    );
  });

  test('feed transport failure restores a durable snapshot after repository restart', () async {
    final cache = FakeFeedCacheLocalDataSource();
    await http.runWithClient(() async {
      await WallhavenWallpaperRepositoryImpl(cache).fetchFeed(categoryName: 'forest', refresh: true);
    }, () => MockClient((_) async => _page(1)));
    final repository = WallhavenWallpaperRepositoryImpl(cache);
    final restored = await http.runWithClient(
      () => repository.fetchFeed(categoryName: 'forest', refresh: true),
      () => MockClient((_) async => throw const SocketException('offline')),
    );
    expect(restored.data!.single.id, 'wall-1');
    expect(repository.hasMoreForCategory('forest'), isTrue);
  });

  test('a detail visit pages in memory only, while the main feed keeps its durable snapshot', () async {
    final cache = FakeFeedCacheLocalDataSource();
    const detailKey = 'detail:7:wallhaven';
    // A snapshot an older build or launch left under this visit's scope must never come back.
    cache.snapshots['wallhaven/forest_detail_7_wallhaven.100.100.portrait'] = FeedSnapshot(
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
        final repository = WallhavenWallpaperRepositoryImpl(cache);
        await repository.fetchFeed(categoryName: 'forest', refresh: true);
        final first = await repository.fetchFeed(categoryName: 'forest', refresh: true, paginationKey: detailKey);
        final next = await repository.fetchFeed(categoryName: 'forest', refresh: false, paginationKey: detailKey);
        expect(first.data!.single.id, 'wall-1');
        expect(next.data!.single.id, 'wall-2');
        expect(repository.hasMoreForCategory('forest', paginationKey: detailKey), isTrue);
      },
      () => MockClient((request) async {
        pages.add(int.parse(request.url.queryParameters['page']!));
        return _page(pages.last);
      }),
    );
    expect(pages, <int>[1, 1, 2], reason: 'the visit pages from its own cursor in memory');
    expect(cache.scopes, <String>['wallhaven/forest.100.100.portrait'], reason: 'only the main feed is written');

    final relaunched = WallhavenWallpaperRepositoryImpl(cache);
    for (final Future<http.Response> Function() fail in <Future<http.Response> Function()>[
      () async => throw const SocketException('offline'),
      () async => http.Response('offline', 503),
    ]) {
      await http.runWithClient(() async {
        final detail = await relaunched.fetchFeed(categoryName: 'forest', refresh: true, paginationKey: detailKey);
        expect(detail.isFailure, isTrue, reason: 'a failed first page falls back to local discovery, not old pages');
        expect((await relaunched.fetchFeed(categoryName: 'forest', refresh: true)).data!.single.id, 'wall-1');
      }, () => MockClient((_) => fail()));
    }
  });

  test('single lookup maps a successful response and malformed data to distinct outcomes', () async {
    final repository = WallhavenWallpaperRepositoryImpl(FakeFeedCacheLocalDataSource());
    await http.runWithClient(
      () async {
        final found = await repository.fetchById('ABC123');
        expect(found.data!.id, 'abc123');
        expect(found.data!.fullUrl, 'https://example.com/full');
      },
      () => MockClient((request) async {
        expect(request.url.path, '/api/v1/w/abc123');
        return http.Response(
          jsonEncode(<String, Object>{
            'data': <String, Object>{'id': 'abc123', 'path': 'https://example.com/full'},
          }),
          200,
        );
      }),
    );
    final malformed = await http.runWithClient(
      () => repository.fetchById('abc123'),
      () => MockClient((_) async => http.Response('invalid json', 200)),
    );
    expect(malformed.failure, isA<ServerFailure>());
    expect(malformed.failure!.message, wallpaperLoadFailureMessage);
  });

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
    final cache = FakeFeedCacheLocalDataSource();
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
    final cache = FakeFeedCacheLocalDataSource();
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
    final cache = FakeFeedCacheLocalDataSource();
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

  test('later pages are retained and advance the durable cursor', () async {
    final cache = FakeFeedCacheLocalDataSource();
    final http.Client client = MockClient(
      (http.Request request) async => _page(int.parse(request.url.queryParameters['page']!)),
    );
    final repository = WallhavenWallpaperRepositoryImpl(cache);

    await http.runWithClient(() async {
      await repository.fetchFeed(categoryName: 'nature', refresh: true);
      await repository.fetchFeed(categoryName: 'nature', refresh: false);
      await repository.fetchFeed(categoryName: 'nature', refresh: false);
    }, () => client);

    expect(cache.scopes, hasLength(3));
    final Map<String, Object?> stored = cache.snapshots.values.single.payload! as Map<String, Object?>;
    expect(stored['nextPage'], 4);
    expect(stored['pages'], hasLength(3));
  });

  test('requests are portrait by default and filters map to query params', () async {
    final List<Map<String, String>> queries = <Map<String, String>>[];
    final http.Client client = MockClient((http.Request request) async {
      queries.add(request.url.queryParameters);
      return _page(1);
    });
    final cache = FakeFeedCacheLocalDataSource();
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
    final repository = WallhavenWallpaperRepositoryImpl(FakeFeedCacheLocalDataSource());

    final Future<Result<List<WallhavenWallpaper>>> pending = http.runWithClient(
      () => repository.fetchFeed(categoryName: 'nature', refresh: true),
      () => client,
    );
    await tester.pump(const Duration(seconds: 11));

    expect((await pending).isFailure, isTrue);
  });

  group('fetchById failures', () {
    Future<Result<WallhavenWallpaper?>> fetchWith(http.Client client) {
      final repository = WallhavenWallpaperRepositoryImpl(FakeFeedCacheLocalDataSource());
      return http.runWithClient(() => repository.fetchById('abc123'), () => client);
    }

    test('a server error tells the user to check the connection and keeps the status in the code', () async {
      final result = await fetchWith(MockClient((_) async => http.Response('boom', 503, reasonPhrase: 'Unavailable')));

      expect(result.failure!.message, wallpaperLoadFailureMessage);
      expect(result.failure!.code, 'http_503');
      expect(result.failure!.message, isNot(contains('503')));
    });

    test('a thrown network error never reaches the screen as raw text', () async {
      final result = await fetchWith(MockClient((_) async => throw const SocketException('Failed host lookup')));

      expect(result.failure!.message, wallpaperLoadFailureMessage);
      expect(result.failure, isA<NetworkFailure>());
    });

    test('a wall Wallhaven does not know is a success with no wall, so the screen can say it was not found', () async {
      final result = await fetchWith(MockClient((_) async => http.Response('{}', 404)));

      expect(result.isSuccess, isTrue);
      expect(result.data, isNull);
    });
  });

  group('colour search', () {
    Future<(List<Uri>, FakeFeedCacheLocalDataSource)> run(
      Future<void> Function(WallhavenWallpaperRepositoryImpl repository) body,
    ) async {
      final List<Uri> requests = <Uri>[];
      final http.Client client = MockClient((http.Request request) async {
        requests.add(request.url);
        return _page(1);
      });
      final cache = FakeFeedCacheLocalDataSource();
      final repository = WallhavenWallpaperRepositoryImpl(cache);
      await http.runWithClient(() => body(repository), () => client);
      return (requests, cache);
    }

    test('colors goes to Wallhaven with the query', () async {
      final (requests, _) = await run((repository) async {
        await repository.fetchFeed(categoryName: 'forest', refresh: true, colors: '0066cc');
      });

      expect(requests.single.queryParameters['q'], 'forest');
      expect(requests.single.queryParameters['colors'], '0066cc');
    });

    test('without a colour there is no colors parameter', () async {
      final (requests, _) = await run((repository) async {
        await repository.fetchFeed(categoryName: 'forest', refresh: true);
      });

      expect(requests.single.queryParameters.containsKey('colors'), isFalse);
    });

    test('an empty query sends no q parameter', () async {
      final (requests, _) = await run((repository) async {
        await repository.fetchFeed(
          categoryName: '',
          refresh: true,
          colors: 'cc0000',
          paginationKey: 'search::color:red',
        );
      });

      expect(requests.single.queryParameters.containsKey('q'), isFalse);
      expect(requests.single.queryParameters['colors'], 'cc0000');
    });

    test('two colours do not share a cached first page', () async {
      final (_, cache) = await run((repository) async {
        await repository.fetchFeed(categoryName: 'forest', refresh: true, colors: '0066cc');
        await repository.fetchFeed(categoryName: 'forest', refresh: true, colors: 'cc0000');
        await repository.fetchFeed(categoryName: 'forest', refresh: true);
      });

      expect(cache.scopes.toSet(), hasLength(3));
    });
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
