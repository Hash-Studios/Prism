enum StatsMetric { views, saves, sets, downloads, shares, folderAdds, remixes }

class StatsWeek {
  const StatsWeek({required this.week, required this.start, required this.endExclusive, required this.metrics});
  final String week;
  final DateTime start;
  final DateTime endExclusive;
  final Map<StatsMetric, int?> metrics;
}

class StatsCoverage {
  const StatsCoverage({required this.weeklyFrom, required this.totalBasis, required this.totalFrom});
  final DateTime? weeklyFrom;
  final String totalBasis;
  final DateTime? totalFrom;
}

class WallStats {
  const WallStats({
    required this.wallId,
    required this.title,
    required this.thumbnailUrl,
    required this.totals,
    required this.weeks,
  });
  final String wallId;
  final String title;
  final String thumbnailUrl;
  final Map<StatsMetric, int?> totals;
  final List<StatsWeek> weeks;
}

class CreatorStats {
  const CreatorStats({
    required this.generatedAt,
    required this.asOf,
    required this.approvedWallCount,
    required this.totals,
    required this.coverage,
    required this.weeks,
    required this.walls,
  });
  final DateTime generatedAt;
  final DateTime asOf;
  final int approvedWallCount;
  final Map<StatsMetric, int?> totals;
  final Map<StatsMetric, StatsCoverage> coverage;
  final List<StatsWeek> weeks;
  final List<WallStats> walls;
  List<WallStats> ranked(StatsMetric metric) => [...walls]
    ..sort((a, b) {
      final av = a.weeks.last.metrics[metric];
      final bv = b.weeks.last.metrics[metric];
      if (av == null && bv != null) return 1;
      if (bv == null && av != null) return -1;
      final order = (bv ?? 0).compareTo(av ?? 0);
      return order == 0 ? a.wallId.compareTo(b.wallId) : order;
    });
}

abstract class CreatorStatsRepository {
  Future<CreatorStats> fetch();
}
