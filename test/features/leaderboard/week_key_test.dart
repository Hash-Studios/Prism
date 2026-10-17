import 'package:Prism/features/leaderboard/domain/week_key.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('isoWeekKey follows ISO weeks in UTC', () {
    expect(isoWeekKey(DateTime.utc(2026, 10, 17)), '2026-W42');
    expect(isoWeekKey(DateTime.utc(2026, 12, 31)), '2026-W53');
    expect(isoWeekKey(DateTime.utc(2027, 1, 4)), '2027-W01');
    expect(isoWeekKey(DateTime.utc(2027, 1, 3)), '2026-W53');
  });

  test('nextWeekStart is the next Monday 00:00 UTC', () {
    expect(nextWeekStart(DateTime.utc(2026, 10, 17, 13, 30)), DateTime.utc(2026, 10, 19));
    expect(nextWeekStart(DateTime.utc(2026, 10, 18, 23, 59)), DateTime.utc(2026, 10, 19));
    expect(nextWeekStart(DateTime.utc(2026, 10, 19)), DateTime.utc(2026, 10, 26));
    expect(nextWeekStart(DateTime.utc(2026, 12, 31)), DateTime.utc(2027, 1, 4));
  });
}
