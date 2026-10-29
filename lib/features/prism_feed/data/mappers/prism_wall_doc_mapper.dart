import 'package:Prism/core/wallpaper/wall_ai_source.dart';
import 'package:Prism/core/wallpaper/wall_depth.dart';
import 'package:Prism/core/wallpaper/wall_spatial.dart';
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

    final String? cleanTitle = title?.trim();

    final List<String> mergedTags = <String>[...tags];
    if (category.isNotEmpty && category.toLowerCase() != 'general') mergedTags.add(category);
    final Set<String> seenTags = <String>{};
    mergedTags.retainWhere((String t) => seenTags.add(t.toLowerCase()));

    return PrismWallpaper(
      core: WallpaperCore(
        id: resolvedId,
        source: WallpaperSource.prism,
        fullUrl: fullUrl,
        thumbnailUrl: thumbnailUrl,
        resolution: resolution.isEmpty ? null : resolution,
        sizeBytes: fileSize,
        authorName: displayAuthor,
        authorEmail: email.isEmpty ? null : email,
        authorUid: creatorUid.isEmpty ? null : creatorUid,
        authorPhoto: userPhoto.isEmpty ? null : userPhoto,
        category: category.isEmpty ? null : category,
        createdAt: createdAt,
      ),
      title: cleanTitle == null || cleanTitle.isEmpty ? null : cleanTitle,
      description: desc.trim().isEmpty ? null : desc.trim(),
      collections: collections.isEmpty ? null : collections,
      review: review,
      tags: mergedTags.isEmpty ? null : mergedTags,
      colors: colors.isEmpty ? null : colors,
      aiMetadata: aiMetadata.isEmpty ? null : aiMetadata,
      isStreakExclusive: isStreakExclusive,
      requiredStreakDays: requiredStreakDays,
      streakShopCoinCost: streakShopCoinCost,
      firestoreDocumentId: docId,
      boostedUntil: boostedUntil,
      depthTier: WallDepthTier.parse(depth['tier']),
      spatial: WallSpatial.parse(spatial),
      aiSource: WallAiSource.parse(
        isAiGenerated: isAiGenerated,
        prompt: aiPrompt,
        stylePreset: aiStylePreset,
        model: aiModel,
        origin: origin,
      ),
      remixOf: remixOf.trim().isEmpty ? null : remixOf.trim(),
      remixCount: (remixCount ?? 0) < 0 ? 0 : remixCount ?? 0,
    );
  }
}
