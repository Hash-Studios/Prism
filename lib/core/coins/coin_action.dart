import 'package:Prism/core/coins/coin_policy.dart';

enum CoinEarnAction {
  rewardedAd,
  dailyLogin,
  streakBonus,
  firstWallpaperUpload,
  referral,
  profileCompletion,
  proDailyBonus,
  refund,
}

enum CoinSpendAction {
  wallpaperDownload,
  premiumWallpaperDownload,
  aiGeneration,
  premiumFilter,
  premiumPreview24h,
}

extension CoinEarnActionX on CoinEarnAction {
  int defaultAmount() {
    switch (this) {
      case CoinEarnAction.rewardedAd:
        return CoinPolicy.rewardedAd;
      case CoinEarnAction.dailyLogin:
        return CoinPolicy.dailyLogin;
      case CoinEarnAction.streakBonus:
        return CoinPolicy.streak7Bonus;
      case CoinEarnAction.firstWallpaperUpload:
        return CoinPolicy.firstWallpaperUpload;
      case CoinEarnAction.referral:
        return CoinPolicy.referral;
      case CoinEarnAction.profileCompletion:
        return CoinPolicy.profileCompletion;
      case CoinEarnAction.proDailyBonus:
        return CoinPolicy.proDailyBonus;
      case CoinEarnAction.refund:
        return 0;
    }
  }
}

extension CoinSpendActionX on CoinSpendAction {
  int cost() {
    switch (this) {
      case CoinSpendAction.wallpaperDownload:
        return CoinPolicy.wallpaperDownload;
      case CoinSpendAction.premiumWallpaperDownload:
        return CoinPolicy.premiumWallpaperDownload;
      case CoinSpendAction.aiGeneration:
        return CoinPolicy.aiGeneration;
      case CoinSpendAction.premiumFilter:
        return CoinPolicy.premiumFilter;
      case CoinSpendAction.premiumPreview24h:
        return CoinPolicy.premiumPreview24h;
    }
  }
}
