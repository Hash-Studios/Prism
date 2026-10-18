import 'package:Prism/core/coins/daily_chest.dart';
import 'package:Prism/core/coins/spin_wheel.dart';
import 'package:Prism/features/spin_wheel/domain/wheel_prizes.dart';

/// The slots of one tier, with the chance of the tier as a whole.
class ChestOddsGroup {
  const ChestOddsGroup({required this.tier, required this.rows});

  final ChestTier tier;
  final List<WheelOdds> rows;

  /// Chance of this tier on one chest, 0 to 100.
  double get percent => rows.fold<double>(0, (double sum, WheelOdds o) => sum + o.percent);
}

/// The odds of [slots] grouped by tier, most common first. A tier with no slot is left out.
List<ChestOddsGroup> chestOddsByTier(List<WheelSegment> slots) {
  final List<WheelOdds> odds = wheelOdds(slots);
  final List<ChestOddsGroup> groups = <ChestOddsGroup>[];
  for (final ChestTier tier in ChestTier.values) {
    final List<WheelOdds> rows = <WheelOdds>[
      for (final (int i, WheelOdds o) in odds.indexed)
        if (chestTierOf(slots, i) == tier) o,
    ];
    if (rows.isNotEmpty) groups.add(ChestOddsGroup(tier: tier, rows: rows));
  }
  return groups;
}
