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
  quest,
  questChest,
  streakChest,
  spinWheel,
}

enum CoinSpendAction {
  wallpaperDownload,
  premiumWallpaperDownload,
  aiGeneration,
  premiumFilter,
  premiumPreview24h,
  streakFreeze,
  liveWallpaperStyle,
  autoRotatePass7d,
  dropWall,
  dropPack,
  boostWall,
  giftPremiumPass,
  drawTicket,
  shopItem,
  spinWheel,
  questChest,
}

extension CoinEarnActionX on CoinEarnAction {
  /// The amount shown before the server answers. Server-rolled rewards (spin, chest) are 0: the reply names the prize.
  int defaultAmount() {
    switch (this) {
      case CoinEarnAction.rewardedAd:
        return CoinPolicy.rewardedAd;
      case CoinEarnAction.dailyLogin:
        return CoinPolicy.dailyLogin;
      case CoinEarnAction.streakBonus:
      case CoinEarnAction.streakChest:
        return CoinPolicy.streak7Bonus;
      case CoinEarnAction.firstWallpaperUpload:
        return CoinPolicy.firstWallpaperUpload;
      case CoinEarnAction.referral:
        return CoinPolicy.referral;
      case CoinEarnAction.profileCompletion:
        return CoinPolicy.profileCompletion;
      case CoinEarnAction.proDailyBonus:
        return CoinPolicy.proDailyBonus;
      case CoinEarnAction.quest:
        return CoinPolicy.questCoins;
      case CoinEarnAction.refund:
      case CoinEarnAction.spinWheel:
      case CoinEarnAction.questChest:
        return 0;
    }
  }
}

extension CoinSpendActionX on CoinSpendAction {
  /// The list price. Shop items return 0: the caller resolves the item price.
  int cost() {
    switch (this) {
      case CoinSpendAction.wallpaperDownload:
        return CoinPolicy.wallpaperDownload;
      case CoinSpendAction.premiumWallpaperDownload:
        return CoinPolicy.premiumWallpaperDownload;
      case CoinSpendAction.aiGeneration:
        return CoinPolicy.aiGenerationFast;
      case CoinSpendAction.premiumFilter:
        return CoinPolicy.premiumFilter;
      case CoinSpendAction.premiumPreview24h:
        return CoinPolicy.premiumPreview24h;
      case CoinSpendAction.streakFreeze:
        return CoinPolicy.streakFreezeCost;
      case CoinSpendAction.liveWallpaperStyle:
        return CoinPolicy.liveWallpaperStyle;
      case CoinSpendAction.autoRotatePass7d:
        return CoinPolicy.autoRotatePass7d;
      case CoinSpendAction.dropWall:
        return CoinPolicy.dropWall;
      case CoinSpendAction.dropPack:
        return CoinPolicy.dropPack;
      case CoinSpendAction.boostWall:
        return CoinPolicy.boostWall;
      case CoinSpendAction.giftPremiumPass:
        return CoinPolicy.giftPremiumPass;
      case CoinSpendAction.drawTicket:
        return CoinPolicy.drawTicket;
      case CoinSpendAction.shopItem:
        return 0;
      case CoinSpendAction.spinWheel:
        return CoinPolicy.spinWheelPrice;
      case CoinSpendAction.questChest:
        return CoinPolicy.dailyChestPrice;
    }
  }
}
