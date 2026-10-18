import 'package:Prism/core/coins/spin_wheel.dart';

/// One readable line per slice, for example `coins 10 x18`, so a test can assert a whole wheel as literals.
List<String> describeWheel(List<WheelSegment> segments) => <String>[
  for (final WheelSegment s in segments)
    switch (s.prize) {
      CoinsPrize(:final int coins) => 'coins $coins x${s.weight.toInt()}',
      XpPrize(:final int xp) => 'xp $xp x${s.weight.toInt()}',
      CosmeticPrize(:final int fallbackCoins) => 'cosmetic $fallbackCoins x${s.weight.toInt()}',
    },
];

const List<String> defaultWheelLines = <String>[
  'coins 10 x18',
  'xp 25 x22',
  'coins 5 x30',
  'coins 100 x1',
  'coins 20 x8',
  'xp 50 x12',
  'coins 50 x3',
  'cosmetic 50 x6',
];

/// The wire JSON of [defaultWheel], the shape the server stores in `award.spinWheel` and returns in a spin reply.
const List<Map<String, Object>> defaultWheelJson = <Map<String, Object>>[
  <String, Object>{'kind': 'coins', 'coins': 10, 'weight': 18},
  <String, Object>{'kind': 'xp', 'xp': 25, 'weight': 22},
  <String, Object>{'kind': 'coins', 'coins': 5, 'weight': 30},
  <String, Object>{'kind': 'coins', 'coins': 100, 'weight': 1},
  <String, Object>{'kind': 'coins', 'coins': 20, 'weight': 8},
  <String, Object>{'kind': 'xp', 'xp': 50, 'weight': 12},
  <String, Object>{'kind': 'coins', 'coins': 50, 'weight': 3},
  <String, Object>{'kind': 'cosmetic', 'fallbackCoins': 50, 'weight': 6},
];

const List<String> defaultChestLines = <String>[
  'coins 5 x32',
  'coins 10 x26',
  'xp 25 x15',
  'coins 20 x13',
  'cosmetic 25 x8',
  'coins 40 x4',
  'coins 100 x2',
];

/// The wire JSON of `defaultChest`, the shape the server stores in `award.dailyChest` and returns in a chest reply.
const List<Map<String, Object>> defaultChestJson = <Map<String, Object>>[
  <String, Object>{'kind': 'coins', 'coins': 5, 'weight': 32},
  <String, Object>{'kind': 'coins', 'coins': 10, 'weight': 26},
  <String, Object>{'kind': 'xp', 'xp': 25, 'weight': 15},
  <String, Object>{'kind': 'coins', 'coins': 20, 'weight': 13},
  <String, Object>{'kind': 'cosmetic', 'fallbackCoins': 25, 'weight': 8},
  <String, Object>{'kind': 'coins', 'coins': 40, 'weight': 4},
  <String, Object>{'kind': 'coins', 'coins': 100, 'weight': 2},
];
