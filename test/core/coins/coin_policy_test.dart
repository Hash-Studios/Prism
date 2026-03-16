import 'package:Prism/core/coins/coin_action.dart';
import 'package:Prism/core/coins/coin_policy.dart';
import 'package:Prism/core/coins/streak_shop_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('coin earn values match revenue model', () {
    expect(CoinPolicy.rewardedAd, 10);
    expect(CoinPolicy.dailyLogin, 5);
    expect(CoinPolicy.streak7Bonus, 40);
    expect(CoinPolicy.firstWallpaperUpload, 50);
    expect(CoinPolicy.referral, 100);
    expect(CoinPolicy.profileCompletion, 25);
    expect(CoinPolicy.proDailyBonus, 50);

    expect(CoinEarnAction.rewardedAd.defaultAmount(), CoinPolicy.rewardedAd);
    expect(CoinEarnAction.dailyLogin.defaultAmount(), CoinPolicy.dailyLogin);
    expect(CoinEarnAction.streakBonus.defaultAmount(), CoinPolicy.streak7Bonus);
    expect(CoinEarnAction.firstWallpaperUpload.defaultAmount(), CoinPolicy.firstWallpaperUpload);
    expect(CoinEarnAction.referral.defaultAmount(), CoinPolicy.referral);
    expect(CoinEarnAction.profileCompletion.defaultAmount(), CoinPolicy.profileCompletion);
    expect(CoinEarnAction.proDailyBonus.defaultAmount(), CoinPolicy.proDailyBonus);
  });

  test('coin spend values match revenue model', () {
    expect(CoinPolicy.wallpaperDownload, 5);
    expect(CoinPolicy.premiumWallpaperDownload, 15);
    expect(CoinPolicy.aiGenerationFast, 10);
    expect(CoinPolicy.aiGenerationBalanced, 75);
    expect(CoinPolicy.aiGenerationQuality, 100);
    expect(CoinPolicy.premiumFilter, 5);
    expect(CoinPolicy.premiumPreview24h, 10);
    expect(CoinPolicy.lowBalanceNudgeThreshold, 10);

    expect(CoinSpendAction.wallpaperDownload.cost(), CoinPolicy.wallpaperDownload);
    expect(CoinSpendAction.premiumWallpaperDownload.cost(), CoinPolicy.premiumWallpaperDownload);
    expect(CoinSpendAction.aiGeneration.cost(), CoinPolicy.aiGenerationFast);
    expect(CoinSpendAction.premiumFilter.cost(), CoinPolicy.premiumFilter);
    expect(CoinSpendAction.premiumPreview24h.cost(), CoinPolicy.premiumPreview24h);
    expect(CoinSpendAction.streakFreeze.cost(), StreakShopPolicy.streakFreezeCoins);
  });
}
