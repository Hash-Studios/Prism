import 'package:Prism/core/coins/economy_config.dart';
import 'package:Prism/core/utils/json_utils.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:intl/intl.dart';

enum CreatorProgressStatus { unknown, loading, cached, loaded, unavailable }

enum CreatorMetric { approvedWalls, uniqueMembers }

class CreatorProgressState {
  const CreatorProgressState({this.progress, this.status = CreatorProgressStatus.unknown});

  final CreatorProgress? progress;
  final CreatorProgressStatus status;
}

class CreatorMilestone {
  const CreatorMilestone({required this.id, required this.metric, required this.target, required this.xp});

  final String id;
  final CreatorMetric metric;
  final int target;
  final int xp;
}

class CreatorWeek {
  const CreatorWeek({required this.weekKey, this.approvedWalls = 0, this.newMembers = 0, this.xp = 0});

  final String weekKey;
  final int approvedWalls;
  final int newMembers;
  final int xp;
}

/// Versioned, server-materialized creator history. Missing or unsupported data stays unknown.
class CreatorProgress {
  const CreatorProgress({
    required this.trackedSince,
    required this.approvedWalls,
    required this.uniqueMembers,
    required this.awardedIds,
    required this.milestones,
    required this.weeks,
  });

  static CreatorProgress? fromMap(Object? raw) {
    final Map<String, dynamic> data = toJsonMap(raw);
    bool count(Object? v) => v is int && v >= 0;
    if (data['version'] != 1 ||
        data['trackedSinceMs'] is! int ||
        (data['trackedSinceMs'] as int) <= 0 ||
        (data['trackedSinceMs'] as int) > 8640000000000000 ||
        !count(data['approvedWalls']) ||
        !count(data['uniqueMembers']) ||
        data['milestones'] is! List ||
        data['awardedIds'] is! List ||
        data['weeks'] is! List) {
      return null;
    }
    final List<CreatorMilestone> milestones = <CreatorMilestone>[];
    for (final Object? raw in data['milestones'] as List) {
      final Map<String, dynamic> row = toJsonMap(raw);
      if (row['id'] is! String ||
          (row['id'] as String).isEmpty ||
          !const <String>{'approvedWalls', 'uniqueMembers'}.contains(row['metric']) ||
          !count(row['target']) ||
          row['target'] == 0 ||
          !count(row['xp'])) {
        return null;
      }
      milestones.add(
        CreatorMilestone(
          id: row['id'] as String,
          metric: CreatorMetric.values.byName(row['metric'] as String),
          target: row['target'] as int,
          xp: row['xp'] as int,
        ),
      );
    }
    if (milestones.map((CreatorMilestone m) => m.id).toSet().length != milestones.length ||
        !CreatorMetric.values.every(
          (CreatorMetric metric) => milestones.any((CreatorMilestone m) => m.metric == metric),
        ) ||
        !(data['awardedIds'] as List).every((Object? value) => value is String) ||
        (data['weeks'] as List).length > 2) {
      return null;
    }
    final List<CreatorWeek> weeks = <CreatorWeek>[];
    for (final Object? raw in data['weeks'] as List) {
      final Map<String, dynamic> row = toJsonMap(raw);
      if (row['weekKey'] is! String ||
          !RegExp(r'^\d{4}-W\d{2}$').hasMatch(row['weekKey'] as String) ||
          !count(row['approvedWalls']) ||
          !count(row['newMembers']) ||
          !count(row['xp'])) {
        return null;
      }
      weeks.add(
        CreatorWeek(
          weekKey: row['weekKey'] as String,
          approvedWalls: row['approvedWalls'] as int,
          newMembers: row['newMembers'] as int,
          xp: row['xp'] as int,
        ),
      );
    }
    return CreatorProgress(
      trackedSince: DateTime.fromMillisecondsSinceEpoch(data['trackedSinceMs'] as int, isUtc: true),
      approvedWalls: data['approvedWalls'] as int,
      uniqueMembers: data['uniqueMembers'] as int,
      awardedIds: Set<String>.unmodifiable((data['awardedIds'] as List).whereType<String>()),
      milestones: List<CreatorMilestone>.unmodifiable(milestones),
      weeks: List<CreatorWeek>.unmodifiable(weeks),
    );
  }

  final DateTime trackedSince;
  final int approvedWalls;
  final int uniqueMembers;
  final Set<String> awardedIds;
  final List<CreatorMilestone> milestones;
  final List<CreatorWeek> weeks;

  CreatorWeek week(DateTime date) {
    final String key = economyWeekKey(date);
    return weeks.where((CreatorWeek w) => w.weekKey == key).firstOrNull ?? CreatorWeek(weekKey: key);
  }

  CreatorMilestone? next(CreatorMetric metric) =>
      milestones.where((CreatorMilestone m) => m.metric == metric && !awardedIds.contains(m.id)).firstOrNull;

  int countFor(CreatorMetric metric) => switch (metric) {
    CreatorMetric.approvedWalls => approvedWalls,
    CreatorMetric.uniqueMembers => uniqueMembers,
  };
}

String creatorDate(DateTime date, String locale) => DateFormat.yMMMd(locale).format(date.toUtc());

String creatorWeekDates(DateTime date, AppLocalizations l10n, String locale) {
  final DateTime utc = date.toUtc();
  final DateTime start = DateTime.utc(utc.year, utc.month, utc.day).subtract(Duration(days: utc.weekday - 1));
  final DateTime end = start.add(const Duration(days: 6));
  return l10n.economyCreatorWeekRange(creatorDate(start, locale), creatorDate(end, locale));
}
