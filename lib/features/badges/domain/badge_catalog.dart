import 'package:flutter/material.dart';

/// How the app shows one badge. The server owns the rules and the coin rewards (`functions/src/badges.ts`).
class BadgeInfo {
  const BadgeInfo({required this.id, required this.name, required this.description, required this.icon});

  final String id;
  final String name;
  final String description;
  final IconData icon;
}

const List<BadgeInfo> badgeCatalog = <BadgeInfo>[
  BadgeInfo(
    id: 'week_warrior',
    name: 'Week Warrior',
    description: 'Reach a 7 day streak',
    icon: Icons.local_fire_department_rounded,
  ),
  BadgeInfo(
    id: 'streak_master',
    name: 'Streak Master',
    description: 'Reach a 28 day streak',
    icon: Icons.whatshot_rounded,
  ),
  BadgeInfo(id: 'creator', name: 'Creator', description: 'Get a wallpaper approved', icon: Icons.brush_rounded),
  BadgeInfo(
    id: 'ai_artist',
    name: 'AI Artist',
    description: 'Generate 10 AI wallpapers',
    icon: Icons.auto_awesome_rounded,
  ),
  BadgeInfo(
    id: 'prism_veteran',
    name: 'Prism Veteran',
    description: 'Use Prism for 30 days and reach a 7 day streak',
    icon: Icons.military_tech_rounded,
  ),
  BadgeInfo(id: 'collector', name: 'Collector', description: 'Favourite 10 wallpapers', icon: Icons.favorite_rounded),
  BadgeInfo(
    id: 'art_curator',
    name: 'Art Curator',
    description: 'Favourite 50 wallpapers',
    icon: Icons.collections_rounded,
  ),
  BadgeInfo(
    id: 'social_butterfly',
    name: 'Social Butterfly',
    description: 'Follow 10 creators',
    icon: Icons.group_rounded,
  ),
  BadgeInfo(
    id: 'profile_complete',
    name: 'Profile Complete',
    description: 'Add a photo, username, bio and a link',
    icon: Icons.verified_rounded,
  ),
];

/// The catalog entry for [id], or null for a badge this app version does not know.
BadgeInfo? badgeInfo(String id) {
  for (final BadgeInfo info in badgeCatalog) {
    if (info.id == id) return info;
  }
  return null;
}
