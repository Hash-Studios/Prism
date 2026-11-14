import 'package:Prism/core/utils/json_utils.dart';

/// Picks the copy: "Weekend 2x" or "2x coins". Mirrors `CoinEventLabel` in functions/src/coinEvents.ts.
enum CoinEventLabel { weekend, event }

/// One event occurrence: start inclusive, end exclusive, both UTC.
class CoinEventWindow {
  const CoinEventWindow({
    required this.id,
    required this.multiplier,
    required this.label,
    required this.startsAt,
    required this.endsAt,
  });

  final String id;
  final int multiplier;
  final CoinEventLabel label;
  final DateTime startsAt;
  final DateTime endsAt;

  bool isLiveAt(DateTime now) => !now.isBefore(startsAt) && now.isBefore(endsAt);

  @override
  bool operator ==(Object other) =>
      other is CoinEventWindow &&
      other.id == id &&
      other.multiplier == multiplier &&
      other.label == label &&
      other.startsAt == startsAt &&
      other.endsAt == endsAt;

  @override
  int get hashCode => Object.hash(id, multiplier, label, startsAt, endsAt);
}

class _Rule {
  const _Rule(this.id, this.multiplier, this.label);

  final String id;
  final int multiplier;
  final CoinEventLabel label;
}

class _WeeklyRule extends _Rule {
  const _WeeklyRule(super.id, super.multiplier, super.label, this.startDay, this.startMinute, this.durationMinutes);

  final int startDay;
  final int startMinute;
  final int durationMinutes;

  /// The occurrence that started last at or before [now]. Mirrors `weeklyOccurrence` on the server.
  CoinEventWindow occurrenceAt(DateTime now) {
    final DateTime utc = now.toUtc();
    final DateTime monday = DateTime.utc(utc.year, utc.month, utc.day).subtract(Duration(days: utc.weekday - 1));
    DateTime start = monday.add(Duration(days: startDay - 1, minutes: startMinute));
    if (start.isAfter(utc)) start = start.subtract(const Duration(days: 7));
    return _window(start);
  }

  CoinEventWindow _window(DateTime start) => CoinEventWindow(
    id: '$id-${start.toIso8601String().substring(0, 10)}',
    multiplier: multiplier,
    label: label,
    startsAt: start,
    endsAt: start.add(Duration(minutes: durationMinutes)),
  );

  CoinEventWindow nextAfter(DateTime now) => _window(occurrenceAt(now).startsAt.add(const Duration(days: 7)));
}

final RegExp _id = RegExp(r'^[a-z0-9_-]{1,40}$');
const int _maxEvents = 50;
const Duration _maxEventLength = Duration(days: 31);
const int _minutesInWeek = 7 * 24 * 60;

bool _isInt(Object? raw, int min, int max) => raw is int && raw >= min && raw <= max;

/// Same rules as `parseCommon` on the server: a bad entry is dropped, never repaired.
_Rule? _common(Map<String, dynamic> m) {
  final Object? id = m['id'];
  final Object? multiplier = m['multiplier'];
  final Object? actions = m['actions'];
  final Object? label = m['label'] ?? 'event';
  if (id is! String || !_id.hasMatch(id)) return null;
  if (multiplier != 2 && multiplier != 3) return null;
  if (actions is! List || actions.isEmpty || actions.any((Object? a) => a != 'rewardedAd')) return null;
  final CoinEventLabel? parsed = switch (label) {
    'weekend' => CoinEventLabel.weekend,
    'event' => CoinEventLabel.event,
    _ => null,
  };
  return parsed == null ? null : _Rule(id, multiplier! as int, parsed);
}

/// The coin doubler events from `economyConfig/current` (`events` and `weeklyEvent`). v1 events double rewarded ads
/// only. The server decides what pays; this copy only decides what the Rewards screen shows.
class CoinEventSchedule {
  const CoinEventSchedule._(this._events, this._weekly);

