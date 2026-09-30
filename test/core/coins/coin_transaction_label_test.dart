import 'package:Prism/core/coins/coin_transaction_entry.dart';
import 'package:Prism/core/coins/coin_transaction_label.dart';
import 'package:flutter_test/flutter_test.dart';

CoinTransactionEntry _tx(String action, {String? reason}) => CoinTransactionEntry(
  id: 'ctx_$action',
  userId: 'u',
  createdAt: DateTime.utc(2026),
  delta: 1,
  balanceBefore: 0,
  balanceAfter: 1,
  action: action,
  description: '',
  sourceTag: '',
  status: 'completed',
  type: 'credit',
  reason: reason,
);

void main() {
  test('maps every known action to a short label', () {
    const expected = <String, String>{
      'streakBonus': 'Week bonus',
      'proStreakBonus': 'Pro streak bonus',
      'proDailyBonus': 'Pro daily bonus',
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
    };
    expected.forEach((action, label) => expect(coinTransactionLabel(_tx(action)), label));
  });

  test('daily login shows the streak day from the reason', () {
    expect(coinTransactionLabel(_tx('dailyLogin', reason: 'daily_login')), 'Daily streak');
    expect(coinTransactionLabel(_tx('dailyLogin', reason: 'streak_mid_cycle_day_4')), 'Daily streak, day 4');
    expect(coinTransactionLabel(_tx('dailyLogin', reason: 'streak_day_7_daily')), 'Daily streak, day 7');
  });

  test('refunds name what was refunded', () {
    expect(coinTransactionLabel(_tx('refund', reason: 'refund_premiumFilter')), 'Refund: Premium filter');
    expect(coinTransactionLabel(_tx('refund', reason: 'ai_generation_failed_refund')), 'Refund: AI wallpaper');
    expect(coinTransactionLabel(_tx('refund', reason: 'download_failed_refund')), 'Refund: Wallpaper download');
    expect(coinTransactionLabel(_tx('refund')), 'Refund: Coins returned');
  });

  test('unknown actions are humanised, never raw', () {
    expect(coinTransactionLabel(_tx('someNewThing')), 'Some new thing');
    expect(coinTransactionLabel(_tx('content_abc_def')), 'Content abc def');
    expect(coinTransactionLabel(_tx('')), 'Coins');
  });
}
