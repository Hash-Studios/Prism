import 'package:Prism/core/coins/economy_config.dart';

/// ISO week key such as `2026-W42`, Monday start, in UTC. Matches `weekKey` in functions/src/economy.ts.
String isoWeekKey(DateTime utc) => economyWeekKey(utc);

/// The next Monday 00:00 UTC after [now]: when the weekly board resets.
DateTime nextWeekStart(DateTime now) {
  final DateTime utc = now.toUtc();
  return DateTime.utc(utc.year, utc.month, utc.day).add(Duration(days: DateTime.monday + 7 - utc.weekday));
}
