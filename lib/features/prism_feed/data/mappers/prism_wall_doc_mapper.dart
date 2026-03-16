import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/features/prism_feed/data/dtos/prism_wall_doc_dto.dart';

extension PrismWallDocMapper on PrismWallDocDto {
  PrismWallpaper toDomain({required String docId}) {
    final String resolvedId = id.isNotEmpty ? id : docId;
    final String fullUrl = wallpaperUrl;
    final String thumbnailUrl = wallpaperThumb.isNotEmpty ? wallpaperThumb : fullUrl;

    return PrismWallpaper(
      core: WallpaperCore(
        id: resolvedId,
        source: WallpaperSourceX.fromWire(wallpaperProvider),
        fullUrl: fullUrl,
        thumbnailUrl: thumbnailUrl,
        resolution: resolution.isEmpty ? null : resolution,
        sizeBytes: fileSize,
        authorName: uploadedBy.isEmpty ? null : uploadedBy,
        category: desc.isEmpty ? null : desc,
        createdAt: createdAt,
      ),
      collections: collections.isEmpty ? null : collections,
      review: review,
      tags: tags.isEmpty ? null : tags,
      aiMetadata: aiMetadata.isEmpty ? null : aiMetadata,
      isStreakExclusive: isStreakExclusive,
      requiredStreakDays: requiredStreakDays,
      streakShopCoinCost: streakShopCoinCost,
    );
  }
}
