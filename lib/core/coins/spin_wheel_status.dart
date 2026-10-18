import 'dart:math';

import 'package:Prism/core/coins/economy_state.dart';
import 'package:Prism/core/coins/spin_wheel.dart';
import 'package:Prism/core/utils/json_utils.dart';
import 'package:Prism/core/wallpaper/parse_helpers.dart';

/// The spin counters of the day that last spun, from `private/economy.spinWheel`. They only count on [dayKey].
class SpinDay {
  const SpinDay({this.dayKey = '', this.paid = 0, this.freeUsed = false});

  /// Reads the stored map. Anything that is not a map with a day key is [none].
  factory SpinDay.fromMap(Object? raw) {
    final Map<String, dynamic> m = toJsonMap(raw);
    final Object? dayKey = m['dayKey'];
    if (dayKey is! String || dayKey.isEmpty) return none;
    return SpinDay(dayKey: dayKey, paid: max(0, parseIntOr(m['paid'])), freeUsed: m['freeUsed'] == true);
  }

  /// The counters that make [status] true on [today]. A spin reply carries the status, not the raw counters.
  factory SpinDay.fromStatus(
    SpinWheelStatus status, {
    required String today,
    required int maxPerDay,
    required bool isPro,
    required SpinDay previous,
  }) => SpinDay(
    dayKey: today,
    paid: max(0, maxPerDay - status.paidSpinsLeft),
    // A non-Pro status always says "no free spin". That says nothing about the counter, so keep it.
    freeUsed: isPro ? !status.freeSpinAvailable : previous.dayKey == today && previous.freeUsed,
  );

  static const SpinDay none = SpinDay();

  final String dayKey;

  /// Paid spins taken on [dayKey].
  final int paid;

  /// The Pro free spin was taken on [dayKey].
  final bool freeUsed;

  Map<String, Object> toMap() => <String, Object>{'dayKey': dayKey, 'paid': paid, 'freeUsed': freeUsed};
}

/// What the spin button shows today. Mirrors the checks of the `spinWheel` callable, so the button agrees with the
/// server unless the config or a legacy client moved under it. The callable has the last word and replies with its own
/// status.
///
/// [quests] is read for the legacy Pro spin: an old client's `claimProSpin` spends the same free spin and ticks the
/// `pro_spin` bonus quest, but writes no `spinWheel` counters.
SpinWheelStatus deriveSpinWheelStatus({
  required String today,
  required SpinDay day,
  required QuestState? quests,
  required bool isPro,
  required int price,
  required int maxPerDay,
}) {
  final bool counted = day.dayKey == today;
  final QuestItem? bonus = quests?.dayKey == today ? quests?.bonus : null;
  final bool legacyFreeSpinTaken = bonus != null && bonus.event == QuestEvent.proSpin && bonus.claimed;
  return SpinWheelStatus(
    freeSpinAvailable: isPro && !(counted && day.freeUsed) && !legacyFreeSpinTaken,
    paidSpinsLeft: max(0, maxPerDay - (counted ? day.paid : 0)),
    price: price,
  );
}

/// Reads the `status` of a spin reply. Null when any field is missing or invalid.
SpinWheelStatus? parseSpinWheelStatus(Object? raw) {
  if (raw is! Map) return null;
  final Map<String, dynamic> m = toJsonMap(raw);
  final Object? free = m['freeSpinAvailable'];
  final int? left = parseInt(m['paidSpinsLeft']);
  final int? price = parseInt(m['price']);
  if (free is! bool || left == null || left < 0 || price == null || price < 0) return null;
  return SpinWheelStatus(freeSpinAvailable: free, paidSpinsLeft: left, price: price);
}
