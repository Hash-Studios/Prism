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
/// before it or listed in [exclude]. Identity uses source and ID; similar image metadata is not proof that two uploads
/// are the same picture.
List<FeedItemEntity> distinctWalls(Iterable<FeedItemEntity> items, {Iterable<FeedItemEntity> exclude = const []}) {
  final Set<(WallpaperSource, String)> ids = <(WallpaperSource, String)>{};
  bool isNew(FeedItemEntity item) {
    if (!ids.add((item.source, item.id.trim()))) return false;
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
