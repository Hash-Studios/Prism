import 'dart:async';
import 'dart:ui';

import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
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

  setUp(() {
    prism = _MockPrismRepository();
    palette = _MockPaletteRepository();
    wallhaven = _MockWallhavenRepository();
    views = _MockRecordViews();
    setCount = _MockSetCount();
    when(() => setCount(any())).thenAnswer((_) async => Result.success<int?>(null));
    when(() => palette.generatePalette(any())).thenAnswer((_) async => Result.error(const NetworkFailure('x')));
    when(() => views(any())).thenAnswer((_) async => Result.success('7'));
    bloc = WallpaperDetailBloc(prism, wallhaven, _MockPexelsRepository(), views, palette, setCount);
    addTearDown(bloc.close);
  });

  Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 10));

  test('a failed fetch never shows the raw failure text and keeps the thumbnail for the error screen', () async {
    when(() => prism.fetchById('abc')).thenAnswer(
      (_) async =>
          Result.error(const ServerFailure('[cloud_firestore/unavailable] The service is currently unavailable')),
    );

    bloc.add(const LoadFromId(wallId: 'abc', source: WallpaperSource.prism, thumbnailUrl: 'https://img/t.jpg'));
    await settle();

    expect(
      bloc.state,
      const WallpaperDetailError(message: 'Check your connection and try again.', thumbnailUrl: 'https://img/t.jpg'),
    );
  });

  test('a network failure also reads as a connection problem', () async {
    when(() => prism.fetchById('abc')).thenAnswer((_) async => Result.error(const NetworkFailure('No connection')));

    bloc.add(const LoadFromId(wallId: 'abc', source: WallpaperSource.prism));
    await settle();

    expect(bloc.state, const WallpaperDetailError(message: 'Check your connection and try again.'));
  });

  test('a missing wallpaper keeps the not found message', () async {
    when(() => prism.fetchById('abc')).thenAnswer((_) async => Result.success<PrismWallpaper?>(null));

    bloc.add(const LoadFromId(wallId: 'abc', source: WallpaperSource.prism));
    await settle();

    expect(bloc.state, const WallpaperDetailError(message: 'Wallpaper not found'));
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
    when(() => prism.fetchById('abc')).thenAnswer((_) async => Result.success(_wallpaper));
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
    await settle();

    final state = bloc.state as WallpaperDetailLoaded;
    expect(state.paletteLoading, isFalse);
    expect(state.colors, const <Color>[Color(0xffff0000)]);
    verify(() => palette.generatePalette('/tmp/download.jpg')).called(1);
  });

  test('a fetch that completes after the bloc closes does not enqueue views', () async {
    final fetch = Completer<Result<PrismWallpaper?>>();
    when(() => prism.fetchById('abc')).thenAnswer((_) => fetch.future);

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
