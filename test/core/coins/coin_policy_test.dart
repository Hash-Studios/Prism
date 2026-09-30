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
    expect(CoinPolicy.streakClaimRewardForDay(3, isPro: false), 8);
    expect(CoinPolicy.streakClaimRewardForDay(3, isPro: true), 13);
    expect(CoinPolicy.streakClaimRewardForDay(7, isPro: true), 75);
  });

  test('isStreakAlive allows one missed day per held freeze', () {
    expect(isStreakAlive('2026-03-01', '2026-03-01', 0), isTrue);
    expect(isStreakAlive('2026-03-01', '2026-03-02', 0), isTrue);
    expect(isStreakAlive('2026-03-01', '2026-03-03', 0), isFalse);
    expect(isStreakAlive('2026-03-01', '2026-03-03', 1), isTrue);
    expect(isStreakAlive('2026-03-01', '2026-03-04', 1), isFalse);
    expect(isStreakAlive('2026-03-01', '2026-03-04', 2), isTrue);
    expect(isStreakAlive('2026-02-28', '2026-03-01', 0), isTrue);
    expect(isStreakAlive('', '2026-03-01', 2), isFalse);
  });

  test('non-day strings cannot keep a streak alive', () {
    expect(dayKeyGap('2026-03-01T00:00:00', '2026-03-02'), isNull);
    expect(dayKeyGap('20260301', '2026-03-02'), isNull);
    expect(dayKeyGap('2026-02-30', '2026-03-02'), isNull);
    expect(dayKeyGap('2026-13-01', '2027-01-02'), isNull);
  });
}
