import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/constants/app_constants.dart' as app_constants;
import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/firestore/dtos/wall_doc_dto.dart';
import 'package:Prism/core/offline/durable_json_store.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/data/offline/bundled_wallpapers.dart';
import 'package:Prism/data/offline/offline_wallpaper_catalog.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/favourite_walls/data/favourite_wall_doc_mapper.dart';
import 'package:Prism/features/favourite_walls/domain/entities/favourite_wall_entity.dart';
import 'package:Prism/features/pexels_feed/domain/repositories/pexels_wallpaper_repository.dart';
import 'package:Prism/features/prism_feed/domain/repositories/prism_wallpaper_repository.dart';
import 'package:Prism/features/wallhaven_feed/domain/repositories/wallhaven_wallpaper_repository.dart';
import 'package:Prism/features/wallpaper_detail/biz/bloc/wallpaper_detail_bloc.dart';
import 'package:Prism/features/wallpaper_detail/biz/bloc/wallpaper_detail_event.dart';
import 'package:Prism/features/wallpaper_detail/biz/bloc/wallpaper_detail_state.dart';
import 'package:Prism/features/wallpaper_detail/domain/entities/palette_entity.dart';
import 'package:Prism/features/wallpaper_detail/domain/repositories/palette_repository.dart';
import 'package:Prism/features/wallpaper_detail/domain/usecases/wallpaper_stats_usecases.dart';
import 'package:Prism/features/wallpaper_detail/domain/usecases/wallpaper_views_usecase.dart';
import 'package:Prism/features/wallpaper_upload/domain/entities/wall_metadata.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockPrismRepository extends Mock implements PrismWallpaperRepository {}

class _MockWallhavenRepository extends Mock implements WallhavenWallpaperRepository {}

class _MockPexelsRepository extends Mock implements PexelsWallpaperRepository {}

class _MockRecordViews extends Mock implements RecordPrismWallpaperViewsUsecase {}

class _MockPaletteRepository extends Mock implements PaletteRepository {}

class _MockSetCount extends Mock implements GetWallpaperSetCountUseCase {}

const PrismWallpaper _wallpaper = PrismWallpaper(
  core: WallpaperCore(
    id: 'abc',
    source: WallpaperSource.prism,
    fullUrl: 'https://example.com/abc.jpg',
    thumbnailUrl: 'https://example.com/abc-thumb.jpg',
  ),
);

