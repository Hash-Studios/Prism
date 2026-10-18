import 'package:Prism/core/coins/economy_config.dart';
import 'package:flutter_test/flutter_test.dart';

import 'spin_wheel_test_helpers.dart';

void main() {
  test('defaults mirror the server defaults', () {
    const EconomyConfig c = EconomyConfig.defaults;
    expect(c.version, 2);
    expect(c.spend.wallpaperDownload, 10);
    expect(c.spend.premiumWallpaperDownload, 25);
    expect(c.spend.giftPremiumPass, 50);
    expect(c.award.rewardedAdFirstOfDay, 20);
    expect(c.award.streakDaily, <int>[3, 3, 5, 5, 8, 8, 10]);
    expect(c.award.weeklyQuestCoins, 30);
    expect(c.award.proSpin.map((SpinSegment s) => s.coins), <int>[20, 30, 50, 75, 100]);
    expect(c.spend.spinWheel, 10);
    expect(c.award.spinWheelMaxPerDay, 5);
    expect(describeWheel(c.award.spinWheel), defaultWheelLines);
    expect(c.spend.dailyChest, 8);
    expect(describeWheel(c.award.dailyChest), defaultChestLines);
    expect(c.xp.ranks.map((RankDef r) => r.id), <String>['bronze', 'silver', 'gold', 'prism']);
    expect(c.flags.drawEnabled, isFalse);
    expect(c.flags.legacyPricingUntil, '2027-01-31T00:00:00Z');
    expect(c.proBypassActions, contains('wallpaperDownload'));
    expect(c.proDiscountActions, <String>['aiGeneration', 'dropWall', 'dropPack']);
  });

  test('null or empty docs give the defaults', () {
    expect(EconomyConfig.fromMap(null).spend.dropPack, 150);
    expect(EconomyConfig.fromMap(<String, dynamic>{}).award.referral, 100);
  });

  test('partial overrides keep every other field', () {
    final EconomyConfig c = EconomyConfig.fromMap(<String, dynamic>{
      'spend': <String, dynamic>{'wallpaperDownload': 12},
      'award': <String, dynamic>{'proStreakMultiplier': 2},
      'flags': <String, dynamic>{'drawEnabled': true},
      'shopPrices': <String, dynamic>{'frame_ring': 90, 'bad': 'x', 'neg': -1},
    });
    expect(c.spend.wallpaperDownload, 12);
    expect(c.spend.premiumWallpaperDownload, 25);
    expect(c.award.proStreakMultiplier, 2);
    expect(c.award.rewardedAd, 10);
    expect(c.flags.drawEnabled, isTrue);
    expect(c.flags.dropsEnabled, isTrue);
    expect(c.shopPrices, <String, int>{'frame_ring': 90});
  });

  test('malformed fields fall back one by one', () {
    final EconomyConfig c = EconomyConfig.fromMap(<String, dynamic>{
      'spend': <String, dynamic>{'wallpaperDownload': -3, 'dropWall': 'cheap', 'dropPack': 20000},
      'award': <String, dynamic>{
        'streakDaily': <int>[1, 2, 3],
        'proSpin': <Object>[],
        'rewardedAd': 5000,
        'streakChestMin': 50,
        'streakChestMax': 20,
      },
      'xp': <String, dynamic>{'ranks': 'none'},
      'flags': 'off',
      'proBypassActions': <Object>['wallpaperDownload', 3],
    });
    expect(c.spend.wallpaperDownload, 10);
    expect(c.spend.dropWall, 30);
    expect(c.spend.dropPack, 150);
    expect(c.award.streakDaily, <int>[3, 3, 5, 5, 8, 8, 10]);
    expect(c.award.proSpin, hasLength(5));
    expect(c.award.rewardedAd, 10);
    expect((c.award.streakChestMin, c.award.streakChestMax), (15, 40));
    expect(c.xp.ranks, hasLength(4));
    expect(c.flags.drawEnabled, isFalse);
    expect(c.proBypassActions, EconomyConfig.defaults.proBypassActions);
  });

  test('a spin table with zero total weight falls back', () {
    final EconomyConfig c = EconomyConfig.fromMap(<String, dynamic>{
      'award': <String, dynamic>{
        'proSpin': <Map<String, num>>[
          <String, num>{'coins': 5, 'weight': 0},
        ],
      },
    });
    expect(c.award.proSpin, hasLength(5));
  });

  group('spin wheel', () {
    EconomyConfig parse({Object? price, Object? cap, Object? wheel, bool absent = false}) =>
        EconomyConfig.fromMap(<String, dynamic>{
          if (!absent) ...<String, dynamic>{
            'spend': <String, dynamic>{'spinWheel': price},
            'award': <String, dynamic>{'spinWheelMaxPerDay': cap, 'spinWheel': wheel},
          },
        });

    test('a valid price, cap and table are read', () {
      final EconomyConfig c = parse(
        price: 15,
        cap: 3,
        wheel: <Map<String, Object>>[
          <String, Object>{'kind': 'coins', 'coins': 7, 'weight': 2},
          <String, Object>{'kind': 'coins', 'coins': 40, 'weight': 1.5},
          <String, Object>{'kind': 'cosmetic', 'fallbackCoins': 1, 'weight': 1},
        ],
      );
      expect(c.spend.spinWheel, 15);
      expect(c.award.spinWheelMaxPerDay, 3);
      expect(describeWheel(c.award.spinWheel), <String>['coins 7 x2', 'coins 40 x1', 'cosmetic 1 x1']);
    });

    test('zero is a valid price and a valid cap', () {
      final EconomyConfig c = parse(price: 0, cap: 0);
      expect((c.spend.spinWheel, c.award.spinWheelMaxPerDay), (0, 0));
    });

    test('a doc without the fields gives the defaults', () {
      for (final EconomyConfig c in <EconomyConfig>[
        parse(absent: true),
        parse(),
        EconomyConfig.fromMap(<String, dynamic>{'spend': <String, dynamic>{}, 'award': <String, dynamic>{}}),
      ]) {
        expect((c.spend.spinWheel, c.award.spinWheelMaxPerDay), (10, 5));
        expect(describeWheel(c.award.spinWheel), defaultWheelLines);
      }
    });

    test('a malformed price falls back to 10', () {
      for (final Object? bad in <Object?>[-1, 10001, 'ten', true, double.nan]) {
        expect(parse(price: bad).spend.spinWheel, 10, reason: '$bad');
      }
    });

    test('a malformed cap falls back to 5', () {
      for (final Object? bad in <Object?>[-1, 1001, 'five', false, double.infinity]) {
        expect(parse(cap: bad).award.spinWheelMaxPerDay, 5, reason: '$bad');
      }
    });

    test('a malformed table falls back to the default wheel and leaves price and cap alone', () {
      final List<Object?> bad = <Object?>[
        'wheel',
        <Map<String, Object>>[
          <String, Object>{'kind': 'coins', 'coins': 10, 'weight': 18},
          <String, Object>{'kind': 'xp', 'xp': 25, 'weight': 22},
        ],
        <Object>[],
        <Map<String, Object>>[
          <String, Object>{'kind': 'coins', 'coins': 5, 'weight': 1},
        ],
        <Map<String, Object>>[
          <String, Object>{'kind': 'coins', 'coins': 5, 'weight': 0},
          <String, Object>{'kind': 'coins', 'coins': 6, 'weight': 0},
        ],
        <Map<String, Object>>[
          <String, Object>{'kind': 'coins', 'coins': 5, 'weight': 1},
          <String, Object>{'kind': 'coins', 'coins': 2000, 'weight': 1},
        ],
      ];
      for (final Object? wheel in bad) {
        final EconomyConfig c = parse(price: 12, cap: 4, wheel: wheel);
        expect(describeWheel(c.award.spinWheel), defaultWheelLines, reason: '$wheel');
        expect((c.spend.spinWheel, c.award.spinWheelMaxPerDay), (12, 4));
      }
    });
  });

  group('daily chest', () {
    EconomyConfig parse({Object? price, Object? table, bool absent = false}) => EconomyConfig.fromMap(<String, dynamic>{
      if (!absent) ...<String, dynamic>{
        'spend': <String, dynamic>{'dailyChest': price},
        'award': <String, dynamic>{'dailyChest': table},
      },
    });

    test('a valid price and table are read, next to an untouched spin wheel', () {
      final EconomyConfig c = parse(
        price: 6,
        table: <Map<String, Object>>[
          <String, Object>{'kind': 'coins', 'coins': 7, 'weight': 2},
          <String, Object>{'kind': 'coins', 'coins': 40, 'weight': 1.5},
          <String, Object>{'kind': 'cosmetic', 'fallbackCoins': 1, 'weight': 1},
        ],
      );
      expect(c.spend.dailyChest, 6);
      expect(describeWheel(c.award.dailyChest), <String>['coins 7 x2', 'coins 40 x1', 'cosmetic 1 x1']);
      expect(c.spend.spinWheel, 10);
      expect(describeWheel(c.award.spinWheel), defaultWheelLines);
    });

    test('zero is a valid price', () {
      expect(parse(price: 0).spend.dailyChest, 0);
    });

    test('a doc without the fields gives the defaults', () {
      for (final EconomyConfig c in <EconomyConfig>[
        parse(absent: true),
        parse(),
        EconomyConfig.fromMap(<String, dynamic>{'spend': <String, dynamic>{}, 'award': <String, dynamic>{}}),
      ]) {
        expect(c.spend.dailyChest, 8);
        expect(describeWheel(c.award.dailyChest), defaultChestLines);
      }
    });

    test('a malformed price falls back to 8', () {
      for (final Object? bad in <Object?>[-1, 10001, 'eight', true, double.nan]) {
        expect(parse(price: bad).spend.dailyChest, 8, reason: '$bad');
      }
    });

    test('a malformed table, or one with an XP slot, falls back to the default chest and keeps the price', () {
      final List<Object?> bad = <Object?>[
        'chest',
        <Object>[],
        <Map<String, Object>>[
          <String, Object>{'kind': 'coins', 'coins': 10, 'weight': 18},
          <String, Object>{'kind': 'xp', 'xp': 25, 'weight': 15},
        ],
        <Map<String, Object>>[
          <String, Object>{'kind': 'xp', 'xp': 25, 'weight': 1},
          <String, Object>{'kind': 'xp', 'xp': 50, 'weight': 1},
        ],
        <Map<String, Object>>[
          <String, Object>{'kind': 'coins', 'coins': 5, 'weight': 1},
        ],
        <Map<String, Object>>[
          <String, Object>{'kind': 'coins', 'coins': 5, 'weight': 0},
          <String, Object>{'kind': 'coins', 'coins': 6, 'weight': 0},
        ],
        <Map<String, Object>>[
          <String, Object>{'kind': 'coins', 'coins': 5, 'weight': 1},
          <String, Object>{'kind': 'coins', 'coins': 2000, 'weight': 1},
        ],
        <Map<String, Object>>[
          for (int i = 0; i < 13; i++) <String, Object>{'kind': 'coins', 'coins': 5, 'weight': 1},
        ],
      ];
      for (final Object? table in bad) {
        final EconomyConfig c = parse(price: 12, table: table);
        expect(describeWheel(c.award.dailyChest), defaultChestLines, reason: '$table');
        expect(c.spend.dailyChest, 12);
      }
    });
  });

  test('money sinks can never be in the Pro bypass set', () {
    final EconomyConfig c = EconomyConfig.fromMap(<String, dynamic>{
      'proBypassActions': <String>['aiGeneration', 'dropWall', 'dropPack', 'premiumFilter'],
    });
    expect(c.proBypassActions, <String>['premiumFilter']);
  });

  test('ranks are sorted and rankFor reports progress to the next rank', () {
    final EconomyConfig c = EconomyConfig.fromMap(<String, dynamic>{
      'xp': <String, dynamic>{
        'ranks': <Map<String, Object>>[
          <String, Object>{'id': 'gold', 'min': 200},
          <String, Object>{'id': 'bronze', 'min': 0},
          <String, Object>{'id': 'silver', 'min': 100},
        ],
      },
    });
    expect(c.xp.ranks.map((RankDef r) => r.id), <String>['bronze', 'silver', 'gold']);
    final Rank start = c.rankFor(0);
    expect((start.id, start.next?.id, start.progress), ('bronze', 'silver', 0.0));
    final Rank mid = c.rankFor(150);
    expect((mid.id, mid.min, mid.next?.id, mid.progress), ('silver', 100, 'gold', 0.5));
    final Rank top = c.rankFor(5000);
    expect((top.id, top.next, top.progress), ('gold', null, 1.0));
  });

  test('default ranks', () {
    expect(EconomyConfig.defaults.rankFor(499).id, 'bronze');
    expect(EconomyConfig.defaults.rankFor(500).id, 'silver');
    expect(EconomyConfig.defaults.rankFor(2000).id, 'gold');
    expect(EconomyConfig.defaults.rankFor(6000).id, 'prism');
  });

  test('proPrice halves for Pro, rounds up, never zero', () {
    expect(proPrice(10, true), 5);
    expect(proPrice(75, true), 38);
    expect(proPrice(1, true), 1);
    expect(proPrice(0, true), 0);
    expect(proPrice(75, false), 75);
  });

  test('week and day keys match the server', () {
    expect(economyWeekKey(DateTime.utc(2026, 10, 17)), '2026-W42');
    expect(economyWeekKey(DateTime.utc(2026, 10, 18, 23, 59)), '2026-W42');
    expect(economyWeekKey(DateTime.utc(2026, 10, 19)), '2026-W43');
    expect(economyWeekKey(DateTime.utc(2026, 12, 31)), '2026-W53');
    expect(economyWeekKey(DateTime.utc(2027, 1, 4)), '2027-W01');
    expect(economyDayKey(DateTime.utc(2026, 10, 17, 23)), '2026-10-17');
  });
}
