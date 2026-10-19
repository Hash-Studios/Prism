import 'package:Prism/core/coins/coin_transaction_entry.dart';
import 'package:Prism/l10n/l10n.dart';

/// Short, user-facing name for a coin transaction. Unknown server actions stay generic and never expose their ID.
String coinTransactionLabel(CoinTransactionEntry entry, AppLocalizations l10n) {
  final String reason = entry.reason ?? '';
  if (entry.action == 'refund') {
    return l10n.coreCoinRefund(_refundTarget(reason, l10n));
  }
  if (entry.action == 'dailyLogin') {
    final RegExpMatch? day = RegExp(r'^streak_mid_cycle_day_(\d)$').firstMatch(reason);
    if (day != null) {
      return l10n.coreCoinDailyStreakDay(day.group(1)!);
    }
    if (reason == 'streak_day_7_daily') {
      return l10n.coreCoinDay7Chest;
    }
    return l10n.coreCoinDailyStreak;
  }
  if (entry.action == 'streakBonus' && reason == 'streak_day_7_chest') {
    return l10n.coreCoinDay7Chest;
  }
  if (entry.action == 'shopItem') {
    final String name = entry.description.trim();
    return name.isEmpty ? l10n.coreCoinShop : name;
  }
  return _actionLabel(entry.action, l10n) ?? l10n.coreCoinCoins;
}

String? _actionLabel(String action, AppLocalizations l10n) => switch (action) {
  'streakBonus' => l10n.coreCoinWeekBonus,
  'proStreakBonus' => l10n.coreCoinProStreakBonus,
  'proDailyBonus' => l10n.coreCoinProDailyBonus,
  'streakRescue' => l10n.coreCoinStreakRestore,
  'rewardedAd' => l10n.coreCoinWatchedVideo,
  'referral' => l10n.coreCoinInviteReward,
  'firstWallpaperUpload' => l10n.coreCoinFirstUpload,
  'profileCompletion' => l10n.coreCoinProfileComplete,
  'wallpaperDownload' => l10n.coreCoinWallpaperDownload,
  'premiumWallpaperDownload' => l10n.coreCoinPremiumWallpaper,
  'aiGeneration' => l10n.coreCoinAiWallpaper,
  'premiumFilter' => l10n.coreCoinPremiumFilter,
  'premiumPreview24h' => l10n.coreCoinCollectionPreview,
  'streakFreeze' => l10n.coreCoinStreakFreeze,
  'badgeReward' => l10n.coreCoinBadgeReward,
  'proSpin' => l10n.coreCoinProSpin,
  'spinWheel' => l10n.coreCoinSpinWheel,
  'quest' => l10n.coreCoinQuest,
  'questChest' => l10n.coreCoinDailyChest,
  'streakChest' => l10n.coreCoinDay7Chest,
  'liveWallpaperStyle' => l10n.coreCoinLiveWallpaperStyle,
  'autoRotatePass7d' => l10n.coreCoinAutoRotatePass,
  'dropWall' => l10n.coreCoinDropWall,
  'dropPack' => l10n.coreCoinDropPack,
  'boostWall' => l10n.coreCoinBoost,
  'giftPremiumPass' => l10n.coreCoinGiftPass,
  'drawTicket' => l10n.coreCoinDrawTicket,
  _ => null,
};

String _refundTarget(String reason, AppLocalizations l10n) {
  if (reason.contains('ai_generation')) {
    return l10n.coreCoinAiWallpaper;
  }
  if (reason.startsWith('refund_')) {
    final String? label = _actionLabel(reason.substring('refund_'.length), l10n);
    if (label != null) {
      return label;
    }
  }
  if (reason.contains('download')) {
    return l10n.coreCoinWallpaperDownload;
  }
  return l10n.coreCoinCoinsReturned;
}
