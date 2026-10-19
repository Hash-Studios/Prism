import 'dart:math' as math;

import 'package:Prism/core/coins/daily_chest.dart';
import 'package:Prism/l10n/l10n.dart';

/// Time to the next chest, which is the next UTC midnight: "5h 12m", "2h" or "40m".
String chestResetIn(AppLocalizations l10n, DateTime now) {
  final DateTime utc = now.toUtc();
  final DateTime midnight = DateTime.utc(utc.year, utc.month, utc.day + 1);
  final int minutes = math.max(1, (midnight.difference(utc).inSeconds / 60).ceil());
  final int hours = minutes ~/ 60;
  final int rest = minutes % 60;
  if (hours == 0) return l10n.economyChestResetMinutes(rest);
  return rest == 0 ? l10n.economyChestResetHours(hours) : l10n.economyChestResetHoursMinutes(hours, rest);
}

/// The line under the box: what the chest costs now.
String chestCostLine(AppLocalizations l10n, DailyChestStatus status, {required DateTime now}) {
  if (status.opened) return l10n.economyChestOpenedReset(chestResetIn(l10n, now));
  if (status.free) return l10n.economyChestQuestsFree;
  return l10n.economyChestOpenFor(status.price, status.questsLeft);
}

String chestBonusLine(AppLocalizations l10n, {required bool bonusDone}) =>
    bonusDone ? l10n.economyChestBonusDone : l10n.economyChestBonusToDouble;

/// The subtitle of the chest row on the Today card. [doubled] is for a chest the bonus quest doubled.
String chestRowSubtitle(AppLocalizations l10n, DailyChestStatus status, {bool doubled = false}) {
  if (status.opened) return doubled ? l10n.economyChestOpenedDoubledTomorrow : l10n.economyChestOpenedTomorrow;
  if (status.free) return l10n.economyChestFreeToday;
  return l10n.economyChestPriceFreeAfter(status.price, status.questsLeft);
}
