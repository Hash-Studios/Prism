import 'dart:math';

import 'package:Prism/core/coins/economy_config.dart';
import 'package:Prism/core/coins/spin_wheel.dart';

/// Coin amounts the app shows and sends. Every value reads the loaded [EconomyConfig], so call sites stay live.
class CoinPolicy {
  const CoinPolicy._();

  static EconomyAward get _award => EconomyConfig.current.award;
  static EconomySpend get _spend => EconomyConfig.current.spend;

  // Earn
  static int get rewardedAd => _award.rewardedAd;
  static int get rewardedAdFirstOfDay => _award.rewardedAdFirstOfDay;
  static int get streakDay1To2Daily => streakDailyRewardForDay(1);
  static int get streakDay3To4Daily => streakDailyRewardForDay(3);
  static int get streakDay5To6Daily => streakDailyRewardForDay(5);
  static int get streakDay7Daily => streakDailyRewardForDay(7);
  static int get dailyLogin => streakDay1To2Daily;

  /// The smallest day 7 chest. The server rolls the real chest between [streakChestMin] and [streakChestMax].
  static int get streak7Bonus => streakChestMin;
  static int get streakChestMin => _award.streakChestMin;
  static int get streakChestMax => _award.streakChestMax;
  static int get firstWallpaperUpload => _award.firstWallpaperUpload;
  static int get referral => _award.referral;
  static int get profileCompletion => _award.profileCompletion;

  /// What the legacy flat Pro bonus pays now: the lowest spin segment.
  static int get proDailyBonus => proSpin.map((SpinSegment s) => s.coins).reduce(min);
  static List<SpinSegment> get proSpin => _award.proSpin;
  static List<WheelSegment> get spinWheel => defaultWheel;
  static int get spinWheelMaxPerDay => 5;
  static int get graceDownloads => _award.graceDownloads;
  static int get questCoins => _award.questCoins;
  static int get questChestMin => _award.questChestMin;
  static int get questChestMax => _award.questChestMax;

  // Spend
  static int get wallpaperDownload => _spend.wallpaperDownload;
  static int get premiumWallpaperDownload => _spend.premiumWallpaperDownload;
  static int get liveWallpaperStyle => _spend.liveWallpaperStyle;
  static int get aiGenerationFast => _spend.aiFast;
  static int get aiGenerationBalanced => _spend.aiBalanced;
  static int get aiGenerationQuality => _spend.aiQuality;
  static int get premiumFilter => _spend.premiumFilter;
  static int get premiumPreview24h => _spend.premiumPreview24h;
  static int get autoRotatePass7d => _spend.autoRotatePass7d;
  static int get streakFreezeCost => _spend.streakFreeze;
  static int get streakRescueCost => _spend.streakRescue;
  static int get dropWall => _spend.dropWall;
  static int get dropPack => _spend.dropPack;
  static int get boostWall => _spend.boostWall;
  static int get giftPremiumPass => _spend.giftPremiumPass;
  static int get drawTicket => _spend.drawTicket;
  static int get spinWheelPrice => 10;
  static const int maxStreakFreezes = 2;

  // UX
  static const int lowBalanceNudgeThreshold = 10;

  static int streakDailyRewardForDay(int day) => _award.streakDaily[day.clamp(1, 7) - 1];

  static int streakBonusRewardForDay(int day) {
    return day >= 7 ? streak7Bonus : 0;
  }

  static int streakTotalRewardForDay(int day) {
    return streakDailyRewardForDay(day) + streakBonusRewardForDay(day);
  }

  /// The Pro extra on a day 1 claim.
  static int get proStreakDailyBonus => streakClaimRewardForDay(1, isPro: true) - streakTotalRewardForDay(1);

  /// The Pro extra on a day 7 claim with the smallest chest.
  static int get proStreak7Bonus => streakClaimRewardForDay(7, isPro: true) - streakTotalRewardForDay(7);

  /// Coins a streak claim on [day] pays, the same sum claimDailyStreak awards (day 7 with the smallest chest).
  static int streakClaimRewardForDay(int day, {required bool isPro}) {
    final int total = streakTotalRewardForDay(day);
    return isPro ? (total * _award.proStreakMultiplier).ceil() : total;
  }
}

/// Whole days from day key [a] to day key [b] (`yyyy-MM-dd`). Null when either key is invalid.
int? dayKeyGap(String a, String b) {
  final RegExp dayKey = RegExp(r'^\d{4}-\d{2}-\d{2}$');
  if (!dayKey.hasMatch(a.trim()) || !dayKey.hasMatch(b.trim())) return null;
  final DateTime? da = DateTime.tryParse(a.trim());
  final DateTime? db = DateTime.tryParse(b.trim());
  if (da == null ||
      db == null ||
      da.toIso8601String().substring(0, 10) != a.trim() ||
      db.toIso8601String().substring(0, 10) != b.trim()) {
    return null;
  }
  return DateTime.utc(db.year, db.month, db.day).difference(DateTime.utc(da.year, da.month, da.day)).inDays;
}

/// Same rule as the server: a streak lives while the missed days fit inside the held freezes.
bool isStreakAlive(String lastKey, String todayKey, int freezes) {
  final int? gap = dayKeyGap(lastKey, todayKey);
  return gap != null && gap <= 1 + freezes;
}
