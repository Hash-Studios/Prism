import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
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

  String get thumbnailUrl => when(
    prism: (_, w) => w.thumbnailUrl,
    wallhaven: (_, w) => w.thumbnailUrl,
    pexels: (_, w) => w.thumbnailUrl,
  );
}
