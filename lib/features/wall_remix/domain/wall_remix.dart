import 'package:Prism/core/user_blocks/blocked_creators_filter.dart';
import 'package:Prism/core/utils/premium_wall_utils.dart';
import 'package:Prism/core/wallpaper/wall_ai_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/features/ai_wallpaper/domain/entities/ai_quality_tier.dart';
import 'package:Prism/features/ai_wallpaper/domain/entities/ai_style_preset.dart';

/// What the viewer may see of a wall: the remix rules never show a wall the viewer cannot open in full.
final class WallViewer {
  const WallViewer({required this.isPremium, required this.premiumCollections, required this.blockedCreatorUids});

  final bool isPremium;
  final List<String> premiumCollections;
  final Set<String> blockedCreatorUids;

  /// Approved, not premium-gated for this viewer, not streak-withheld, and not by a blocked creator.
  bool canFullyView(PrismWallpaper wall) {
    if (wall.review != true || wall.isStreakExclusive) return false;
    if (!isPremium && isPremiumWall(premiumCollections, wall.collections ?? const <String>[])) return false;
    return !BlockedCreatorsFilter.hidesCreatorUid(wall.core.authorUid, blockedCreatorUids);
  }
}

enum RemixSourceType { studio, user }

/// The wall a remix starts from, as the AI tab needs it.
final class AiRemixSeed {
  const AiRemixSeed({
    required this.wallDocId,
    required this.title,
    required this.creatorName,
    required this.thumbnailUrl,
    required this.prompt,
    required this.sourceType,
    this.style,
    this.model,
  });

  final String wallDocId;
  final String? title;
  final String? creatorName;
  final String thumbnailUrl;
  final String prompt;
  final RemixSourceType sourceType;

  /// Null on Studio walls and older walls: the AI tab then keeps the style the user has.
  final AiStylePreset? style;
  final String? model;

  /// The seed of [wall], or null when the viewer must not see a Remix action on it.
  static AiRemixSeed? of(PrismWallpaper wall, {required WallViewer viewer, required bool aiEnabled}) {
    final WallAiSource? ai = wall.aiSource;
    final String docId = wall.firestoreDocumentId?.trim() ?? '';
    if (!aiEnabled || ai == null || docId.isEmpty || !viewer.canFullyView(wall)) return null;
    return AiRemixSeed(
      wallDocId: docId,
      title: wall.title,
      creatorName: wall.core.authorName,
      thumbnailUrl: wall.thumbnailUrl,
      prompt: ai.prompt,
      sourceType: ai.isStudio ? RemixSourceType.studio : RemixSourceType.user,
      style: AiStylePreset.tryFromApiValue(ai.stylePreset),
      model: ai.model,
    );
  }
}

/// The tier that made [model] on the Worker's default routing. Unknown models read as balanced.
AiQualityTier tierForModel(String? model) {
  final String value = (model ?? '').toLowerCase();
  if (value.contains('z-image') || value.contains('turbo') || value.contains('schnell')) return AiQualityTier.fast;
  if (value.contains('gpt-image')) return AiQualityTier.quality;
  return AiQualityTier.balanced;
}

/// The original's tier, or the next lower tier the user can pay for. Fast when none fits: the generate bar then
/// offers coins as usual.
AiQualityTier remixTier({required String? model, required int balance, required bool isPro}) {
  final AiQualityTier target = tierForModel(model);
  for (final AiQualityTier tier in AiQualityTier.values.reversed) {
    if (tier.index <= target.index && tier.costFor(isPro: isPro) <= balance) return tier;
  }
  return AiQualityTier.fast;
}

/// Remixes by other creators that the viewer may open, newest first as the query returns them.
List<PrismWallpaper> visibleRemixes(
  List<PrismWallpaper> remixes, {
  required PrismWallpaper original,
  required WallViewer viewer,
}) {
  final String ownerEmail = (original.core.authorEmail ?? '').trim().toLowerCase();
  return remixes
      .where((PrismWallpaper wall) {
        final String email = (wall.core.authorEmail ?? '').trim().toLowerCase();
        return viewer.canFullyView(wall) && (ownerEmail.isEmpty || email != ownerEmail);
      })
      .toList(growable: false);
}
