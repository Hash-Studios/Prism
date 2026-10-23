import 'dart:async';
import 'dart:convert';

import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/firestore/firestore_client.dart';
import 'package:Prism/core/firestore/firestore_query_specs.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/data/feed_cache/pagination_session.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/pexels_feed/data/repositories/pexels_wallpaper_repository_impl.dart';
import 'package:Prism/features/pexels_feed/domain/repositories/pexels_wallpaper_repository.dart';
import 'package:Prism/features/user_blocks/domain/repositories/user_block_repository.dart';
import 'package:Prism/features/wallhaven_feed/data/repositories/wallhaven_wallpaper_repository_impl.dart';
import 'package:Prism/features/wallhaven_feed/domain/repositories/wallhaven_wallpaper_repository.dart';
import 'package:Prism/features/wallpaper_detail/data/repositories/wallpaper_recommendation_repository_impl.dart';
import 'package:Prism/features/wallpaper_detail/domain/entities/recommendation_page.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mocktail/mocktail.dart';

import '../../../support/fake_feed_cache_local_data_source.dart';
import '../../../support/in_memory_local_store.dart';

class _Firestore extends Fake implements FirestoreClient {
  final specs = <FirestoreQuerySpec>[];
  List<Map<String, dynamic>> rows = [];
  bool fail = false;
  @override
  Future<List<T>> query<T>(FirestoreQuerySpec spec, T Function(Map<String, dynamic>, String) map) async {
    specs.add(spec);
    if (fail) throw StateError('offline');
    return rows.map((row) => map(row, 'doc-${row['id']}')).toList();
  }
}

class _Wallhaven extends Mock implements WallhavenWallpaperRepository, PaginationSession {}

class _Pexels extends Mock implements PexelsWallpaperRepository, PaginationSession {}

class _Blocks extends Mock implements UserBlockRepository {}

FeedItemEntity _item(
  String id, {
  WallpaperSource source = WallpaperSource.prism,
  List<String>? tags,
  String category = 'Nature',
}) {
  final core = WallpaperCore(id: id, source: source, fullUrl: '', thumbnailUrl: '', category: category);
  return switch (source) {
    WallpaperSource.prism => PrismFeedItem(
      id: id,
      wallpaper: PrismWallpaper(core: core, tags: tags),
    ),
    WallpaperSource.wallhaven => WallhavenFeedItem(
      id: id,
      wallpaper: WallhavenWallpaper(core: core, tags: tags),
    ),
    _ => PexelsFeedItem(
      id: id,
      wallpaper: PexelsWallpaper(core: core),
    ),
  };
}

