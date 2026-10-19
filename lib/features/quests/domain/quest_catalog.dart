import 'package:flutter/material.dart';
import 'package:Prism/l10n/l10n.dart';

/// A quest's title and icon. Mirrors `functions/src/questCatalog.ts`; ids are stable.
class QuestInfo {
  const QuestInfo({required this.title, required this.icon});

  final String title;
  final IconData icon;
}

/// Falls back to a readable title for an id this build does not know.
QuestInfo questInfo(String id, AppLocalizations l10n) {
  final (String title, IconData icon)? known = switch (id) {
    'set_wall' => (l10n.economyQuestSetWall, Icons.wallpaper_rounded),
    'fav_3' => (l10n.economyQuestFav3, Icons.favorite_border_rounded),
    'wotd_view' => (l10n.economyQuestWotd, Icons.today_outlined),
    'colour_search' => (l10n.economyQuestColourSearch, Icons.palette_outlined),
    'trending_view' => (l10n.economyQuestTrending, Icons.trending_up_rounded),
    'share_wall' => (l10n.economyQuestShareWall, Icons.ios_share_rounded),
    'download_2' => (l10n.economyQuestDownload2, Icons.download_rounded),
    'browse_10' => (l10n.economyQuestBrowse10, Icons.visibility_outlined),
    'watch_ad' => (l10n.economyQuestWatchAd, Icons.play_circle_outline_rounded),
    'pro_spin' => (l10n.economyQuestProSpin, Icons.workspace_premium_outlined),
    'weekly_set_5' => (l10n.economyQuestWeeklySet5, Icons.event_available_outlined),
    _ => null,
  };
  return known == null
      ? QuestInfo(title: l10n.economyQuestUnknown, icon: Icons.check_circle_outline_rounded)
      : QuestInfo(title: known.$1, icon: known.$2);
}

/// Localized fallback for a cosmetic id missing from the shop catalog.
String cosmeticName(AppLocalizations l10n) {
  return l10n.economyUnknownCosmetic;
}
