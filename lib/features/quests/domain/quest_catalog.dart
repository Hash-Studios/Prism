import 'package:flutter/material.dart';

/// A quest's title and icon. Mirrors `functions/src/questCatalog.ts`; ids are stable.
class QuestInfo {
  const QuestInfo({required this.title, required this.icon});

  final String title;
  final IconData icon;
}

const Map<String, QuestInfo> _quests = <String, QuestInfo>{
  'set_wall': QuestInfo(title: 'Set or save a wallpaper', icon: Icons.wallpaper_rounded),
  'fav_3': QuestInfo(title: 'Favourite 3 walls', icon: Icons.favorite_border_rounded),
  'wotd_view': QuestInfo(title: "Open today's Wall of the Day", icon: Icons.today_outlined),
  'colour_search': QuestInfo(title: 'Search by colour', icon: Icons.palette_outlined),
  'trending_view': QuestInfo(title: "See what's trending", icon: Icons.trending_up_rounded),
  'share_wall': QuestInfo(title: 'Share a wallpaper', icon: Icons.ios_share_rounded),
  'download_2': QuestInfo(title: 'Download 2 walls', icon: Icons.download_rounded),
  'browse_10': QuestInfo(title: 'Look at 10 walls', icon: Icons.visibility_outlined),
  'watch_ad': QuestInfo(title: 'Watch a video', icon: Icons.play_circle_outline_rounded),
  'pro_spin': QuestInfo(title: 'Open your Pro spin', icon: Icons.workspace_premium_outlined),
  'weekly_set_5': QuestInfo(title: 'Save or set 5 walls', icon: Icons.event_available_outlined),
};

/// Falls back to a readable title for an id this build does not know.
QuestInfo questInfo(String id) =>
    _quests[id] ?? QuestInfo(title: id.replaceAll('_', ' '), icon: Icons.check_circle_outline_rounded);

/// A readable name for a cosmetic a chest dropped, from its catalog id (`frame_ring` is "Ring frame").
String cosmeticName(String itemId) {
  final int split = itemId.indexOf('_');
  if (split <= 0) return itemId;
  final String kind = switch (itemId.substring(0, split)) {
    'theme' => 'theme',
    'icon' => 'app icon',
    'frame' => 'frame',
    'glow' => 'name glow',
    final String other => other,
  };
  final String name = itemId
      .substring(split + 1)
      .split('_')
      .map((String w) => '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');
  return '$name $kind';
}
