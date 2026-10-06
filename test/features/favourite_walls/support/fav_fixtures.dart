import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/features/favourite_walls/domain/entities/favourite_wall_entity.dart';

WallpaperCore _core(String id, WallpaperSource source, String? author, String? category, DateTime? createdAt) =>
    WallpaperCore(
      id: id,
      source: source,
      fullUrl: 'https://example.com/$id.jpg',
      thumbnailUrl: 'https://example.com/$id-thumb.jpg',
      authorName: author,
      category: category,
      createdAt: createdAt,
    );

FavouriteWallEntity prismFav(String id, {String? author, String? category, DateTime? createdAt}) => PrismFavouriteWall(
  id: id,
  wallpaper: PrismWallpaper(core: _core(id, WallpaperSource.prism, author, category, createdAt)),
);

FavouriteWallEntity wallhavenFav(String id, {String? category, DateTime? createdAt}) => WallhavenFavouriteWall(
  id: id,
  wallpaper: WallhavenWallpaper(core: _core(id, WallpaperSource.wallhaven, null, category, createdAt)),
);

FavouriteWallEntity pexelsFav(String id, {String? author, String? category, DateTime? createdAt}) =>
    PexelsFavouriteWall(
      id: id,
      wallpaper: PexelsWallpaper(
        core: _core(id, WallpaperSource.pexels, author, category, createdAt),
        photographer: author,
      ),
    );

FavouriteWallEntity legacyFav(String id, {String? author, String? category}) => LegacyFavouriteWall(
  id: id,
  source: WallpaperSource.unknown,
  legacyPayload: <String, Object?>{
    'url': 'https://example.com/$id.jpg',
    if (author != null) 'photographer': author,
    if (category != null) 'category': category,
  },
);
