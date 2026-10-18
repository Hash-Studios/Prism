import 'package:Prism/core/coins/coin_action.dart';
import 'package:Prism/core/coins/coin_policy.dart';
import 'package:Prism/core/coins/economy_config.dart';
import 'package:flutter_test/flutter_test.dart';

import 'spin_wheel_test_helpers.dart';

void main() {
  test('daily streak reward follows the config table and caps at day 7', () {
    const expected = <int, int>{0: 3, 1: 3, 2: 3, 3: 5, 4: 5, 5: 8, 6: 8, 7: 10, 30: 10};
    for (final entry in expected.entries) {
      expect(CoinPolicy.streakDailyRewardForDay(entry.key), entry.value, reason: 'day ${entry.key}');
    }
  });

  test('day 7 adds the smallest chest', () {
    expect(CoinPolicy.streakBonusRewardForDay(6), 0);
    expect(CoinPolicy.streakBonusRewardForDay(7), 15);
  });

  test('Pro claims pay the multiplier on the whole day, rounded up', () {
    expect(CoinPolicy.streakTotalRewardForDay(6), 8);
    expect(CoinPolicy.streakTotalRewardForDay(7), 25);
    expect(CoinPolicy.streakClaimRewardForDay(3, isPro: false), 5);
    expect(CoinPolicy.streakClaimRewardForDay(3, isPro: true), 8);
    expect(CoinPolicy.streakClaimRewardForDay(7, isPro: true), 38);
    expect(CoinPolicy.proStreakDailyBonus, 2);
    expect(CoinPolicy.proStreak7Bonus, 13);
  });

  test('getters read the loaded config', () {
    addTearDown(EconomyConfig.resetForTest);
    EconomyConfig.current = EconomyConfig.fromMap(<String, dynamic>{
      'spend': <String, dynamic>{'wallpaperDownload': 7},
      'award': <String, dynamic>{
        'rewardedAd': 4,
        'proSpin': <Map<String, num>>[
          <String, num>{'coins': 30, 'weight': 1},
          <String, num>{'coins': 25, 'weight': 1},
        ],
      },
    });
    expect(CoinPolicy.wallpaperDownload, 7);
    expect(CoinPolicy.rewardedAd, 4);
    expect(CoinPolicy.proDailyBonus, 25);
    expect(CoinPolicy.premiumWallpaperDownload, 25);
  });

  test('the spin wheel getters follow the loaded config', () {
    addTearDown(EconomyConfig.resetForTest);
    expect((CoinPolicy.spinWheelPrice, CoinPolicy.spinWheelMaxPerDay), (10, 5));
    expect(describeWheel(CoinPolicy.spinWheel), defaultWheelLines);
    EconomyConfig.current = EconomyConfig.fromMap(<String, dynamic>{
      'spend': <String, dynamic>{'spinWheel': 25},
      'award': <String, dynamic>{
        'spinWheelMaxPerDay': 2,
        'spinWheel': <Map<String, Object>>[
          <String, Object>{'kind': 'coins', 'coins': 9, 'weight': 1},
          <String, Object>{'kind': 'xp', 'xp': 9, 'weight': 1},
        ],
      },
    });
    expect((CoinPolicy.spinWheelPrice, CoinPolicy.spinWheelMaxPerDay), (25, 2));
    expect(describeWheel(CoinPolicy.spinWheel), <String>['coins 9 x1', 'xp 9 x1']);
    expect(CoinSpendAction.spinWheel.cost(), 25);
  });

  test('the daily chest getters follow the loaded config', () {
    addTearDown(EconomyConfig.resetForTest);
    expect(CoinPolicy.dailyChestPrice, 8);
    expect(describeWheel(CoinPolicy.dailyChest), defaultChestLines);
    expect((CoinSpendAction.questChest.cost(), CoinEarnAction.questChest.defaultAmount()), (8, 5));
    EconomyConfig.current = EconomyConfig.fromMap(<String, dynamic>{
      'spend': <String, dynamic>{'dailyChest': 6},
      'award': <String, dynamic>{
        'dailyChest': <Map<String, Object>>[
          <String, Object>{'kind': 'xp', 'xp': 30, 'weight': 3},
          <String, Object>{'kind': 'coins', 'coins': 12, 'weight': 2},
          <String, Object>{'kind': 'coins', 'coins': 9, 'weight': 1},
        ],
      },
    });
    expect(CoinPolicy.dailyChestPrice, 6);
    expect(describeWheel(CoinPolicy.dailyChest), <String>['xp 30 x3', 'coins 12 x2', 'coins 9 x1']);
    expect((CoinSpendAction.questChest.cost(), CoinEarnAction.questChest.defaultAmount()), (6, 9));
  });

  test('a chest table that pays no coins previews zero coins', () {
    addTearDown(EconomyConfig.resetForTest);
    EconomyConfig.current = EconomyConfig.fromMap(<String, dynamic>{
      'award': <String, dynamic>{
        'dailyChest': <Map<String, Object>>[
          <String, Object>{'kind': 'xp', 'xp': 30, 'weight': 1},
          <String, Object>{'kind': 'cosmetic', 'fallbackCoins': 25, 'weight': 1},
        ],
      },
    });
    expect(CoinEarnAction.questChest.defaultAmount(), 0);
  });

  test('isStreakAlive allows one missed day per held freeze', () {
    expect(isStreakAlive('2026-03-01', '2026-03-01', 0), isTrue);
    expect(isStreakAlive('2026-03-01', '2026-03-02', 0), isTrue);
    expect(isStreakAlive('2026-03-01', '2026-03-03', 0), isFalse);
    expect(isStreakAlive('2026-03-01', '2026-03-03', 1), isTrue);
    expect(isStreakAlive('2026-03-01', '2026-03-04', 1), isFalse);
    expect(isStreakAlive('2026-03-01', '2026-03-04', 2), isTrue);
    expect(isStreakAlive('2026-02-28', '2026-03-01', 0), isTrue);
    expect(isStreakAlive('', '2026-03-01', 2), isFalse);
  });

  test('non-day strings cannot keep a streak alive', () {
    expect(dayKeyGap('2026-03-01T00:00:00', '2026-03-02'), isNull);
    expect(dayKeyGap('20260301', '2026-03-02'), isNull);
    expect(dayKeyGap('2026-02-30', '2026-03-02'), isNull);
    expect(dayKeyGap('2026-13-01', '2027-01-02'), isNull);
  });
}
