import 'package:Prism/core/coins/spin_wheel.dart';
import 'package:flutter_test/flutter_test.dart';

import 'spin_wheel_test_helpers.dart';

void main() {
  group('parseWheel', () {
    test('reads every kind of slice in order', () {
      final List<WheelSegment>? wheel = parseWheel(defaultWheelJson);
      expect(describeWheel(wheel!), defaultWheelLines);
    });

    test('accepts the bounds: two slices, twelve slices, 1000 coins, 1 fallback coin, zero weight', () {
      expect(
        describeWheel(
          parseWheel(<Map<String, Object>>[
            <String, Object>{'kind': 'coins', 'coins': 1000, 'weight': 1000},
            <String, Object>{'kind': 'cosmetic', 'fallbackCoins': 1, 'weight': 0},
          ])!,
        ),
        <String>['coins 1000 x1000', 'cosmetic 1 x0'],
      );
      final List<Map<String, Object>> twelve = List<Map<String, Object>>.filled(12, <String, Object>{
        'kind': 'xp',
        'xp': 1,
        'weight': 1,
      });
      expect(parseWheel(twelve), hasLength(12));
    });

    test('refuses a table the server would refuse', () {
      Map<String, Object> coins(Object? amount, {Object weight = 1}) => <String, Object>{
        'kind': 'coins',
        if (amount != null) 'coins': amount,
        'weight': weight,
      };
      final Map<String, Object> ok = coins(5);
      expect(parseWheel(null), isNull);
      expect(parseWheel('wheel'), isNull);
      expect(parseWheel(<Object>[]), isNull);
      expect(parseWheel(<Object>[ok]), isNull, reason: 'one slice');
      expect(parseWheel(List<Object>.filled(13, ok)), isNull, reason: 'thirteen slices');
      expect(parseWheel(<Object>[ok, coins(0)]), isNull, reason: 'zero coins');
      expect(parseWheel(<Object>[ok, coins(1001)]), isNull, reason: 'over 1000 coins');
      expect(parseWheel(<Object>[ok, coins(2.5)]), isNull, reason: 'fractional coins');
      expect(parseWheel(<Object>[ok, coins('5')]), isNull, reason: 'coins as text');
      expect(parseWheel(<Object>[ok, coins(null)]), isNull, reason: 'missing coins');
      expect(parseWheel(<Object>[ok, coins(5, weight: -1)]), isNull, reason: 'negative weight');
      expect(parseWheel(<Object>[ok, coins(5, weight: 1001)]), isNull, reason: 'weight over 1000');
      expect(parseWheel(<Object>[coins(5, weight: 0), coins(6, weight: 0)]), isNull, reason: 'no weight at all');
      expect(
        parseWheel(<Object>[
          ok,
          <String, Object>{'kind': 'gem', 'weight': 1},
        ]),
        isNull,
        reason: 'unknown kind',
      );
      expect(parseWheel(<Object>[ok, 'coins']), isNull, reason: 'slice is not a map');
      expect(
        parseWheel(<Object>[
          ok,
          <String, Object>{'kind': 'cosmetic', 'fallbackCoins': 0, 'weight': 1},
        ]),
        isNull,
        reason: 'a fallback that pays nothing',
      );
    });
  });

  group('SpinWheelStatus', () {
    test('the next cost is zero while the free spin is open, else the price', () {
      const SpinWheelStatus free = SpinWheelStatus(freeSpinAvailable: true, paidSpinsLeft: 5, price: 10);
      const SpinWheelStatus paid = SpinWheelStatus(freeSpinAvailable: false, paidSpinsLeft: 2, price: 10);
      const SpinWheelStatus capped = SpinWheelStatus(freeSpinAvailable: false, paidSpinsLeft: 0, price: 10);
      expect((free.nextCost, free.canSpin), (0, true));
      expect((paid.nextCost, paid.canSpin), (10, true));
      expect((capped.nextCost, capped.canSpin), (10, false));
    });

    test('two statuses with the same fields are equal', () {
      const SpinWheelStatus a = SpinWheelStatus(freeSpinAvailable: true, paidSpinsLeft: 3, price: 10);
      const SpinWheelStatus b = SpinWheelStatus(freeSpinAvailable: true, paidSpinsLeft: 3, price: 10);
      const SpinWheelStatus c = SpinWheelStatus(freeSpinAvailable: false, paidSpinsLeft: 3, price: 10);
      expect(a == b, isTrue);
      expect(a.hashCode, b.hashCode);
      expect(a == c, isFalse);
    });
  });
}
