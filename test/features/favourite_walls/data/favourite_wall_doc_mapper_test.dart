import 'package:Prism/core/firestore/dtos/wall_doc_dto.dart';
import 'package:Prism/core/wallpaper/wall_depth.dart';
import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/features/favourite_walls/data/favourite_wall_doc_mapper.dart';
import 'package:Prism/features/favourite_walls/domain/entities/favourite_wall_entity.dart';
import 'package:flutter_test/flutter_test.dart';

PrismFavouriteWall _prismFav({WallDepthTier? depthTier}) => PrismFavouriteWall(
  id: 'w1',
  favouritedAt: DateTime.utc(2026, 1, 2),
  wallpaper: PrismWallpaper(
    core: const WallpaperCore(
      id: 'w1',
      source: WallpaperSource.prism,
      fullUrl: 'https://example.com/w1.jpg',
      thumbnailUrl: 'https://example.com/w1-thumb.jpg',
    ),
    depthTier: depthTier,
  ),
);

WallDepthTier? _depthTierAfterRoundTrip(PrismFavouriteWall wall) {
  final FavouriteWallEntity mapped = mapFavouriteWallDoc(
    FavouriteWallDocDto.fromJson(favouriteWallToDoc(wall)),
    wall.id,
  );
  return (mapped as PrismFavouriteWall).wallpaper.depthTier;
}

void main() {
  test('a Prism favourite keeps its Depth Effect tier through the doc', () {
    for (final WallDepthTier tier in WallDepthTier.values) {
      expect(_depthTierAfterRoundTrip(_prismFav(depthTier: tier)), tier, reason: tier.name);
    }
  });

  test('the doc of a favourite with a tier carries only that tier', () {
    expect(favouriteWallToDoc(_prismFav(depthTier: WallDepthTier.menu))['depth'], <String, Object?>{'tier': 'menu'});
  });

  test('a favourite without a tier writes no depth and maps back to null', () {
    expect(favouriteWallToDoc(_prismFav()), isNot(contains('depth')));
    expect(_depthTierAfterRoundTrip(_prismFav()), isNull);
  });

  test('a stored favourite doc without depth maps to a null tier', () {
    final FavouriteWallEntity mapped = mapFavouriteWallDoc(
      FavouriteWallDocDto.fromJson(<String, dynamic>{
        'id': 'w1',
        'provider': 'Prism',
        'url': 'https://example.com/w1.jpg',
        'thumb': 'https://example.com/w1-thumb.jpg',
      }),
      'w1',
    );

    expect((mapped as PrismFavouriteWall).wallpaper.depthTier, isNull);
  });

  test('the retry write of a favourite keeps the tier', () {
    final FavouriteWallDocDto dto = FavouriteWallDocDto.fromJson(
      favouriteWallToDoc(_prismFav(depthTier: WallDepthTier.auto)),
    );

    expect(dto.toJson()['depth'], <String, Object?>{'tier': 'auto'});
  });

  test('a saved Wallhaven favourite restores its published favourite total on the core', () {
    final mapped =
        mapFavouriteWallDoc(
              FavouriteWallDocDto.fromJson(<String, dynamic>{
                'id': 'wallhaven-id',
                'provider': 'Wallhaven',
                'url': 'https://example.com/wallhaven.jpg',
                'thumb': 'https://example.com/wallhaven-thumb.jpg',
                'fav': '42',
                'views': '1234',
              }),
              'wallhaven-id',
            )
            as WallhavenFavouriteWall;

    expect(mapped.wallpaper.core.favourites, 42);
    expect(mapped.wallpaper.views, 1234);
  });
}
