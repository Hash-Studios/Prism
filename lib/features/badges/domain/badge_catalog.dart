import 'package:flutter/material.dart';
import 'package:Prism/l10n/l10n.dart';

/// How the app shows one badge. The server owns the rules and the coin rewards (`functions/src/badges.ts`).
class BadgeInfo {
  const BadgeInfo({required this.id, required this.icon});

  final String id;
  final IconData icon;

  String name(AppLocalizations l10n) => switch (id) {
    'week_warrior' => l10n.economyBadgeWeekWarrior,
    'streak_master' => l10n.economyBadgeStreakMaster,
    'creator' => l10n.economyBadgeCreator,
    'ai_artist' => l10n.economyBadgeAiArtist,
    'prism_veteran' => l10n.economyBadgePrismVeteran,
    'collector' => l10n.economyBadgeCollector,
    'art_curator' => l10n.economyBadgeArtCurator,
    'social_butterfly' => l10n.economyBadgeSocialButterfly,
    'profile_complete' => l10n.economyBadgeProfileComplete,
    _ => l10n.economyBadge,
  };

  String description(AppLocalizations l10n) => switch (id) {
    'week_warrior' => l10n.economyBadgeWeekWarriorDescription,
    'streak_master' => l10n.economyBadgeStreakMasterDescription,
    'creator' => l10n.economyBadgeCreatorDescription,
    'ai_artist' => l10n.economyBadgeAiArtistDescription,
    'prism_veteran' => l10n.economyBadgePrismVeteranDescription,
    'collector' => l10n.economyBadgeCollectorDescription,
    'art_curator' => l10n.economyBadgeArtCuratorDescription,
    'social_butterfly' => l10n.economyBadgeSocialButterflyDescription,
    'profile_complete' => l10n.economyBadgeProfileCompleteDescription,
    _ => l10n.economyBadgeDescription,
  };
}

const List<BadgeInfo> badgeCatalog = <BadgeInfo>[
  BadgeInfo(id: 'week_warrior', icon: Icons.local_fire_department_rounded),
  BadgeInfo(id: 'streak_master', icon: Icons.whatshot_rounded),
  BadgeInfo(id: 'creator', icon: Icons.brush_rounded),
  BadgeInfo(id: 'ai_artist', icon: Icons.auto_awesome_rounded),
  BadgeInfo(id: 'prism_veteran', icon: Icons.military_tech_rounded),
  BadgeInfo(id: 'collector', icon: Icons.favorite_rounded),
  BadgeInfo(id: 'art_curator', icon: Icons.collections_rounded),
  BadgeInfo(id: 'social_butterfly', icon: Icons.group_rounded),
  BadgeInfo(id: 'profile_complete', icon: Icons.verified_rounded),
];

/// The catalog entry for [id], or null for a badge this app version does not know.
BadgeInfo? badgeInfo(String id) {
  for (final BadgeInfo info in badgeCatalog) {
    if (info.id == id) return info;
  }
  return null;
}