void main() {
  late _MockPrismRepository prism;
  late _MockPaletteRepository palette;
  late _MockWallhavenRepository wallhaven;
  late _MockRecordViews views;
  late _MockSetCount setCount;
  late WallpaperDetailBloc bloc;
  late Directory catalogDirectory;

  setUp(() async {
    catalogDirectory = await Directory.systemTemp.createTemp('wallpaper-detail-catalog-');
    prism = _MockPrismRepository();
    when(() => prism.fetchCanonicalByDocumentId(any())).thenAnswer((_) async => Result.success<PrismWallpaper?>(null));
    when(() => prism.fetchCanonicalById(any())).thenAnswer((invocation) async {
      final id = invocation.positionalArguments.first as String;
      if (id == 'abc') return Result.success(_wallpaper);
      return Result.success(
        PrismWallpaper(
          core: WallpaperCore(
            id: id,
            source: WallpaperSource.prism,
            fullUrl: _wallpaper.core.fullUrl,
            thumbnailUrl: _wallpaper.core.thumbnailUrl,
          ),
        ),
      );
    });
    palette = _MockPaletteRepository();
    wallhaven = _MockWallhavenRepository();
    views = _MockRecordViews();
    setCount = _MockSetCount();
    when(() => setCount(any())).thenAnswer((_) async => Result.success<int?>(null));
    when(() => palette.generatePalette(any())).thenAnswer((_) async => Result.error(const NetworkFailure('x')));
    when(() => views(any())).thenAnswer((_) async => Result.success('7'));
    final OfflineWallpaperCatalog catalog = OfflineWallpaperCatalog(
      store: DurableJsonStore('catalog', directory: catalogDirectory),
    );
    bloc = WallpaperDetailBloc(prism, wallhaven, _MockPexelsRepository(), views, palette, setCount, catalog);
    addTearDown(bloc.close);
    addTearDown(() => catalogDirectory.delete(recursive: true));
  });

  Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 40));

  Future<void> waitForLookup() async {
    bool completed(WallpaperDetailState state) =>
        state is WallpaperDetailError ||
        (state is WallpaperDetailLoaded && !state.paletteLoading && !state.viewsLoading);
    if (completed(bloc.state)) return;
    await bloc.stream.firstWhere(completed).timeout(const Duration(seconds: 10));
  }

  group('metadata refresh', () {
    const owned = PrismWallpaper(
      core: WallpaperCore(id: 'editable', source: WallpaperSource.prism, fullUrl: '', thumbnailUrl: ''),
      firestoreDocumentId: 'wall_doc.jpg',
      title: 'Before',
      description: 'Old description',
      tags: ['old'],
      review: true,
      remixOf: 'original-doc',
      remixCount: 3,
      isStreakExclusive: true,
    );
    const saved = WallMetadataSnapshot(
      metadata: PendingWallMetadata(
        text: WallTextMetadata(title: 'After', description: 'New description', tags: ['new']),
      ),
      approved: true,
      revision: 'rev-2',
    );

    Future<void> open() async {
      when(() => prism.fetchCanonicalById('editable')).thenAnswer((_) async => Result.success(owned));
      bloc.add(const LoadFromId(wallId: 'editable', source: WallpaperSource.prism));
      await waitForLookup();
      bloc.add(const OnPanelOpened());
      await pumpEventQueue();
    }

    test('saved text updates visible entity immediately and leaves unrelated wall and panel state intact', () async {
      await open();
      final read = Completer<Result<PrismWallpaper?>>();
      when(() => prism.fetchCanonicalByDocumentId('wall_doc.jpg')).thenAnswer((_) => read.future);
      bloc.add(const RefreshWallMetadata(wallDocId: 'wall_doc.jpg', saved: saved));
      await pumpEventQueue();
      final state = bloc.state as WallpaperDetailLoaded;
      final wall = (state.entity as PrismFeedItem).wallpaper;
      expect(wall.title, 'After');
      expect(wall.description, 'New description');
      expect(wall.tags, ['new']);
      expect(wall.remixOf, 'original-doc');
      expect(wall.remixCount, 3);
      expect(wall.isStreakExclusive, isTrue);
      expect(state.panelCollapsed, isFalse);
      read.complete(Result.error(const NetworkFailure('offline')));
      await pumpEventQueue();
      expect(((bloc.state as WallpaperDetailLoaded).entity as PrismFeedItem).wallpaper.title, 'After');
    });

    test('history return refetches by Firestore document ID without another view or palette load', () async {
      await open();
      const reverted = PrismWallpaper(
        core: WallpaperCore(id: 'editable', source: WallpaperSource.prism, fullUrl: '', thumbnailUrl: ''),
        firestoreDocumentId: 'wall_doc.jpg',
        title: 'Reverted',
        description: 'Restored',
        tags: ['restored'],
      );
      when(() => prism.fetchCanonicalByDocumentId('wall_doc.jpg')).thenAnswer((_) async => Result.success(reverted));
      clearInteractions(views);
      clearInteractions(palette);
      bloc.add(const RefreshWallMetadata(wallDocId: 'wall_doc.jpg'));
      await pumpEventQueue();
      final state = bloc.state as WallpaperDetailLoaded;
      expect((state.entity as PrismFeedItem).wallpaper.title, 'Reverted');
      expect((state.entity as PrismFeedItem).wallpaper.tags, ['restored']);
      expect(state.panelCollapsed, isFalse);
      verifyNever(() => views(any()));
      verifyNever(() => palette.generatePalette(any()));
    });

    test('a pending metadata refresh cannot replace a different detail route', () async {
      await open();
      final read = Completer<Result<PrismWallpaper?>>();
      when(() => prism.fetchCanonicalByDocumentId('wall_doc.jpg')).thenAnswer((_) => read.future);
      bloc.add(const RefreshWallMetadata(wallDocId: 'wall_doc.jpg', saved: saved));
      await pumpEventQueue();
      bloc.add(const LoadFromId(wallId: 'other', source: WallpaperSource.prism));
      await pumpEventQueue();
      read.complete(Result.success(owned));
      await pumpEventQueue();
      expect((bloc.state as WallpaperDetailLoaded).entity.id, 'other');
    });
  });

  test('a stale Prism entity cannot open detail when the canonical wall is unavailable', () async {
    when(() => prism.fetchCanonicalById('abc')).thenAnswer((_) async => Result.success<PrismWallpaper?>(null));
    bloc.add(
      const LoadFromEntity(
        entity: PrismFeedItem(id: 'abc', wallpaper: _wallpaper),
      ),
    );
    await waitForLookup();
    expect(
      bloc.state,
      const WallpaperDetailError(
        failure: WallpaperDetailLoadFailure.notFound,
        thumbnailUrl: 'https://example.com/abc-thumb.jpg',
      ),
    );
    verifyNever(() => palette.generatePalette(any()));
    verifyNever(() => prism.fetchCanonicalByDocumentId(any()));
  });

  group('Drop walls', () {
    // An unreleased Drop wall is unreviewed, so the canonical lookup never finds it.
    setUp(() {
      when(() => prism.fetchCanonicalById(any())).thenAnswer((_) async => Result.success<PrismWallpaper?>(null));
      app_state.prismUser = app_constants.createGuestPrismUser()
        ..id = 'alice'
        ..loggedIn = true;
      CoinsService.instance.setDropUnlocksForTest(const <String, DropUnlock>{
        'abc': DropUnlock(wallId: 'abc', weekKey: '2026-W43', url: 'https://example.com/abc.jpg'),
      });
      addTearDown(() {
        CoinsService.instance.dropsUnlockedNotifier.value = const <String, DropUnlock>{};
        app_state.prismUser = app_constants.createGuestPrismUser();
      });
    });

    test('an unlocked Drop wall opens with the url its unlock gave this account', () async {
      bloc.add(
        const LoadFromEntity(
          entity: PrismFeedItem(id: 'abc', wallpaper: _wallpaper),
        ),
      );
      await waitForLookup();
      expect(bloc.state, isA<WallpaperDetailLoaded>());
      expect((bloc.state as WallpaperDetailLoaded).entity.fullUrl, 'https://example.com/abc.jpg');
      verifyNever(() => prism.fetchCanonicalById(any()));
    });

    test('a Prism entity with another url still needs the canonical wall', () async {
      bloc.add(
        const LoadFromEntity(
          entity: PrismFeedItem(
            id: 'abc',
            wallpaper: PrismWallpaper(
              core: WallpaperCore(
                id: 'abc',
                source: WallpaperSource.prism,
                fullUrl: 'https://example.com/other.jpg',
                thumbnailUrl: 'https://example.com/abc-thumb.jpg',
              ),
            ),
          ),
        ),
      );
      await waitForLookup();
      expect(bloc.state, isA<WallpaperDetailError>());
    });
  });

  test('a saved favourite with only an author name opens with the canonical creator email', () async {
    // Saved favourites keep only `photographer`. The profile link needs the email (#540).
    final FavouriteWallEntity saved = mapFavouriteWallDoc(
      FavouriteWallDocDto.fromJson(const <String, dynamic>{
        'id': 'abc',
        'provider': 'Prism',
        'url': 'https://example.com/abc.jpg',
        'thumb': 'https://example.com/abc-thumb.jpg',
        'photographer': 'Display Name',
      }),
      'favourite-doc',
    );
    final FeedItemEntity fromFavourites = saved.toFeedItem();
    expect((fromFavourites as PrismFeedItem).wallpaper.core.authorEmail, isNull);
    when(() => prism.fetchCanonicalById('abc')).thenAnswer(
      (_) async => Result.success<PrismWallpaper?>(
        const PrismWallpaper(
          core: WallpaperCore(
            id: 'abc',
            source: WallpaperSource.prism,
            fullUrl: 'https://example.com/abc.jpg',
            thumbnailUrl: 'https://example.com/abc-thumb.jpg',
            authorName: 'Display Name',
            authorEmail: 'creator@example.com',
          ),
        ),
      ),
    );

    bloc.add(LoadFromEntity(entity: fromFavourites));
    await waitForLookup();

    final FeedItemEntity loaded = (bloc.state as WallpaperDetailLoaded).entity;
    expect((loaded as PrismFeedItem).wallpaper.core.authorEmail, 'creator@example.com');
  });

  test('an explicit document-ID deep link resolves to a fresh canonical wallpaper', () async {
    when(() => prism.fetchCanonicalById('document-id')).thenAnswer((_) async => Result.success<PrismWallpaper?>(null));
    when(() => prism.fetchCanonicalByDocumentId('document-id')).thenAnswer((_) async => Result.success(_wallpaper));
    bloc.add(const LoadFromId(wallId: 'document-id', source: WallpaperSource.prism));
    await waitForLookup();
    expect((bloc.state as WallpaperDetailLoaded).entity.id, 'abc');
    verify(() => prism.fetchCanonicalByDocumentId('document-id')).called(1);
  });

  test('a feed entity whose ID came from its document resolves through the protected document lookup', () async {
    const wallpaper = PrismWallpaper(
      core: WallpaperCore(id: 'document-id', source: WallpaperSource.prism, fullUrl: '', thumbnailUrl: ''),
      firestoreDocumentId: 'document-id',
    );
    when(() => prism.fetchCanonicalById('document-id')).thenAnswer((_) async => Result.success<PrismWallpaper?>(null));
    when(() => prism.fetchCanonicalByDocumentId('document-id')).thenAnswer((_) async => Result.success(wallpaper));
    bloc.add(
      const LoadFromEntity(
        entity: PrismFeedItem(id: 'document-id', wallpaper: wallpaper),
      ),
    );
    await waitForLookup();
    expect((bloc.state as WallpaperDetailLoaded).entity.id, 'document-id');
    verify(() => prism.fetchCanonicalByDocumentId('document-id')).called(1);
  });

  test('an arbitrary cached file does not bypass Prism canonical freshness', () async {
    when(() => prism.fetchCanonicalById('abc')).thenAnswer((_) async => Result.success<PrismWallpaper?>(null));
    bloc.add(
      const LoadFromEntity(
        entity: PrismFeedItem(id: 'abc', wallpaper: _wallpaper),
        localFilePath: '/cache/unproven.jpg',
      ),
    );
    await waitForLookup();
    expect(bloc.state, isA<WallpaperDetailError>());
    verifyNever(() => palette.generatePalette(any()));
    verifyNever(() => prism.fetchCanonicalByDocumentId(any()));
  });

  test('a failed fetch never shows the raw failure text and keeps the thumbnail for the error screen', () async {
    when(() => prism.fetchCanonicalById('abc')).thenAnswer(
      (_) async =>
          Result.error(const ServerFailure('[cloud_firestore/unavailable] The service is currently unavailable')),
    );

    bloc.add(const LoadFromId(wallId: 'abc', source: WallpaperSource.prism, thumbnailUrl: 'https://img/t.jpg'));
    await waitForLookup();

    expect(
      bloc.state,
      const WallpaperDetailError(failure: WallpaperDetailLoadFailure.unavailable, thumbnailUrl: 'https://img/t.jpg'),
    );
  });

  test('a network failure also reads as a connection problem', () async {
    when(
      () => prism.fetchCanonicalById('abc'),
    ).thenAnswer((_) async => Result.error(const NetworkFailure('No connection')));

    bloc.add(const LoadFromId(wallId: 'abc', source: WallpaperSource.prism));
    await waitForLookup();

    expect(bloc.state, const WallpaperDetailError(failure: WallpaperDetailLoadFailure.unavailable));
  });

  test('a missing wallpaper keeps the not found message', () async {
    when(() => prism.fetchCanonicalById('abc')).thenAnswer((_) async => Result.success<PrismWallpaper?>(null));

    bloc.add(const LoadFromId(wallId: 'abc', source: WallpaperSource.prism));
    await waitForLookup();

    expect(bloc.state, const WallpaperDetailError(failure: WallpaperDetailLoadFailure.notFound));
  });

  test('a Prism ID lookup never uses stale local catalog after a transport failure', () async {
    final OfflineWallpaperCatalog catalog = OfflineWallpaperCatalog(
      store: DurableJsonStore('catalog', directory: catalogDirectory),
    );
    await catalog.remember(const <FeedItemEntity>[PrismFeedItem(id: 'abc', wallpaper: _wallpaper)]);
    when(() => prism.fetchCanonicalById('abc')).thenAnswer((_) async => Result.error(const NetworkFailure('offline')));
    bloc = WallpaperDetailBloc(prism, wallhaven, _MockPexelsRepository(), views, palette, setCount, catalog);
    addTearDown(bloc.close);

    bloc.add(const LoadFromId(wallId: 'abc', source: WallpaperSource.prism));
    await waitForLookup();

    expect(bloc.state, const WallpaperDetailError(failure: WallpaperDetailLoadFailure.unavailable));
    verify(() => prism.fetchCanonicalById('abc')).called(1);
  });

  test('a slow ID lookup succeeds when no saved fallback exists', () async {
    when(() => prism.fetchCanonicalById('abc')).thenAnswer((_) async {
      await Future<void>.delayed(const Duration(seconds: 3));
      return Result.success<PrismWallpaper?>(_wallpaper);
    });

    bloc.add(const LoadFromId(wallId: 'abc', source: WallpaperSource.prism));
    await waitForLookup();

    expect((bloc.state as WallpaperDetailLoaded).entity.id, 'abc');
    verify(() => prism.fetchCanonicalById('abc')).called(1);
  });

  test('saved Prism detail waits for the canonical server response', () async {
    final OfflineWallpaperCatalog catalog = OfflineWallpaperCatalog(
      store: DurableJsonStore('catalog', directory: catalogDirectory),
    );
    await catalog.remember(const <FeedItemEntity>[PrismFeedItem(id: 'abc', wallpaper: _wallpaper)]);
    bloc = WallpaperDetailBloc(prism, wallhaven, _MockPexelsRepository(), views, palette, setCount, catalog);
    addTearDown(bloc.close);
    when(() => prism.fetchCanonicalById('abc')).thenAnswer((_) async {
      await Future<void>.delayed(const Duration(seconds: 3));
      return Result.success<PrismWallpaper?>(_wallpaper);
    });

    final Stopwatch stopwatch = Stopwatch()..start();
    bloc.add(const LoadFromId(wallId: 'abc', source: WallpaperSource.prism));
    await waitForLookup();

    expect((bloc.state as WallpaperDetailLoaded).entity.id, 'abc');
    expect(stopwatch.elapsed, greaterThanOrEqualTo(const Duration(seconds: 3)));
    verify(() => prism.fetchCanonicalById('abc')).called(1);
  });

  test('a successful not-found response does not show stale catalog content', () async {
    final OfflineWallpaperCatalog catalog = OfflineWallpaperCatalog(
      store: DurableJsonStore('catalog', directory: catalogDirectory),
    );
    await catalog.remember(const <FeedItemEntity>[PrismFeedItem(id: 'abc', wallpaper: _wallpaper)]);
    bloc = WallpaperDetailBloc(prism, wallhaven, _MockPexelsRepository(), views, palette, setCount, catalog);
    addTearDown(bloc.close);
    when(() => prism.fetchCanonicalById('abc')).thenAnswer((_) async => Result.success<PrismWallpaper?>(null));

    bloc.add(const LoadFromId(wallId: 'abc', source: WallpaperSource.prism));
    await waitForLookup();

    expect(bloc.state, const WallpaperDetailError(failure: WallpaperDetailLoadFailure.notFound));
    verify(() => prism.fetchCanonicalById('abc')).called(1);
  });

  test('the set count of a Prism wall lands in the loaded state', () async {
    when(() => setCount('abc')).thenAnswer((_) async => Result.success<int?>(12));

    bloc.add(
      const LoadFromEntity(
        entity: PrismFeedItem(id: 'abc', wallpaper: _wallpaper),
      ),
    );
    await settle();

    expect((bloc.state as WallpaperDetailLoaded).setCount, 12);
  });

  test('a failed or empty set count leaves the state without a count', () async {
    when(() => setCount('abc')).thenAnswer((_) async => Result.error(const ServerFailure('offline')));

    bloc.add(
      const LoadFromEntity(
        entity: PrismFeedItem(id: 'abc', wallpaper: _wallpaper),
      ),
    );
    await settle();

    expect((bloc.state as WallpaperDetailLoaded).setCount, isNull);
  });

  test('walls from other sources never ask for a set count', () async {
    const WallhavenWallpaper wallhavenWall = WallhavenWallpaper(
      core: WallpaperCore(id: 'w', source: WallpaperSource.wallhaven, fullUrl: 'f', thumbnailUrl: 't', authorName: 'a'),
    );

    bloc.add(
      const LoadFromEntity(
        entity: WallhavenFeedItem(id: 'w', wallpaper: wallhavenWall),
      ),
    );
    await settle();

    verifyNever(() => setCount(any()));
  });

  test('bundled starter entities never request server-side views or set counts', () async {
    const FeedItemEntity starter = PrismFeedItem(
      id: 'starter-sunset',
      wallpaper: PrismWallpaper(
        core: WallpaperCore(
          id: 'starter-sunset',
          source: WallpaperSource.prism,
          fullUrl: '/local/starter-sunset.jpg',
          thumbnailUrl: '/local/starter-sunset.jpg',
        ),
      ),
    );
    expect(BundledWallpapers.isStarter(starter), isTrue);

    bloc.add(const LoadFromEntity(entity: starter));
    await settle();
    bloc.add(const FetchViews());
    bloc.add(const FetchSetCount());
    await settle();

    verifyNever(() => views(any()));
    verifyNever(() => setCount(any()));
  });

  test('palette colours land in the loaded state with similar shades removed', () async {
    when(() => palette.generatePalette(any())).thenAnswer(
      (_) async => Result.success(
        const PaletteEntity(
          imageUrl: 'https://example.com/abc-thumb.jpg',
          dominantColorValue: 0xffff0000,
          paletteColorValues: <int>[0xffff0000, 0xffff0505, 0xff0000ff],
        ),
      ),
    );

    bloc.add(
      const LoadFromEntity(
        entity: PrismFeedItem(id: 'abc', wallpaper: _wallpaper),
      ),
    );
    await settle();

    final state = bloc.state as WallpaperDetailLoaded;
    expect(state.paletteLoading, isFalse);
    expect(state.colors, const <Color>[Color(0xffff0000), Color(0xff0000ff)]);
    expect(state.accent, const Color(0xffff0000));
    expect(state.views, '7');
  });

  test('accent changes and panel gestures preserve the loaded wallpaper and reset user selection', () async {
    when(() => palette.generatePalette(any())).thenAnswer(
      (_) async => Result.success(
        const PaletteEntity(
          imageUrl: 'https://example.com/abc-thumb.jpg',
          dominantColorValue: 0xffff0000,
          paletteColorValues: [0xffff0000, 0xff0000ff],
        ),
      ),
    );
    bloc.add(
      const LoadFromEntity(
        entity: PrismFeedItem(id: 'abc', wallpaper: _wallpaper),
      ),
    );
    await waitForLookup();

    Future<WallpaperDetailLoaded> apply(WallpaperDetailEvent event) async {
      final next = bloc.stream.first;
      bloc.add(event);
      return await next as WallpaperDetailLoaded;
    }

    var state = await apply(const SelectAccentColor(color: Color(0xff00ff00)));
    expect(state.accent, const Color(0xff00ff00));
    state = await apply(const ResetAccentColor());
    expect(state.colorChanged, isFalse);
    state = await apply(const OnPanelOpened());
    expect((state.panelCollapsed, state.panelClosed), (false, false));
    state = await apply(const OnPanelScrollStart());
    expect(state.panelScrollInProgress, isTrue);
    state = await apply(const OnPanelScrollEnd());
    expect(state.panelScrollInProgress, isFalse);
    state = await apply(const OnPanelClosed());
    expect((state.panelCollapsed, state.panelClosed), (true, true));
    expect(state.entity.id, 'abc');
    expect(state.views, '7');
  });

  test('a failed palette stops the loading flag and keeps the accent empty', () async {
    when(() => palette.generatePalette(any())).thenAnswer((_) async => Result.error(const NetworkFailure('offline')));

    bloc.add(
      const LoadFromEntity(
        entity: PrismFeedItem(id: 'abc', wallpaper: _wallpaper),
      ),
    );
    await settle();

    final state = bloc.state as WallpaperDetailLoaded;
    expect(state.paletteLoading, isFalse);
    expect(state.colors, isNull);
    expect(state.accent, isNull);
  });

  test('a local file supplies the palette when the wallpaper has no thumbnail', () async {
    const entity = PrismFeedItem(
      id: 'abc',
      wallpaper: PrismWallpaper(
        core: WallpaperCore(
          id: 'abc',
          source: WallpaperSource.prism,
          fullUrl: 'https://example.com/abc.jpg',
          thumbnailUrl: '',
        ),
      ),
    );
    when(() => palette.generatePalette('/tmp/download.jpg')).thenAnswer(
      (_) async => Result.success(
        const PaletteEntity(
          imageUrl: '/tmp/download.jpg',
          dominantColorValue: 0xffff0000,
          paletteColorValues: [0xffff0000],
        ),
      ),
    );

    bloc.add(const LoadFromEntity(entity: entity, localFilePath: '/tmp/download.jpg'));
    await settle();

    final state = bloc.state as WallpaperDetailLoaded;
    expect(state.paletteLoading, isFalse);
    expect(state.colors, const <Color>[Color(0xffff0000)]);
    verify(() => palette.generatePalette('/tmp/download.jpg')).called(1);
  });

  test('an empty thumbnail settles palette loading when there is no local file', () async {
    const entity = PrismFeedItem(
      id: 'abc',
      wallpaper: PrismWallpaper(
        core: WallpaperCore(
          id: 'abc',
          source: WallpaperSource.prism,
          fullUrl: 'https://example.com/abc.jpg',
          thumbnailUrl: '',
        ),
      ),
    );

    when(() => prism.fetchCanonicalById('abc')).thenAnswer((_) async => Result.success(entity.wallpaper));
    bloc.add(const LoadFromEntity(entity: entity));
    await settle();

    expect((bloc.state as WallpaperDetailLoaded).paletteLoading, isFalse);
    verifyNever(() => palette.generatePalette(any()));
  });

  test('a palette result from an earlier wallpaper is ignored even if thumbnails match', () async {
    final firstPalette = Completer<Result<PaletteEntity>>();
    final secondPalette = Completer<Result<PaletteEntity>>();
    var requests = 0;
    when(
      () => palette.generatePalette(any()),
    ).thenAnswer((_) => requests++ == 0 ? firstPalette.future : secondPalette.future);

    bloc.add(
      const LoadFromEntity(
        entity: PrismFeedItem(id: 'first', wallpaper: _wallpaper),
      ),
    );
    await settle();
    bloc.add(
      const LoadFromEntity(
        entity: PrismFeedItem(id: 'second', wallpaper: _wallpaper),
      ),
    );
    await settle();
    secondPalette.complete(
      Result.success(
        const PaletteEntity(
          imageUrl: 'https://example.com/abc-thumb.jpg',
          dominantColorValue: 0xff0000ff,
          paletteColorValues: [0xff0000ff],
        ),
      ),
    );
    await settle();
    firstPalette.complete(
      Result.success(
        const PaletteEntity(
          imageUrl: 'https://example.com/abc-thumb.jpg',
          dominantColorValue: 0xffff0000,
          paletteColorValues: [0xffff0000],
        ),
      ),
    );
    await settle();

    expect((bloc.state as WallpaperDetailLoaded).entity.id, 'second');
    expect((bloc.state as WallpaperDetailLoaded).colors, const <Color>[Color(0xff0000ff)]);
  });

  test('LoadFromId uses the local image for palette generation', () async {
    when(() => prism.fetchCanonicalById('abc')).thenAnswer((_) async => Result.success(_wallpaper));
    when(() => palette.generatePalette('/tmp/download.jpg')).thenAnswer(
      (_) async => Result.success(
        const PaletteEntity(
          imageUrl: '/tmp/download.jpg',
          dominantColorValue: 0xffff0000,
          paletteColorValues: [0xffff0000],
        ),
      ),
    );

    bloc.add(const LoadFromId(wallId: 'abc', source: WallpaperSource.prism, localFilePath: '/tmp/download.jpg'));
    await waitForLookup();

    final state = bloc.state as WallpaperDetailLoaded;
    expect(state.paletteLoading, isFalse);
    expect(state.colors, const <Color>[Color(0xffff0000)]);
    verify(() => palette.generatePalette('/tmp/download.jpg')).called(1);
  });

  test('a fetch that completes after the bloc closes does not enqueue views', () async {
    final fetch = Completer<Result<PrismWallpaper?>>();
    when(() => prism.fetchCanonicalById('abc')).thenAnswer((_) => fetch.future);

    bloc.add(const LoadFromId(wallId: 'abc', source: WallpaperSource.prism));
    await settle();
    final closing = bloc.close();
    fetch.complete(Result.success(_wallpaper));
    await closing;

    verifyNever(() => views(any()));
  });

  test('an entity queued just before close does not enqueue views afterward', () async {
    when(() => palette.generatePalette(any())).thenAnswer((_) async => Result.error(const NetworkFailure('offline')));
    bloc.add(
      const LoadFromEntity(
        entity: PrismFeedItem(id: 'abc', wallpaper: _wallpaper),
      ),
    );

    await bloc.close();

    verifyNever(() => views(any()));
  });

  test('pending palette and views completions are ignored after close', () async {
    final pendingPalette = Completer<Result<PaletteEntity>>();
    final pendingViews = Completer<Result<String>>();
    when(() => palette.generatePalette(any())).thenAnswer((_) => pendingPalette.future);
    when(() => views(any())).thenAnswer((_) => pendingViews.future);

    bloc.add(
      const LoadFromEntity(
        entity: PrismFeedItem(id: 'abc', wallpaper: _wallpaper),
      ),
    );
    await pumpEventQueue();
    await bloc.close();
    pendingPalette.complete(
      Result.success(
        const PaletteEntity(
          imageUrl: 'https://example.com/abc-thumb.jpg',
          dominantColorValue: 0xffff0000,
          paletteColorValues: <int>[0xffff0000],
        ),
      ),
    );
    pendingViews.complete(Result.success('9'));
    await pumpEventQueue();

    expect(
      bloc.state,
      const WallpaperDetailLoaded(
        entity: PrismFeedItem(id: 'abc', wallpaper: _wallpaper),
        viewsLoading: true,
      ),
    );
  });

  test('pending wallhaven enrichment is ignored after close', () async {
    final pendingEnrichment = Completer<Result<WallhavenWallpaper?>>();
    when(() => wallhaven.fetchById('wallhaven-1')).thenAnswer((_) => pendingEnrichment.future);
    const wallpaper = WallhavenWallpaper(
      core: WallpaperCore(
        id: 'wallhaven-1',
        source: WallpaperSource.wallhaven,
        fullUrl: 'https://example.com/wallhaven.jpg',
        thumbnailUrl: '',
      ),
    );

    bloc.add(
      const LoadFromEntity(
        entity: WallhavenFeedItem(id: 'wallhaven-1', wallpaper: wallpaper),
      ),
    );
    await pumpEventQueue();
    await bloc.close();
    pendingEnrichment.complete(
      Result.success(
        const WallhavenWallpaper(
          core: WallpaperCore(
            id: 'wallhaven-1',
            source: WallpaperSource.wallhaven,
            fullUrl: 'https://example.com/wallhaven.jpg',
            thumbnailUrl: '',
            authorName: 'Author',
          ),
        ),
      ),
    );
    await pumpEventQueue();

    expect(
      bloc.state,
      const WallpaperDetailLoaded(
        entity: WallhavenFeedItem(id: 'wallhaven-1', wallpaper: wallpaper),
        paletteLoading: false,
      ),
    );
  });
}
