import 'package:Prism/core/coins/coin_events.dart';
import 'package:Prism/core/coins/economy_config.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _event({
  String id = 'launch',
  required DateTime startsAt,
  required DateTime endsAt,
  Object? multiplier = 2,
  Object? actions = const <String>['rewardedAd'],
  Object? label = 'event',
}) => <String, dynamic>{
  'id': id,
  'startsAtMs': startsAt.millisecondsSinceEpoch,
  'endsAtMs': endsAt.millisecondsSinceEpoch,
  'multiplier': multiplier,
  'actions': actions,
  'label': label,
};

Map<String, dynamic> _weekly({int startDay = 6, int startMinute = 0, int durationMinutes = 2880}) => <String, dynamic>{
  'id': 'weekend',
  'startDay': startDay,
  'startMinute': startMinute,
  'durationMinutes': durationMinutes,
  'multiplier': 2,
  'actions': <String>['rewardedAd'],
  'label': 'weekend',
};

CoinEventSchedule _schedule({List<Map<String, dynamic>> events = const [], Map<String, dynamic>? weekly}) =>
    CoinEventSchedule.fromConfig(<String, dynamic>{'events': events, if (weekly != null) 'weeklyEvent': weekly});

// 2026-11-14 is a Saturday. The weekend runs Saturday 00:00 to Monday 00:00 UTC.
final DateTime _launchStart = DateTime.utc(2026, 11, 14, 12);
final DateTime _launchEnd = DateTime.utc(2026, 11, 14, 13);