  factory CoinEventSchedule.fromConfig(Map<String, dynamic> raw) {
    final List<CoinEventWindow> events = <CoinEventWindow>[];
    final Object? rawEvents = raw['events'];
    if (rawEvents is List) {
      for (final Object? entry in rawEvents.take(_maxEvents)) {
        if (entry is! Map) continue;
        final Map<String, dynamic> m = toJsonMap(entry);
        final _Rule? rule = _common(m);
        final Object? start = m['startsAtMs'];
        final Object? end = m['endsAtMs'];
        if (rule == null || start is! int || end is! int || start < 0 || end <= start) continue;
        if (end - start > _maxEventLength.inMilliseconds) continue;
        events.add(
          CoinEventWindow(
            id: rule.id,
            multiplier: rule.multiplier,
            label: rule.label,
            startsAt: DateTime.fromMillisecondsSinceEpoch(start, isUtc: true),
            endsAt: DateTime.fromMillisecondsSinceEpoch(end, isUtc: true),
          ),
        );
      }
    }
    _WeeklyRule? weekly;
    final Object? rawWeekly = raw['weeklyEvent'];
    if (rawWeekly is Map) {
      final Map<String, dynamic> m = toJsonMap(rawWeekly);
      final _Rule? rule = _common(m);
      if (rule != null &&
          _isInt(m['startDay'], 1, 7) &&
          _isInt(m['startMinute'], 0, 1439) &&
          _isInt(m['durationMinutes'], 1, _minutesInWeek - 1)) {
        weekly = _WeeklyRule(
          rule.id,
          rule.multiplier,
          rule.label,
          m['startDay'] as int,
          m['startMinute'] as int,
          m['durationMinutes'] as int,
        );
      }
    }
    return CoinEventSchedule._(List<CoinEventWindow>.unmodifiable(events), weekly);
  }

  static const CoinEventSchedule none = CoinEventSchedule._(<CoinEventWindow>[], null);

  /// How far ahead an upcoming event shows on Rewards.
  static const Duration nextHorizon = Duration(days: 7);

  final List<CoinEventWindow> _events;
  final _WeeklyRule? _weekly;

  /// The event paying rewarded ads at [now]. The highest multiplier wins, then the lower id, as on the server.
  CoinEventWindow? liveAt(DateTime now) {
    final List<CoinEventWindow> live = <CoinEventWindow>[
      ..._events.where((CoinEventWindow e) => e.isLiveAt(now)),
      if (_weekly case final _WeeklyRule weekly when weekly.occurrenceAt(now).isLiveAt(now)) weekly.occurrenceAt(now),
    ];
    live.sort((CoinEventWindow a, CoinEventWindow b) {
      final int byMultiplier = b.multiplier.compareTo(a.multiplier);
      return byMultiplier != 0 ? byMultiplier : a.id.compareTo(b.id);
    });
    return live.isEmpty ? null : live.first;
  }

  /// The soonest event that starts after [now] and within [nextHorizon].
  CoinEventWindow? nextAfter(DateTime now) {
    final DateTime limit = now.add(nextHorizon);
    final List<CoinEventWindow> upcoming = <CoinEventWindow>[
      ..._events.where((CoinEventWindow e) => e.startsAt.isAfter(now)),
      if (_weekly case final _WeeklyRule weekly) weekly.nextAfter(now),
    ].where((CoinEventWindow e) => !e.startsAt.isAfter(limit)).toList();
    upcoming.sort((CoinEventWindow a, CoinEventWindow b) => a.startsAt.compareTo(b.startsAt));
    return upcoming.isEmpty ? null : upcoming.first;
  }

  /// The multiplier a rewarded ad gets at [now]: 1 without a live event.
  int multiplierAt(DateTime now) => liveAt(now)?.multiplier ?? 1;
}

/// What the ledger stores on a coin transaction paid under an event (`coinEvent` on the tx doc).
class CoinEventReceipt {
  const CoinEventReceipt({required this.id, required this.multiplier, required this.label});

  /// Null when [raw] is not a valid receipt.
  static CoinEventReceipt? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final Object? id = raw['id'];
    final Object? multiplier = raw['multiplier'];
    final CoinEventLabel label = raw['label'] == 'weekend' ? CoinEventLabel.weekend : CoinEventLabel.event;
    if (id is! String || id.isEmpty || (multiplier != 2 && multiplier != 3)) return null;
    return CoinEventReceipt(id: id, multiplier: multiplier! as int, label: label);
  }

  final String id;
  final int multiplier;
  final CoinEventLabel label;
}
