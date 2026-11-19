import 'package:Prism/features/creator_stats/domain/creator_stats.dart';

/// A window of the eight-week history and the window of the same length before it.
enum StatsPeriod {
  thisWeek(weeks: 1, offset: 0),
  lastWeek(weeks: 1, offset: 1),
  fourWeeks(weeks: 4, offset: 0);

  const StatsPeriod({required this.weeks, required this.offset});

  /// Number of weeks in the window.
  final int weeks;

  /// Number of newest weeks skipped before the window starts.
  final int offset;

  /// Indexes of the window in an oldest-first history of [length] weeks.
  List<int> indexes(int length) => [for (var i = length - offset - weeks; i < length - offset; i++) i];

  /// Indexes of the window just before [indexes], or empty when the history is too short.
  List<int> previousIndexes(int length) {
    final start = length - offset - 2 * weeks;
    return start < 0 ? const [] : [for (var i = start; i < start + weeks; i++) i];
  }

  /// Sum of [metric] over the window. Null when any week in it is unavailable.
  int? value(List<StatsWeek> history, StatsMetric metric) => _sum(history, metric, indexes(history.length));

  /// Sum of [metric] over the window before. Null when any week in it is unavailable.
  int? previous(List<StatsWeek> history, StatsMetric metric) => _sum(history, metric, previousIndexes(history.length));

  static int? _sum(List<StatsWeek> history, StatsMetric metric, List<int> indexes) {
    if (indexes.isEmpty) return null;
    var total = 0;
    for (final i in indexes) {
      final value = history[i].metrics[metric];
      if (value == null) return null;
      total += value;
    }
    return total;
  }
}
