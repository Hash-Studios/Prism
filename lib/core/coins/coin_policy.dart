class CoinPolicy {
  const CoinPolicy._();

  // Earn
  static const int rewardedAd = 10;
  static const int streakDay1To2Daily = 5;
  static const int streakDay3To4Daily = 8;
  static const int streakDay5To6Daily = 12;
  static const int streakDay7Daily = 15;
  static const int dailyLogin = streakDay1To2Daily;
  static const int streak7Bonus = 40;
  static const int firstWallpaperUpload = 50;
  static const int referral = 100;
  static const int profileCompletion = 25;
  static const int proDailyBonus = 50;

  // Spend
  static const int wallpaperDownload = 5;
  static const int premiumWallpaperDownload = 15;
  static const int aiGenerationFast = 10;
  static const int aiGenerationBalanced = 75;
  static const int aiGenerationQuality = 100;
  static const int premiumFilter = 5;
  static const int premiumPreview24h = 10;
  static const int streakFreezeCost = 50;
  static const int maxStreakFreezes = 2;

  // UX
  static const int lowBalanceNudgeThreshold = 10;

  static int streakDailyRewardForDay(int day) {
    if (day >= 1 && day <= 2) {
      return streakDay1To2Daily;
    }
    if (day >= 3 && day <= 4) {
      return streakDay3To4Daily;
    }
    if (day >= 5 && day <= 6) {
      return streakDay5To6Daily;
    }
    if (day >= 7) {
      return streakDay7Daily;
    }
    return streakDay1To2Daily;
  }

  static int streakBonusRewardForDay(int day) {
    return day >= 7 ? streak7Bonus : 0;
  }

  static int streakTotalRewardForDay(int day) {
    return streakDailyRewardForDay(day) + streakBonusRewardForDay(day);
  }

  // Pro streak bonus: added on top of base daily reward
  static const int proStreakDailyBonus = 5;
  static const int proStreak7Bonus = 20;

  /// Coins a streak claim on [day] pays, the same sum claimDailyStreak awards.
  static int streakClaimRewardForDay(int day, {required bool isPro}) {
    final int proBonus = !isPro ? 0 : (day >= 7 ? proStreak7Bonus : proStreakDailyBonus);
    return streakTotalRewardForDay(day) + proBonus;
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