void main() {
  late _Firestore firestore;
  late _Wallhaven wallhaven;
  late _Pexels pexels;
  late WallpaperRecommendationRepositoryImpl repository;
  late _Blocks blocks;
  late SettingsLocalDataSource settings;
  List<FeedItemEntity> local = [];
  setUp(() {
    firestore = _Firestore();
    wallhaven = _Wallhaven();
    pexels = _Pexels();
    blocks = _Blocks();
    when(() => blocks.getBlockedCreatorEmails(waitForInitialLoad: true)).thenAnswer((_) async => {'blocked@x.com'});
    settings = SettingsLocalDataSource(InMemoryLocalStore());
    local = [];
    repository = WallpaperRecommendationRepositoryImpl(
      firestore: () => firestore,
      wallhaven: () => wallhaven,
      pexels: () => pexels,
      settings: () => settings,
      blocks: () => blocks,
      localSearch: (_) async => local,
    );
  });

  test('raw last Firestore document advances past blocked and anime rows', () async {
    firestore.rows = [
      for (var i = 0; i < 24; i++)
        {
          'id': '$i',
          'category': 'Nature',
          'review': true,
          'email': i == 23 ? 'blocked@x.com' : '',
          'tags': i == 22 ? ['anime'] : <String>[],
        },
    ];
    final page = await repository.load(current: _item('current'), sessionKey: 'a', discoveryOnly: false);
    expect(page.items.map((item) => item.id), [for (var i = 0; i < 22; i++) '$i']);
    expect(page.nextCursor, const PrismRecommendationCursor('doc-23'));
    firestore.rows = [
      {'id': 'next', 'category': 'Nature', 'review': true},
    ];
    final next = await repository.load(
      current: _item('current'),
      sessionKey: 'a',
      discoveryOnly: false,
      cursor: page.nextCursor,
    );
    expect(next.items.map((item) => item.id), ['next']);
    expect(next.nextCursor, isNull);
    expect(firestore.specs.last.startAfterDocId, 'doc-23');
    expect(firestore.specs.first.filters.map((filter) => (filter.field, filter.value)), [
      ('category', 'Nature'),
      ('review', true),
    ]);
  });

  test('Wallhaven visits do not share each other or search cursors; release is scoped', () async {
    final keys = <String>[];
    final refreshes = <bool>[];
    when(
      () => wallhaven.fetchFeed(
        categoryName: 'space',
        refresh: any(named: 'refresh'),
        paginationKey: any(named: 'paginationKey'),
        startPage: any(named: 'startPage'),
        categories: 100,
        purity: 100,
      ),
    ).thenAnswer((call) async {
      keys.add(call.namedArguments[#paginationKey] as String);
      refreshes.add(call.namedArguments[#refresh] as bool);
      return Result.success([(_item('found', source: WallpaperSource.wallhaven) as WallhavenFeedItem).wallpaper]);
    });
    when(() => wallhaven.hasMoreForCategory('space', paginationKey: any(named: 'paginationKey'))).thenReturn(true);
    final current = _item('current', source: WallpaperSource.wallhaven, tags: [' space ', 'SPACE']);
    final page = await repository.load(current: current, sessionKey: 'visit-a', discoveryOnly: false);
    await repository.load(current: current, sessionKey: 'visit-b', discoveryOnly: false);
    final next = await repository.load(
      current: current,
      sessionKey: 'visit-a',
      discoveryOnly: false,
      cursor: page.nextCursor,
    );
    expect(next.items.map((item) => item.id), ['found']);
    expect(keys, ['detail:visit-a:wallhaven', 'detail:visit-b:wallhaven', 'detail:visit-a:wallhaven']);
    expect(refreshes, [true, true, false]);
    repository.release('visit-a');
    verify(() => wallhaven.releasePaginationKey('detail:visit-a:wallhaven')).called(1);
    verifyNever(() => wallhaven.releasePaginationKey('detail:visit-b:wallhaven'));
  });

  test('Pexels is curated discovery, never invented similarity', () async {
    when(
      () => pexels.fetchFeed(categoryName: 'Curated', refresh: true, startPage: 1, paginationKey: 'detail:p:pexels'),
    ).thenAnswer(
      (_) async => Result.success([(_item('photo', source: WallpaperSource.pexels) as PexelsFeedItem).wallpaper]),
    );
    when(() => pexels.hasMoreForCategory('Curated', paginationKey: 'detail:p:pexels')).thenReturn(true);
    final page = await repository.load(
      current: _item('current', source: WallpaperSource.pexels),
      sessionKey: 'p',
      discoveryOnly: false,
    );
    expect(page.items.map((item) => item.id), ['photo']);
    expect(page.kind, RecommendationKind.discovery);
    expect(page.nextCursor, const ExternalRecommendationCursor(2, provider: RecommendationProvider.pexels));
  });

  test('initial network failure uses local discovery but append failure remains retryable', () async {
    firestore.fail = true;
    local = [_item('saved')];
    final page = await repository.load(current: _item('current'), sessionKey: 'a', discoveryOnly: false);
    expect(page.items.map((item) => item.id), ['saved']);
    expect(page.kind, RecommendationKind.offline);
    expect(page.nextCursor, isNull);
    await expectLater(
      repository.load(
        current: _item('current'),
        sessionKey: 'a',
        discoveryOnly: false,
        cursor: const PrismRecommendationCursor('last'),
      ),
      throwsStateError,
    );
    local = [];
    await expectLater(
      repository.load(current: _item('current'), sessionKey: 'b', discoveryOnly: false),
      throwsStateError,
    );
  });

  test('download discovery does not claim a same-category match', () async {
    firestore.rows = [
      {'id': 'general', 'review': true},
    ];
    final page = await repository.load(current: _item('download'), sessionKey: 'local', discoveryOnly: true);
    expect(page.kind, RecommendationKind.discovery);
    expect(page.items.map((item) => item.id), ['general']);
    expect(firestore.specs.single.filters.map((filter) => filter.field), ['review']);
  });

  test('Wallhaven enrichment cannot change the query halfway through a visit', () async {
    final queries = <String>[];
    when(
      () => wallhaven.fetchFeed(
        categoryName: any(named: 'categoryName'),
        refresh: any(named: 'refresh'),
        startPage: any(named: 'startPage'),
        paginationKey: any(named: 'paginationKey'),
        categories: 100,
        purity: 100,
      ),
    ).thenAnswer((call) async {
      queries.add(call.namedArguments[#categoryName] as String);
      return Result.success(const <WallhavenWallpaper>[]);
    });
    when(() => wallhaven.hasMoreForCategory(any(), paginationKey: any(named: 'paginationKey'))).thenReturn(true);
    final first = await repository.load(
      current: _item('wall', source: WallpaperSource.wallhaven),
      sessionKey: 'visit',
      discoveryOnly: false,
    );
    final next = await repository.load(
      current: _item('wall', source: WallpaperSource.wallhaven, tags: ['space']),
      sessionKey: 'visit',
      discoveryOnly: false,
      cursor: first.nextCursor,
    );
    expect(queries, ['', '']);
    expect(next.kind, RecommendationKind.discovery);
  });

  test('Wallhaven fallback continues Pexels page two without returning to Wallhaven', () async {
    var wallhavenCalls = 0;
    final pages = <int>[];
    when(
      () => wallhaven.fetchFeed(
        categoryName: '',
        refresh: true,
        paginationKey: 'detail:fallback:wallhaven',
        startPage: 1,
        categories: 100,
        purity: 100,
      ),
    ).thenAnswer((_) async {
      wallhavenCalls++;
      return Result.error(const ServerFailure('offline'));
    });
    when(
      () => pexels.fetchFeed(
        categoryName: 'Curated',
        refresh: any(named: 'refresh'),
        startPage: any(named: 'startPage'),
        paginationKey: 'detail:fallback:pexels',
      ),
    ).thenAnswer((call) async {
      final page = call.namedArguments[#startPage] as int;
      pages.add(page);
      return Result.success([(_item('photo-$page', source: WallpaperSource.pexels) as PexelsFeedItem).wallpaper]);
    });
    when(() => pexels.hasMoreForCategory('Curated', paginationKey: 'detail:fallback:pexels')).thenReturn(true);
    final first = await repository.load(
      current: _item('wall', source: WallpaperSource.wallhaven),
      sessionKey: 'fallback',
      discoveryOnly: false,
    );
    final next = await repository.load(
      current: _item('wall', source: WallpaperSource.wallhaven, tags: ['new tag']),
      sessionKey: 'fallback',
      discoveryOnly: false,
      cursor: first.nextCursor,
    );
    expect(wallhavenCalls, 1);
    expect(pages, [1, 2]);
    expect(next.items.single.id, 'photo-2');
    expect(next.kind, RecommendationKind.discovery);
  });

  test('offline Wallhaven recommendations respect category flags, including anime', () async {
    firestore.fail = true;
    await settings.set('WHpurity', 111);
    local = [
      _item('general', source: WallpaperSource.wallhaven, category: 'general'),
      _item('anime', source: WallpaperSource.wallhaven, category: 'anime'),
      _item('people', source: WallpaperSource.wallhaven, category: 'people'),
      _item('tag-anime', source: WallpaperSource.wallhaven, tags: ['anime']),
    ];
    final page = await repository.load(current: _item('wall'), sessionKey: 'offline', discoveryOnly: false);
    expect(page.items.map((item) => item.id), ['general']);
    expect(page.kind, RecommendationKind.offline);
  });

  test('restricted purity excludes unverifiable offline Wallhaven but preserves other providers', () async {
    firestore.fail = true;
    local = [
      _item('cached-wallhaven', source: WallpaperSource.wallhaven, category: 'general'),
      _item('saved-prism'),
      _item('saved-pexels', source: WallpaperSource.pexels),
    ];
    await settings.set('WHpurity', 111);
    final unrestricted = await repository.load(
      current: _item('wall'),
      sessionKey: 'unrestricted',
      discoveryOnly: false,
    );
    expect(unrestricted.items.map((item) => item.id), ['cached-wallhaven', 'saved-prism', 'saved-pexels']);
    for (final purity in [100, 110]) {
      await settings.set('WHpurity', purity);
      final restricted = await repository.load(
        current: _item('wall'),
        sessionKey: 'restricted-$purity',
        discoveryOnly: false,
      );
      expect(restricted.items.map((item) => item.id), ['saved-prism', 'saved-pexels']);
      expect(restricted.kind, RecommendationKind.offline);
    }
    local = [local.first];
    await expectLater(
      repository.load(current: _item('wall'), sessionKey: 'only-unverifiable', discoveryOnly: false),
      throwsStateError,
    );
  });

  for (final source in [WallpaperSource.wallhaven, WallpaperSource.pexels]) {
    test('released $source visit cannot recreate real provider caches after delayed completion', () async {
      final wh = WallhavenWallpaperRepositoryImpl(FakeFeedCacheLocalDataSource());
      final px = PexelsWallpaperRepositoryImpl(FakeFeedCacheLocalDataSource());
      final repo = WallpaperRecommendationRepositoryImpl(
        firestore: () => firestore,
        wallhaven: () => wh,
        pexels: () => px,
        blocks: () => blocks,
        settings: () => settings,
        localSearch: (_) async => throw StateError('released visits must not fall back'),
      );
      final started = Completer<void>();
      final response = Completer<http.Response>();
      await http.runWithClient(
        () async {
          final pending = repo.load(
            current: _item('wall', source: source),
            sessionKey: 'late',
            discoveryOnly: false,
          );
          final failure = expectLater(pending, throwsStateError);
          await started.future;
          repo.release('late');
          expect(wh.activePaginationSessions, 0);
          expect(px.activePaginationSessions, 0);
          response.complete(
            http.Response(
              jsonEncode(
                source == WallpaperSource.wallhaven
                    ? {
                        'data': <Object?>[],
                        'meta': {'current_page': 1, 'last_page': 1},
                      }
                    : {'photos': <Object?>[], 'page': 1, 'per_page': 24},
              ),
              200,
            ),
          );
          await failure;
          expect(wh.activePaginationSessions, 0);
          expect(px.activePaginationSessions, 0);
          wh.hasMoreForCategory('', paginationKey: 'detail:late:wallhaven');
          px.hasMoreForCategory('Curated', paginationKey: 'detail:late:pexels');
          expect(wh.activePaginationSessions, 0, reason: 'cursor reads must not allocate a new cache');
          expect(px.activePaginationSessions, 0, reason: 'cursor reads must not allocate a new cache');
        },
        () => MockClient((_) {
          started.complete();
          return response.future;
        }),
      );
    });
  }
}
