import 'package:Prism/features/creator_stats/domain/creator_stats.dart';
import 'package:Prism/features/creator_stats/domain/stats_period.dart';
import 'package:Prism/features/creator_stats/views/pages/creator_stats_page.dart';
import 'package:flutter_test/flutter_test.dart';

StatsWeek _week(int i, int? views) => StatsWeek(
  week: '2026-W${36 + i}',
  start: DateTime.utc(2026, 8, 31).add(Duration(days: i * 7)),
  endExclusive: DateTime.utc(2026, 8, 31).add(Duration(days: (i + 1) * 7)),
  metrics: {for (final m in StatsMetric.values) m: views},
);

void main() {
  test('this week uses the newest week and compares with the one before', () {
    expect(StatsPeriod.thisWeek.indexes(8), [7]);
    expect(StatsPeriod.thisWeek.previousIndexes(8), [6]);
  });

  test('last week skips the newest week', () {
    expect(StatsPeriod.lastWeek.indexes(8), [6]);
    expect(StatsPeriod.lastWeek.previousIndexes(8), [5]);
  });

  test('four weeks uses the newest four weeks and the four before them', () {
    expect(StatsPeriod.fourWeeks.indexes(8), [4, 5, 6, 7]);
    expect(StatsPeriod.fourWeeks.previousIndexes(8), [0, 1, 2, 3]);
  });

  test('four weeks has no previous window in a six week history', () {
    expect(StatsPeriod.fourWeeks.previousIndexes(6), isEmpty);
  });

  test('value sums the window', () {
    final history = [for (var i = 0; i < 8; i++) _week(i, i)];
    expect(StatsPeriod.thisWeek.value(history, StatsMetric.views), 7);
    expect(StatsPeriod.lastWeek.value(history, StatsMetric.views), 6);
    expect(StatsPeriod.fourWeeks.value(history, StatsMetric.views), 4 + 5 + 6 + 7);
  });

  test('value is null when any week in the window is unavailable', () {
    final history = [for (var i = 0; i < 8; i++) _week(i, i == 5 ? null : i)];
    expect(StatsPeriod.thisWeek.value(history, StatsMetric.views), 7);
    expect(StatsPeriod.fourWeeks.value(history, StatsMetric.views), isNull);
    expect(StatsPeriod.lastWeek.previous(history, StatsMetric.views), isNull);
  });

  test('previous is null when the history is too short for the comparison', () {
    final history = [for (var i = 0; i < 6; i++) _week(i, i)];
    expect(StatsPeriod.fourWeeks.previous(history, StatsMetric.views), isNull);
  });

  test('statsAxisTop picks the smallest even step at or above the peak', () {
    expect(statsAxisTop(0), 2);
    expect(statsAxisTop(1), 2);
    expect(statsAxisTop(7), 8);
    expect(statsAxisTop(13), 16);
    expect(statsAxisTop(124), 160);
    expect(statsAxisTop(1000), 1000);
    expect(statsAxisTop(1001), 1200);
  });
}
