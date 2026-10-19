import 'package:Prism/core/firestore/firestore_document.dart';
import 'package:Prism/core/wallpaper/wall_depth.dart';
import 'package:Prism/l10n/l10n.dart';

/// The tier in `walls.depth.tier`, from the detector or an admin. Null when the wall was not checked.
WallDepthTier? wallDepthTier(FirestoreDocument wall) {
  final Object? depth = wall.payload['depth'];
  return depth is Map ? WallDepthTier.parse(depth['tier']) : null;
}

String depthTierLabel(AppLocalizations l10n, WallDepthTier? tier) => switch (tier) {
  WallDepthTier.auto => l10n.adminDepthTierAuto,
  WallDepthTier.menu => l10n.adminDepthTierMenu,
  WallDepthTier.none => l10n.adminDepthTierNone,
  null => l10n.adminDepthTierNotChecked,
};

/// The update for an admin pick. Dotted paths keep the detector's `kind`, `top` and `v`. A wall that was never
/// checked has no `depth` map to update, so it gets a whole one.
Map<String, dynamic> depthOverrideUpdate(FirestoreDocument wall, WallDepthTier tier) {
  if (wall.payload['depth'] is Map) {
    return <String, dynamic>{'depth.tier': tier.name, 'depth.by': 'admin'};
  }
  return <String, dynamic>{'depth': _newDepth(tier)};
}

/// [wall] as it reads after [depthOverrideUpdate], so a card can show the pick before Firestore answers.
FirestoreDocument withDepthOverride(FirestoreDocument wall, WallDepthTier tier) {
  final Object? depth = wall.payload['depth'];
  final Map<String, dynamic> updated = depth is Map
      ? <String, dynamic>{...depth.cast<String, dynamic>(), 'tier': tier.name, 'by': 'admin'}
      : _newDepth(tier);
  return FirestoreDocument(wall.id, <String, dynamic>{...wall.payload, 'depth': updated});
}

Map<String, dynamic> _newDepth(WallDepthTier tier) => <String, dynamic>{
  'tier': tier.name,
  'by': 'admin',
  'v': 1,
  'kind': null,
  'top': null,
};
