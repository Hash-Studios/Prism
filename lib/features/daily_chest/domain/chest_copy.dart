import 'dart:math' as math;

import 'package:Prism/core/coins/daily_chest.dart';

/// Time to the next chest, which is the next UTC midnight: "5h 12m", "2h" or "40m".
String chestResetIn(DateTime now) {
  final DateTime utc = now.toUtc();
  final DateTime midnight = DateTime.utc(utc.year, utc.month, utc.day + 1);
  final int minutes = math.max(1, (midnight.difference(utc).inSeconds / 60).ceil());
  final int hours = minutes ~/ 60;
  final int rest = minutes % 60;
  if (hours == 0) return '${rest}m';
  return rest == 0 ? '${hours}h' : '${hours}h ${rest}m';
}

String _moreQuests(int count) => count == 1 ? '1 more quest' : '$count more quests';

/// The line under the box: what the chest costs now.
String chestCostLine(DailyChestStatus status, {required DateTime now}) {
  if (status.opened) return 'Opened. A new chest in ${chestResetIn(now)}.';
  if (status.free) return 'Your quests made it free today.';
  return 'Open it for ${status.price} coins, or finish ${_moreQuests(status.questsLeft)} to open it free.';
}

String chestBonusLine({required bool bonusDone}) =>
    bonusDone ? 'Bonus quest done: your coins are doubled.' : "Do today's bonus quest first to double your coins.";

/// The subtitle of the chest row on the Today card.
String chestRowSubtitle(DailyChestStatus status) {
  if (status.opened) return 'Opened. A new one tomorrow.';
  if (status.free) return 'Free today';
  return '${status.price} coins, or free after ${_moreQuests(status.questsLeft)}';
}
