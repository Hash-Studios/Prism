import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'feed_item_entity.freezed.dart';

@freezed
sealed class FeedItemEntity with _$FeedItemEntity {
  const FeedItemEntity._();

  const factory FeedItemEntity.prism({required String id, required PrismWallpaper wallpaper}) = PrismFeedItem;

  const factory FeedItemEntity.wallhaven({required String id, required WallhavenWallpaper wallpaper}) =
      WallhavenFeedItem;

  const factory FeedItemEntity.pexels({required String id, required PexelsWallpaper wallpaper}) = PexelsFeedItem;

  WallpaperSource get source => when(
    prism: (_, _) => WallpaperSource.prism,
    wallhaven: (_, _) => WallpaperSource.wallhaven,
    pexels: (_, _) => WallpaperSource.pexels,
  );

  WallpaperCore get wallpaperCore =>
      when(prism: (_, w) => w.core, wallhaven: (_, w) => w.core, pexels: (_, w) => w.core);

  String get thumbnailUrl =>
      when(prism: (_, w) => w.thumbnailUrl, wallhaven: (_, w) => w.thumbnailUrl, pexels: (_, w) => w.thumbnailUrl);

  String get fullUrl => when(prism: (_, w) => w.fullUrl, wallhaven: (_, w) => w.fullUrl, pexels: (_, w) => w.fullUrl);

  String get canonicalKey {
    final String url = fullUrl.trim().toLowerCase();
    return url.isNotEmpty ? url : '${source.wireValue}:${id.trim().toLowerCase()}';
  }

  /// What screen readers say for this wallpaper's tile.
  String semanticLabel(AppLocalizations l10n) => wallpaperSemanticLabel(
    when(
      prism: (_, w) => w.core.authorName,
      wallhaven: (_, w) => w.core.authorName,
      pexels: (_, w) => w.core.authorName,
    ),
    l10n,
  );
}

/// [items] in order, with repeats dropped and the first copy kept. A repeat has the same source and id as a wall kept
/// before it or listed in [exclude], or is a Wallhaven re-upload of one: Wallhaven gives each upload a new id.
List<FeedItemEntity> distinctWalls(Iterable<FeedItemEntity> items, {Iterable<FeedItemEntity> exclude = const []}) {
  final Set<(WallpaperSource, String)> ids = <(WallpaperSource, String)>{};
  final List<WallhavenWallpaper> uploads = <WallhavenWallpaper>[];
  bool isNew(FeedItemEntity item) {
    if (!ids.add((item.source, item.id.trim()))) return false;
    if (item case WallhavenFeedItem(:final WallhavenWallpaper wallpaper)) {
      if (uploads.any((WallhavenWallpaper kept) => _sameUpload(kept, wallpaper))) return false;
      uploads.add(wallpaper);
    }
    return true;
  }

  for (final FeedItemEntity item in exclude) {
    isNew(item);
  }
  return <FeedItemEntity>[
    for (final FeedItemEntity item in items)
      if (isNew(item)) item,
  ];
}

// ponytail: Wallhaven sends no picture hash, so a re-upload is the same pixel size and palette with a file size within
// 1%. Match on a hash if the API ever sends one.
bool _sameUpload(WallhavenWallpaper a, WallhavenWallpaper b) {
  final int? sizeA = a.core.sizeBytes;
  final int? sizeB = b.core.sizeBytes;
  final List<String>? colours = a.colors;
  return a.dimensionX != null &&
      a.dimensionX == b.dimensionX &&
      a.dimensionY == b.dimensionY &&
      sizeA != null &&
      sizeB != null &&
      (sizeA - sizeB).abs() * 100 <= (sizeA > sizeB ? sizeA : sizeB) &&
      colours != null &&
      colours.isNotEmpty &&
      colours.join(',') == b.colors?.join(',');
}