void main() {
  test('parse keeps the valid event and drops every bad one', () {
    final List<Map<String, dynamic>> bad = <Map<String, dynamic>>[
      _event(id: 'bad-mult-1', startsAt: _launchStart, endsAt: _launchEnd, multiplier: 1),
      _event(id: 'bad-mult-4', startsAt: _launchStart, endsAt: _launchEnd, multiplier: 4),
      _event(id: 'bad-mult-2-5', startsAt: _launchStart, endsAt: _launchEnd, multiplier: 2.5),
      _event(id: 'bad-actions-empty', startsAt: _launchStart, endsAt: _launchEnd, actions: <String>[]),
      _event(id: 'bad-action-spend', startsAt: _launchStart, endsAt: _launchEnd, actions: <String>['spend']),
      _event(
        id: 'bad-action-mixed',
        startsAt: _launchStart,
        endsAt: _launchEnd,
        actions: <String>['rewardedAd', 'quest'],
      ),
      _event(id: 'bad-end-equal', startsAt: _launchStart, endsAt: _launchStart),
      _event(id: 'bad-end-before', startsAt: _launchStart, endsAt: _launchStart.subtract(const Duration(hours: 1))),
      _event(id: 'bad-too-long', startsAt: _launchStart, endsAt: _launchStart.add(const Duration(days: 32))),
      _event(id: 'Bad Id', startsAt: _launchStart, endsAt: _launchEnd),
      _event(id: 'bad-label', startsAt: _launchStart, endsAt: _launchEnd, label: 'party'),
    ];
    final List<Map<String, dynamic>> good = <Map<String, dynamic>>[
      _event(id: 'good', startsAt: _launchStart, endsAt: _launchEnd),
    ];

    expect(_schedule(events: <Map<String, dynamic>>[...bad, ...good]).liveAt(_launchStart)?.id, 'good');
    for (final Map<String, dynamic> entry in bad) {
      expect(_schedule(events: <Map<String, dynamic>>[entry]).liveAt(_launchStart), isNull, reason: '${entry['id']}');
    }
  });

  test('a missing label is the event label', () {
    final CoinEventWindow? live = _schedule(
      events: <Map<String, dynamic>>[(_event(startsAt: _launchStart, endsAt: _launchEnd)..remove('label'))],
    ).liveAt(_launchStart);

    expect(live?.label, CoinEventLabel.event);
  });

  test('explicit null labels are dropped without hiding valid entries', () {
    final schedule = _schedule(
      events: [
        _event(id: 'a-null', startsAt: _launchStart, endsAt: _launchEnd, label: null),
        _event(id: 'good', startsAt: _launchStart, endsAt: _launchEnd),
      ],
    );
    expect(schedule.liveAt(_launchStart)?.id, 'good');
  });

  test('integral Firestore doubles match the server event and weekly rules', () {
    final event = _event(startsAt: _launchStart, endsAt: _launchEnd, multiplier: 3.0)
      ..['startsAtMs'] = _launchStart.millisecondsSinceEpoch.toDouble()
      ..['endsAtMs'] = _launchEnd.millisecondsSinceEpoch.toDouble();
    expect(_schedule(events: [event]).liveAt(_launchStart)?.multiplier, 3);
    final weekly = _weekly()
      ..['startDay'] = 6.0
      ..['startMinute'] = 0.0
      ..['durationMinutes'] = 2880.0;
    expect(_schedule(weekly: weekly).liveAt(_launchStart)?.id, 'weekend-2026-11-14');
  });

  test('out of range timestamps do not discard good events', () {
    final schedule = _schedule(
      events: [
        _event(id: 'invalid', startsAt: _launchStart, endsAt: _launchEnd)
          ..['startsAtMs'] = 8640000000000001
          ..['endsAtMs'] = 8640000000000002,
        _event(id: 'good', startsAt: _launchStart, endsAt: _launchEnd),
      ],
    );
    expect(schedule.liveAt(_launchStart)?.id, 'good');
  });

  test('receipt accepts integral doubles without throwing', () {
    expect(CoinEventReceipt.tryParse({'id': 'launch', 'multiplier': 2.0})?.multiplier, 2);
    expect(CoinEventReceipt.tryParse({'id': 'launch', 'multiplier': 2.5}), isNull);
  });

  test('bad weekly rules are ignored', () {
    final List<Map<String, dynamic>> bad = <Map<String, dynamic>>[
      _weekly(startDay: 0),
      _weekly(startDay: 8),
      _weekly(durationMinutes: 0),
      _weekly(durationMinutes: 10080),
    ];
    for (final Map<String, dynamic> weekly in bad) {
      final CoinEventSchedule schedule = _schedule(weekly: weekly);
      expect(schedule.liveAt(DateTime.utc(2026, 11, 14, 12)), isNull, reason: '$weekly');
      expect(schedule.nextAfter(DateTime.utc(2026, 11, 11)), isNull, reason: '$weekly');
    }
  });

  test('a one-off event is live from start inclusive to end exclusive', () {
    final CoinEventSchedule schedule = _schedule(
      events: <Map<String, dynamic>>[_event(startsAt: _launchStart, endsAt: _launchEnd)],
    );

    expect(schedule.liveAt(_launchStart), isNotNull);
    expect(schedule.liveAt(_launchEnd.subtract(const Duration(milliseconds: 1))), isNotNull);
    expect(schedule.liveAt(_launchStart.subtract(const Duration(milliseconds: 1))), isNull);
    expect(schedule.liveAt(_launchEnd), isNull);

    expect(schedule.multiplierAt(_launchStart), 2);
    expect(schedule.multiplierAt(_launchStart.subtract(const Duration(milliseconds: 1))), 1);
  });

  test('the weekly weekend is live Saturday to Monday UTC', () {
    final CoinEventSchedule schedule = _schedule(weekly: _weekly());

    final CoinEventWindow? saturday = schedule.liveAt(DateTime.utc(2026, 11, 14));
    expect(saturday?.id, 'weekend-2026-11-14');
    expect(saturday?.label, CoinEventLabel.weekend);
    expect(saturday?.endsAt, DateTime.utc(2026, 11, 16));

    expect(schedule.liveAt(DateTime.utc(2026, 11, 15, 23, 59, 59, 999)), isNotNull);
    expect(schedule.liveAt(DateTime.utc(2026, 11, 16)), isNull);
    expect(schedule.liveAt(DateTime.utc(2026, 11, 13, 23, 59, 59, 999)), isNull);
  });

  test('nextAfter finds the next occurrence within the seven day horizon', () {
    final CoinEventSchedule schedule = _schedule(weekly: _weekly());

    expect(schedule.nextAfter(DateTime.utc(2026, 11, 11))?.startsAt, DateTime.utc(2026, 11, 14));
    expect(schedule.nextAfter(DateTime.utc(2026, 11, 14, 12))?.startsAt, DateTime.utc(2026, 11, 21));
  });

  test('nextAfter shows a one-off within seven days and hides one beyond it', () {
    final DateTime now = DateTime.utc(2026, 11, 11);
    final DateTime soon = now.add(const Duration(days: 3));
    final CoinEventSchedule near = _schedule(
      events: <Map<String, dynamic>>[_event(startsAt: soon, endsAt: soon.add(const Duration(hours: 2)))],
    );
    final CoinEventSchedule far = _schedule(
      events: <Map<String, dynamic>>[
        _event(startsAt: now.add(const Duration(days: 8)), endsAt: now.add(const Duration(days: 8, hours: 2))),
      ],
    );

    expect(near.nextAfter(now)?.startsAt, soon);
    expect(far.nextAfter(now), isNull);
  });

  test('nextAfter returns the soonest of several upcoming events', () {
    final DateTime now = DateTime.utc(2026, 11, 11);
    final CoinEventSchedule schedule = _schedule(
      events: <Map<String, dynamic>>[
        _event(
          id: 'soon',
          startsAt: now.add(const Duration(days: 2)),
          endsAt: now.add(const Duration(days: 2, hours: 1)),
        ),
      ],
      weekly: _weekly(),
    );

    expect(schedule.nextAfter(now)?.id, 'soon');
  });

  test('overlapping events pay the highest multiplier', () {
    final CoinEventSchedule schedule = _schedule(
      events: <Map<String, dynamic>>[
        _event(id: 'double', startsAt: _launchStart, endsAt: _launchEnd),
        _event(id: 'triple', startsAt: _launchStart, endsAt: _launchEnd, multiplier: 3),
      ],
    );

    expect(schedule.liveAt(_launchStart)?.multiplier, 3);
    expect(schedule.multiplierAt(_launchStart), 3);
  });

  test('EconomyConfig reads the events from the config doc', () {
    final DateTime now = DateTime.utc(2026, 11, 14, 12, 30);
    final EconomyConfig config = EconomyConfig.fromMap(<String, dynamic>{
      'events': <Map<String, dynamic>>[
        _event(startsAt: now.subtract(const Duration(hours: 1)), endsAt: now.add(const Duration(hours: 1))),
      ],
    });

    expect(config.coinEvents.liveAt(now), isNotNull);
    expect(EconomyConfig.defaults.coinEvents.liveAt(now), isNull);
  });
}
