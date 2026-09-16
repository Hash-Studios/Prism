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

    expect(CoinEarnAction.rewardedAd.defaultAmount(), 10);
    expect(CoinEarnAction.dailyLogin.defaultAmount(), 5);
    expect(CoinEarnAction.streakBonus.defaultAmount(), 40);
    expect(CoinEarnAction.firstWallpaperUpload.defaultAmount(), 50);
    expect(CoinEarnAction.referral.defaultAmount(), 100);
    expect(CoinEarnAction.profileCompletion.defaultAmount(), 25);
    expect(CoinEarnAction.proDailyBonus.defaultAmount(), 50);
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

    expect(CoinSpendAction.wallpaperDownload.cost(), 5);
    expect(CoinSpendAction.premiumWallpaperDownload.cost(), 15);
    expect(CoinSpendAction.aiGeneration.cost(), 10);
    expect(CoinSpendAction.premiumFilter.cost(), 5);
    expect(CoinSpendAction.premiumPreview24h.cost(), 10);
    expect(CoinSpendAction.streakFreeze.cost(), StreakShopPolicy.streakFreezeCoins);
  });
}
