import 'dart:math' as math;

import 'package:Prism/core/coins/spin_wheel.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:intl/intl.dart';

/// The most coins any slice pays. Cosmetic fallbacks are not counted: they pay only when every cosmetic is owned.
int maxWheelCoins(List<WheelSegment> segments) {
  int best = 0;
  for (final WheelSegment s in segments) {
    final WheelPrize prize = s.prize;
    if (prize is CoinsPrize) best = math.max(best, prize.coins);
  }
  return best;
}

/// What the main button of the machine does for this status and balance.
enum SpinAction {
  /// Spin: the free spin, or a paid one the balance covers.
  spin,

  /// The balance is short of the price: open the way to earn coins.
  getCoins,

  /// Today's spins are used up.
  capped,
}

SpinAction spinAction({required SpinWheelStatus status, required int balance}) {
  if (!status.canSpin) return SpinAction.capped;
  if (balance < status.nextCost) return SpinAction.getCoins;
  return SpinAction.spin;
}

class WheelOdds {
  const WheelOdds({required this.prize, required this.percent});

  final WheelPrize prize;

  /// Chance of this slice on one spin, 0 to 100.
  final double percent;
}

List<WheelOdds> wheelOdds(List<WheelSegment> segments) {
  final double total = segments.fold<double>(0, (double sum, WheelSegment s) => sum + s.weight);
  return <WheelOdds>[
    for (final WheelSegment s in segments) WheelOdds(prize: s.prize, percent: total <= 0 ? 0 : s.weight / total * 100),
  ];
}

/// "18%", or "0.5%" for a rare slice so it does not round to a lie.
String oddsLabel(double percent, AppLocalizations l10n) {
  final NumberFormat format = NumberFormat('0.#%', l10n.localeName);
  return format.format(math.max(0, percent) / 100);
}

/// The line under the odds pill: what is left today.
String spinsLeftCaption(AppLocalizations l10n, SpinWheelStatus status) {
  final int paid = status.paidSpinsLeft;
  if (status.freeSpinAvailable) return l10n.economyFreeSpinReady(paid);
  if (paid <= 0) return l10n.economyNoSpinsLeft;
  return l10n.economySpinsLeftToday(paid);
}
