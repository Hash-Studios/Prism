import 'package:Prism/core/constants/app_functions.dart';
import 'package:Prism/features/creator_stats/domain/creator_stats.dart';
import 'package:injectable/injectable.dart';

@LazySingleton(as: CreatorStatsRepository)
class CreatorStatsRepositoryImpl implements CreatorStatsRepository {
  @override
  Future<CreatorStats> fetch() async =>
      parseCreatorStats((await appFunctions.httpsCallable('getCreatorStats').call<Object?>(<String, Object?>{})).data);
}

T _read<T>(Object? value) {
  if (value is T) return value;
  throw const FormatException('Malformed creator stats');
}

Map<String, Object?> _map(Object? value) {
  final map = _read<Map<Object?, Object?>>(value);
  if (map.keys.any((key) => key is! String)) throw const FormatException('Invalid stats keys');
  return map.map((key, value) => MapEntry(key! as String, value));
}

DateTime _date(Object? value) => DateTime.parse(_read<String>(value)).toUtc();
Map<StatsMetric, int?> _counts(Object? value) {
  final map = _map(value);
  if (StatsMetric.values.any((metric) => !map.containsKey(metric.name))) {
    throw const FormatException('Missing stats metric');
  }
  return {
    for (final metric in StatsMetric.values)
      metric: switch (map[metric.name]) {
        null => null,
        final int count when count >= 0 => count,
        _ => throw const FormatException('Invalid stats count'),
      },
  };
}

List<StatsWeek> _weeks(Object? value) {
  final weeks = _read<List<Object?>>(value)
      .map((value) {
        final m = _map(value);
        return StatsWeek(
          week: _read<String>(m['week']),
          start: _date(m['start']),
          endExclusive: _date(m['endExclusive']),
          metrics: _counts(m['metrics']),
        );
      })
      .toList(growable: false);
  if (weeks.length != 8) throw const FormatException('Expected eight weeks');
  for (var i = 0; i < weeks.length; i++) {
    final w = weeks[i];
    if (w.start.weekday != DateTime.monday ||
        w.start.hour != 0 ||
        w.start.minute != 0 ||
        w.start.second != 0 ||
        w.start.millisecond != 0 ||
        w.start.microsecond != 0 ||
        w.week != _isoWeek(w.start) ||
        w.endExclusive.difference(w.start) != const Duration(days: 7) ||
        (i > 0 && weeks[i - 1].endExclusive != w.start)) {
      throw const FormatException('Invalid UTC weeks');
    }
  }
  return weeks;
}

String _isoWeek(DateTime monday) {
  final thursday = monday.add(const Duration(days: 3));
  final first = DateTime.utc(thursday.year, 1, 4);
  final firstMonday = first.subtract(Duration(days: first.weekday - 1));
  final number = monday.difference(firstMonday).inDays ~/ 7 + 1;
  return '${thursday.year}-W${number.toString().padLeft(2, '0')}';
}

int _count(Object? value) => switch (value) {
  final int count when count >= 0 => count,
  _ => throw const FormatException('Invalid tip count'),
};

/// Servers older than tips send no `tips`; that reads as no tips.
CreatorTips _tips(Object? value, List<StatsWeek> weeks) {
  if (value == null) return CreatorTips.empty;
  final m = _map(value);
  final tipWeeks = _read<List<Object?>>(m['weeks'])
      .map((value) {
        final w = _map(value);
        return TipWeek(
          week: _read<String>(w['week']),
          start: _date(w['start']),
          count: _count(w['count']),
          coins: _count(w['coins']),
        );
      })
      .toList(growable: false);
  if (tipWeeks.length != weeks.length ||
      [for (var i = 0; i < weeks.length; i++) tipWeeks[i].week == weeks[i].week].contains(false)) {
    throw const FormatException('Mismatched tip weeks');
  }
  return CreatorTips(
    count: _count(m['count']),
    coins: _count(m['coins']),
    weeks: tipWeeks,
    walls: {
      for (final value in _read<List<Object?>>(m['walls']))
        _read<String>(_map(value)['wallId']): TipTally(
          count: _count(_map(value)['count']),
          coins: _count(_map(value)['coins']),
        ),
    },
  );
}

CreatorStats parseCreatorStats(Object? value) {
  final m = _map(value);
  if (m['schemaVersion'] != 1 || m['timezone'] != 'UTC') throw const FormatException('Unsupported creator stats');
  final weeks = _weeks(m['weeks']);
  final coverage = _map(m['coverage']);
  final walls = _read<List<Object?>>(m['walls'])
      .map((value) {
        final w = _map(value);
        final history = _weeks(w['weeks']);
        for (var i = 0; i < 8; i++) {
          if (history[i].week != weeks[i].week ||
              history[i].start != weeks[i].start ||
              history[i].endExclusive != weeks[i].endExclusive) {
            throw const FormatException('Mismatched wall weeks');
          }
        }
        return WallStats(
          wallId: _read<String>(w['wallId']),
          title: _read<String>(w['title']),
          thumbnailUrl: _read<String>(w['thumbnailUrl']),
          totals: _counts(w['totals']),
          weeks: history,
        );
      })
      .toList(growable: false);
  if (m['approvedWallCount'] != walls.length || walls.map((w) => w.wallId).toSet().length != walls.length) {
    throw const FormatException('Incomplete creator walls');
  }
  final asOf = _date(m['asOf']);
  if (asOf.isBefore(weeks.last.start) || !asOf.isBefore(weeks.last.endExclusive)) {
    throw const FormatException('Invalid current week');
  }
  return CreatorStats(
    generatedAt: _date(m['generatedAt']),
    asOf: asOf,
    approvedWallCount: _read<int>(m['approvedWallCount']),
    totals: _counts(m['totals']),
    coverage: {
      for (final metric in StatsMetric.values)
        metric: (() {
          final c = _map(coverage[metric.name]);
          if (!const {'recordedLifetime', 'currentMembership', 'since'}.contains(c['totalBasis'])) {
            throw const FormatException('Invalid coverage basis');
          }
          return StatsCoverage(
            weeklyFrom: c['weeklyFrom'] == null ? null : _date(c['weeklyFrom']),
            totalBasis: _read<String>(c['totalBasis']),
            totalFrom: c['totalFrom'] == null ? null : _date(c['totalFrom']),
          );
        })(),
    },
    weeks: weeks,
    walls: walls,
    tips: _tips(m['tips'], weeks),
  );
}
