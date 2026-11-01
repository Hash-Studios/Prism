import 'package:Prism/core/coins/coin_transaction_entry.dart';
import 'package:Prism/core/coins/coin_transaction_label.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

late AppLocalizations _l10n;

String _label(CoinTransactionEntry entry) => coinTransactionLabel(entry, _l10n);

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
  setUpAll(() async {
    _l10n = await loadAppLocalizations(const Locale('en'));
  });

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
      'tipSent': 'Tip sent',
      'tipReceived': 'Tip received',
      'drawTicket': 'Draw ticket',
      'shopItem': 'Shop',
    };
    expected.forEach((action, label) => expect(_label(_tx(action)), label));
  });

  test('a legacy day 7 streak bonus reads as the chest', () {
    expect(_label(_tx('streakBonus', reason: 'streak_day_7_chest')), 'Day 7 chest');
    expect(_label(_tx('streakBonus')), 'Week bonus');
  });

  test('shop purchases show the item name', () {
    expect(_label(_tx('shopItem', description: 'Aurora frame')), 'Aurora frame');
  });

  test('daily login shows the streak day from the reason', () {
    expect(_label(_tx('dailyLogin', reason: 'daily_login')), 'Daily streak');
    expect(_label(_tx('dailyLogin', reason: 'streak_mid_cycle_day_4')), 'Daily streak, day 4');
    expect(_label(_tx('dailyLogin', reason: 'streak_day_7_daily')), 'Day 7 chest');
  });

  test('refunds name what was refunded', () {
    expect(_label(_tx('refund', reason: 'refund_premiumFilter')), 'Refund: Premium filter');
    expect(_label(_tx('refund', reason: 'ai_generation_failed_refund')), 'Refund: AI wallpaper');
    expect(_label(_tx('refund', reason: 'download_failed_refund')), 'Refund: Wallpaper download');
    expect(_label(_tx('refund')), 'Refund: Coins returned');
  });

  test('unknown actions use a localized generic label and never expose IDs', () {
    expect(_label(_tx('someNewThing')), 'Coins');
    expect(_label(_tx('content_abc_def')), 'Coins');
    expect(_label(_tx('')), 'Coins');
  });
}
