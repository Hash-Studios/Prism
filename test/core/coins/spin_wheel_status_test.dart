import 'package:Prism/core/coins/economy_state.dart';
import 'package:Prism/core/coins/spin_wheel.dart';
import 'package:Prism/core/coins/spin_wheel_status.dart';
import 'package:flutter_test/flutter_test.dart';

const String _today = '2026-10-18';

QuestState _quests({String dayKey = _today, QuestEvent event = QuestEvent.proSpin, bool claimed = true}) => QuestState(
  dayKey: dayKey,
  items: const <QuestItem>[],
  chestOpened: false,
  chestDoubled: false,
  weekKey: '2026-W42',
  bonus: QuestItem(id: 'bonus', event: event, target: 1, progress: claimed ? 1 : 0, claimed: claimed),
);

(bool, int, int) _derive({
  SpinDay day = SpinDay.none,
  QuestState? quests,
  bool isPro = true,
  int price = 10,
  int maxPerDay = 5,
}) {
  final SpinWheelStatus s = deriveSpinWheelStatus(
    today: _today,
    day: day,
    quests: quests,
    isPro: isPro,
    price: price,
    maxPerDay: maxPerDay,
  );
  return (s.freeSpinAvailable, s.paidSpinsLeft, s.price);
}

void main() {
  group('deriveSpinWheelStatus', () {
    test('a fresh day gives a Pro member the free spin and every paid spin', () {
      expect(_derive(), (true, 5, 10));
    });

    test('a member without Pro never has the free spin', () {
      expect(_derive(isPro: false), (false, 5, 10));
    });

    test('paid spins taken today are subtracted from the cap', () {
      expect(_derive(day: const SpinDay(dayKey: _today, paid: 2)), (true, 3, 10));
    });

    test('the cap leaves no paid spins, and never goes below zero', () {
      expect(_derive(day: const SpinDay(dayKey: _today, paid: 5)), (true, 0, 10));
      expect(_derive(day: const SpinDay(dayKey: _today, paid: 9)), (true, 0, 10));
      expect(_derive(maxPerDay: 0), (true, 0, 10));
    });

    test('a used free spin stays used and does not count against the cap', () {
      expect(_derive(day: const SpinDay(dayKey: _today, freeUsed: true)), (false, 5, 10));
      expect(_derive(day: const SpinDay(dayKey: _today, paid: 1, freeUsed: true)), (false, 4, 10));
    });

    test("another day's counters do not carry over", () {
      expect(_derive(day: const SpinDay(dayKey: '2026-10-17', paid: 5, freeUsed: true)), (true, 5, 10));
    });

    test('the price and the cap come from the arguments', () {
      expect(_derive(price: 15, maxPerDay: 2, day: const SpinDay(dayKey: _today, paid: 1)), (true, 1, 15));
    });

    group('a legacy Pro spin from an old client', () {
      test("takes today's free spin when the pro_spin bonus quest is claimed", () {
        expect(_derive(quests: _quests()), (false, 5, 10));
      });

      test('does not count when the quest is from another day, unclaimed, or another event', () {
        expect(_derive(quests: _quests(dayKey: '2026-10-17')), (true, 5, 10));
        expect(_derive(quests: _quests(claimed: false)), (true, 5, 10));
        expect(_derive(quests: _quests(event: QuestEvent.watchAd)), (true, 5, 10));
      });

      test('does not touch the paid spins', () {
        expect(
          _derive(
            quests: _quests(),
            day: const SpinDay(dayKey: _today, paid: 3),
          ),
          (false, 2, 10),
        );
      });
    });
  });

  group('SpinDay.fromMap', () {
    test('reads the stored counters', () {
      final SpinDay day = SpinDay.fromMap(<String, Object>{'dayKey': _today, 'paid': 3, 'freeUsed': true});
      expect((day.dayKey, day.paid, day.freeUsed), (_today, 3, true));
    });

    test('a missing map, a map without a day key or a wrong type is none', () {
      for (final Object? raw in <Object?>[
        null,
        'x',
        3,
        <String, Object>{},
        <String, Object>{'paid': 2},
        <String, Object>{'dayKey': '', 'paid': 2},
        <String, Object>{'dayKey': 20261018, 'paid': 2},
      ]) {
        final SpinDay day = SpinDay.fromMap(raw);
        expect((day.dayKey, day.paid, day.freeUsed), ('', 0, false), reason: '$raw');
      }
    });

    test('a bad counter reads as zero or false', () {
      final SpinDay day = SpinDay.fromMap(<String, Object>{'dayKey': _today, 'paid': -4, 'freeUsed': 'yes'});
      expect((day.paid, day.freeUsed), (0, false));
      expect(SpinDay.fromMap(<String, Object>{'dayKey': _today, 'paid': 'many'}).paid, 0);
    });

    test('toMap writes what fromMap reads', () {
      const SpinDay day = SpinDay(dayKey: _today, paid: 4, freeUsed: true);
      expect(day.toMap(), <String, Object>{'dayKey': _today, 'paid': 4, 'freeUsed': true});
      final SpinDay back = SpinDay.fromMap(day.toMap());
      expect((back.dayKey, back.paid, back.freeUsed), (_today, 4, true));
    });
  });

  group('SpinDay.fromStatus', () {
    SpinDay from(SpinWheelStatus status, {bool isPro = true, SpinDay previous = SpinDay.none, int maxPerDay = 5}) =>
        SpinDay.fromStatus(status, today: _today, maxPerDay: maxPerDay, isPro: isPro, previous: previous);

    test('a Pro status with four paid spins left and no free spin means one paid spin and the free spin used', () {
      final SpinDay day = from(const SpinWheelStatus(freeSpinAvailable: false, paidSpinsLeft: 4, price: 10));
      expect((day.dayKey, day.paid, day.freeUsed), (_today, 1, true));
    });

    test('deriving from the counters gives the status back', () {
      for (final SpinWheelStatus status in const <SpinWheelStatus>[
        SpinWheelStatus(freeSpinAvailable: true, paidSpinsLeft: 5, price: 10),
        SpinWheelStatus(freeSpinAvailable: false, paidSpinsLeft: 3, price: 10),
        SpinWheelStatus(freeSpinAvailable: false, paidSpinsLeft: 0, price: 10),
      ]) {
        final SpinDay day = from(status);
        expect(
          deriveSpinWheelStatus(today: _today, day: day, quests: null, isPro: true, price: 10, maxPerDay: 5),
          status,
        );
      }
    });

    test('a status for a member without Pro keeps the free spin counter it had', () {
      const SpinWheelStatus status = SpinWheelStatus(freeSpinAvailable: false, paidSpinsLeft: 4, price: 10);
      expect(from(status, isPro: false).freeUsed, isFalse);
      expect(from(status, isPro: false, previous: const SpinDay(dayKey: _today, freeUsed: true)).freeUsed, isTrue);
      expect(from(status, isPro: false, previous: const SpinDay(dayKey: '2026-10-17', freeUsed: true)).freeUsed, false);
    });

    test('a cap smaller than the spins left reads as no paid spins taken', () {
      const SpinWheelStatus status = SpinWheelStatus(freeSpinAvailable: true, paidSpinsLeft: 8, price: 10);
      expect(from(status).paid, 0);
    });
  });

  group('parseSpinWheelStatus', () {
    test('reads a reply status', () {
      expect(
        parseSpinWheelStatus(<String, Object>{'freeSpinAvailable': false, 'paidSpinsLeft': 3, 'price': 12}),
        const SpinWheelStatus(freeSpinAvailable: false, paidSpinsLeft: 3, price: 12),
      );
    });

    test('a status with a missing or invalid field is null', () {
      expect(parseSpinWheelStatus(null), isNull);
      expect(parseSpinWheelStatus('status'), isNull);
      expect(parseSpinWheelStatus(<String, Object>{'paidSpinsLeft': 3, 'price': 12}), isNull);
      expect(parseSpinWheelStatus(<String, Object>{'freeSpinAvailable': 1, 'paidSpinsLeft': 3, 'price': 12}), isNull);
      expect(parseSpinWheelStatus(<String, Object>{'freeSpinAvailable': true, 'price': 12}), isNull);
      expect(
        parseSpinWheelStatus(<String, Object>{'freeSpinAvailable': true, 'paidSpinsLeft': -1, 'price': 12}),
        isNull,
      );
      expect(
        parseSpinWheelStatus(<String, Object>{'freeSpinAvailable': true, 'paidSpinsLeft': 3, 'price': -10}),
        isNull,
      );
    });
  });
}
