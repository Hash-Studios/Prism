import 'package:Prism/core/coins/coin_transaction_entry.dart';
import 'package:Prism/core/coins/coin_transaction_label.dart';
import 'package:flutter_test/flutter_test.dart';

CoinTransactionEntry _tx(String action, {String? reason, String description = ''}) => CoinTransactionEntry(
  id: 'ctx_$action',
  userId: 'u',
  createdAt: DateTime.utc(2026),
  delta: 1,
  balanceBefore: 0,
  balanceAfter: 1,
  action: action,
  description: description,
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
      'badgeReward': 'Badge reward',
      'proSpin': 'Pro spin',
      'spinWheel': 'Spin the wheel',
      'quest': 'Quest',
      'questChest': 'Daily chest',
      'streakChest': 'Day 7 chest',
      'liveWallpaperStyle': 'Live wallpaper style',
      'autoRotatePass7d': 'Auto-rotate pass, 7 days',
      'dropWall': 'Drop wall',
      'dropPack': 'Drop pack',
      'boostWall': 'Boost',
      'giftPremiumPass': 'Gift: 24 h pass',
      'drawTicket': 'Draw ticket',
      'shopItem': 'Shop',
    };
    expected.forEach((action, label) => expect(coinTransactionLabel(_tx(action)), label));
  });

  test('a legacy day 7 streak bonus reads as the chest', () {
    expect(coinTransactionLabel(_tx('streakBonus', reason: 'streak_day_7_chest')), 'Day 7 chest');
    expect(coinTransactionLabel(_tx('streakBonus')), 'Week bonus');
  });

  test('shop purchases show the item name', () {
    expect(coinTransactionLabel(_tx('shopItem', description: 'Aurora frame')), 'Aurora frame');
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
