import 'dart:ui';

import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/features/pexels_feed/domain/repositories/pexels_wallpaper_repository.dart';
import 'package:Prism/features/prism_feed/domain/repositories/prism_wallpaper_repository.dart';
import 'package:Prism/features/wallhaven_feed/domain/repositories/wallhaven_wallpaper_repository.dart';
import 'package:Prism/features/wallpaper_detail/biz/bloc/wallpaper_detail_bloc.dart';
import 'package:Prism/features/wallpaper_detail/biz/bloc/wallpaper_detail_event.dart';
import 'package:Prism/features/wallpaper_detail/biz/bloc/wallpaper_detail_state.dart';
import 'package:Prism/features/wallpaper_detail/domain/entities/palette_entity.dart';
import 'package:Prism/features/wallpaper_detail/domain/entities/wallpaper_detail_entity.dart';
import 'package:Prism/features/wallpaper_detail/domain/repositories/palette_repository.dart';
import 'package:Prism/features/wallpaper_detail/domain/usecases/wallpaper_views_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockPrismRepository extends Mock implements PrismWallpaperRepository {}

class _MockWallhavenRepository extends Mock implements WallhavenWallpaperRepository {}

class _MockPexelsRepository extends Mock implements PexelsWallpaperRepository {}

class _MockRecordViews extends Mock implements RecordPrismWallpaperViewsUsecase {}

class _MockPaletteRepository extends Mock implements PaletteRepository {}

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
  late WallpaperDetailBloc bloc;

  setUp(() {
    prism = _MockPrismRepository();
    palette = _MockPaletteRepository();
    final views = _MockRecordViews();
    when(() => views(any())).thenAnswer((_) async => Result.success('7'));
    bloc = WallpaperDetailBloc(prism, _MockWallhavenRepository(), _MockPexelsRepository(), views, palette);
    addTearDown(bloc.close);
  });

  Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 10));

  test('a failed fetch shows the failure message without an Exception prefix', () async {
    when(() => prism.fetchById('abc')).thenAnswer((_) async => Result.error(const NetworkFailure('No connection')));

    bloc.add(const LoadFromId(wallId: 'abc', source: WallpaperSource.prism));
    await settle();

    expect(bloc.state, const WallpaperDetailError(message: 'No connection'));
  });

  test('a missing wallpaper shows a not found message', () async {
    when(() => prism.fetchById('abc')).thenAnswer((_) async => Result.success<PrismWallpaper?>(null));

    bloc.add(const LoadFromId(wallId: 'abc', source: WallpaperSource.prism));
    await settle();

    expect(bloc.state, const WallpaperDetailError(message: 'Wallpaper not found'));
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

    bloc.add(const LoadFromEntity(entity: PrismDetailEntity(wallpaper: _wallpaper)));
    await settle();

    final state = bloc.state as WallpaperDetailLoaded;
    expect(state.paletteLoading, isFalse);
    expect(state.colors, const <Color>[Color(0xffff0000), Color(0xff0000ff)]);
    expect(state.accent, const Color(0xffff0000));
    expect(state.views, '7');
  });

  test('a failed palette stops the loading flag and keeps the accent empty', () async {
    when(() => palette.generatePalette(any())).thenAnswer((_) async => Result.error(const NetworkFailure('offline')));

    bloc.add(const LoadFromEntity(entity: PrismDetailEntity(wallpaper: _wallpaper)));
    await settle();

    final state = bloc.state as WallpaperDetailLoaded;
    expect(state.paletteLoading, isFalse);
    expect(state.colors, isNull);
    expect(state.accent, isNull);
  });
}
