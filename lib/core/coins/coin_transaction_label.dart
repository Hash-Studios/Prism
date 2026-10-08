import 'package:Prism/core/coins/coin_transaction_entry.dart';

const Map<String, String> _actionLabels = <String, String>{
  'streakBonus': 'Week bonus',
  'proStreakBonus': 'Pro streak bonus',
  'proDailyBonus': 'Pro daily bonus',
  'streakRescue': 'Streak restore',
  'rewardedAd': 'Watched a video',
  'referral': 'Invite reward',
  'firstWallpaperUpload': 'First upload',
  'profileCompletion': 'Profile complete',
  'wallpaperDownload': 'Wallpaper download',
  'premiumWallpaperDownload': 'Premium wallpaper',
  'aiGeneration': 'AI wallpaper',
  'premiumFilter': 'Premium filter',
  'premiumPreview24h': 'Collection preview, 24 h',
  'streakFreeze': 'Streak freeze',
  'badgeReward': 'Badge reward',
};

/// Short, user-facing name for a coin transaction. Never returns a raw id or slug.
String coinTransactionLabel(CoinTransactionEntry e) {
  final String reason = e.reason ?? '';
  if (e.action == 'refund') {
    return 'Refund: ${_refundTarget(reason)}';
  }
  if (e.action == 'dailyLogin') {
    final RegExpMatch? day = RegExp(r'^streak_mid_cycle_day_(\d)$').firstMatch(reason);
    if (day != null) {
      return 'Daily streak, day ${day.group(1)}';
    }
    if (reason == 'streak_day_7_daily') {
      return 'Daily streak, day 7';
    }
    return 'Daily streak';
  }
  return _actionLabels[e.action] ?? _humanise(e.action);
}

String _refundTarget(String reason) {
  if (reason.contains('ai_generation')) {
    return 'AI wallpaper';
  }
  if (reason.startsWith('refund_')) {
    final String? label = _actionLabels[reason.substring('refund_'.length)];
    if (label != null) {
      return label;
    }
  }
  if (reason.contains('download')) {
    return 'Wallpaper download';
  }
  return 'Coins returned';
}

/// `someActionName` or `some_action_name` to `Some action name`. Empty input gives `Coins`.
String _humanise(String raw) {
  final String words = raw
      .replaceAllMapped(RegExp('([a-z0-9])([A-Z])'), (m) => '${m[1]} ${m[2]}')
      .replaceAll(RegExp('[_\\-\\s]+'), ' ')
      .trim()
      .toLowerCase();
  if (words.isEmpty) {
    return 'Coins';
  }
  return words[0].toUpperCase() + words.substring(1);
}
