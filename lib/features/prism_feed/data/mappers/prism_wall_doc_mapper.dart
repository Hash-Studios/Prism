import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/features/prism_feed/data/dtos/prism_wall_doc_dto.dart';

extension PrismWallDocMapper on PrismWallDocDto {
  PrismWallpaper toDomain({required String docId}) {
    final String resolvedId = id.isNotEmpty ? id : docId;
    final String fullUrl = wallpaperUrl;
    final String thumbnailUrl = wallpaperThumb.isNotEmpty ? wallpaperThumb : fullUrl;
    final String? displayAuthor = by.isNotEmpty
        ? by
        : uploadedBy.isEmpty
        ? null
        : uploadedBy;

    final List<String> mergedTags = <String>[...tags];
    if (category.isNotEmpty && category.toLowerCase() != 'general') mergedTags.add(category);
    final Set<String> seenTags = <String>{};
    mergedTags.retainWhere((String t) => seenTags.add(t.toLowerCase()));

    return PrismWallpaper(
      core: WallpaperCore(
        id: resolvedId,
        source: WallpaperSourceX.fromWire(wallpaperProvider),
        fullUrl: fullUrl,
        thumbnailUrl: thumbnailUrl,
        resolution: resolution.isEmpty ? null : resolution,
        sizeBytes: fileSize,
        authorName: displayAuthor,
        authorEmail: email.isEmpty ? null : email,
        authorPhoto: userPhoto.isEmpty ? null : userPhoto,
        category: desc.isEmpty ? null : desc,
        createdAt: createdAt,
      ),
      collections: collections.isEmpty ? null : collections,
      review: review,
      tags: mergedTags.isEmpty ? null : mergedTags,
      aiMetadata: aiMetadata.isEmpty ? null : aiMetadata,
      isStreakExclusive: isStreakExclusive,
      requiredStreakDays: requiredStreakDays,
      streakShopCoinCost: streakShopCoinCost,
      firestoreDocumentId: docId,
    );
  }
}
