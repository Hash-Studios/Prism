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

/// Tips and the coins they carried.
class TipTally {
  const TipTally({required this.count, required this.coins});
  final int count;
  final int coins;
}

class TipWeek extends TipTally {
  const TipWeek({required this.week, required this.start, required super.count, required super.coins});
  final String week;
  final DateTime start;
}

/// Tips the creator got: all time, per stats week (oldest first) and per approved wall.
class CreatorTips extends TipTally {
  const CreatorTips({required super.count, required super.coins, required this.weeks, required this.walls});
  static const CreatorTips empty = CreatorTips(count: 0, coins: 0, weeks: <TipWeek>[], walls: <String, TipTally>{});
  final List<TipWeek> weeks;
  final Map<String, TipTally> walls;
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
    this.tips = CreatorTips.empty,
  });
  final DateTime generatedAt;
  final DateTime asOf;
  final int approvedWallCount;
  final Map<StatsMetric, int?> totals;
  final Map<StatsMetric, StatsCoverage> coverage;
  final List<StatsWeek> weeks;
  final List<WallStats> walls;
  final CreatorTips tips;
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
