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
}
