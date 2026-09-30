import 'package:Prism/core/coins/coin_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('daily streak reward climbs the ladder and caps at day 7', () {
    const expected = <int, int>{0: 5, 1: 5, 2: 5, 3: 8, 4: 8, 5: 12, 6: 12, 7: 15, 30: 15};
    for (final entry in expected.entries) {
      expect(CoinPolicy.streakDailyRewardForDay(entry.key), entry.value, reason: 'day ${entry.key}');
    }
  });

  test('streak bonus is paid only from day 7', () {
    expect(CoinPolicy.streakBonusRewardForDay(6), 0);
    expect(CoinPolicy.streakBonusRewardForDay(7), 40);
  });

  test('total streak reward adds the bonus to the daily reward', () {
    expect(CoinPolicy.streakTotalRewardForDay(6), 12);
    expect(CoinPolicy.streakTotalRewardForDay(7), 55);
  });
}
