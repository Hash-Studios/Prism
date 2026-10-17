/// Shard docs for one UTC day. Kept in step with `SCOREBOARD_SHARD_COUNT`.
const int notificationScoreboardShardCount = 32;

const int notificationScoreboardWindowDays = 14;

/// Inclusive start and exclusive end document ids for the last 14 UTC dates.
class ScoreboardWindow {
  const ScoreboardWindow({required this.start, required this.end, required this.limit});

  final String start;
  final String end;
  final int limit;
}

ScoreboardWindow scoreboardWindow(DateTime utcNow) {
  final DateTime today = DateTime.utc(utcNow.year, utcNow.month, utcNow.day);
  final DateTime oldest = today.subtract(const Duration(days: notificationScoreboardWindowDays - 1));
  final DateTime tomorrow = DateTime.utc(today.year, today.month, today.day + 1);
  return ScoreboardWindow(
    start: _dayId(oldest),
    end: _dayId(tomorrow),
    limit: notificationScoreboardWindowDays * (notificationScoreboardShardCount + 1),
  );
}

/// `2026-10-17` and `2026-10-17_03` are the same calendar day.
String scoreboardDayKey(String docId) {
  final RegExpMatch? match = RegExp(r'^(\d{4}-\d{2}-\d{2})').firstMatch(docId);
  return match?.group(1) ?? docId;
}

/// Sums shard docs and returns one row per UTC day, newest first.
List<ScoreboardDay> combineScoreboardShards(Iterable<ScoreboardDay> shards) {
  final Map<String, ScoreboardDay> byDay = <String, ScoreboardDay>{};
  for (final ScoreboardDay shard in shards) {
    final String day = scoreboardDayKey(shard.day);
    final ScoreboardDay current = ScoreboardDay(
      day: day,
      sends: shard.sends,
      accepts: shard.accepts,
      fails: shard.fails,
      taps: shard.taps,
      returnedNextDay: shard.returnedNextDay,
      permissionGranted: shard.permissionGranted,
      permissionDeclined: shard.permissionDeclined,
    );
    final ScoreboardDay? prior = byDay[day];
    byDay[day] = prior == null ? current : _addDays(prior, current);
  }
  final List<ScoreboardDay> days = byDay.values.toList()
    ..sort((ScoreboardDay a, ScoreboardDay b) => b.day.compareTo(a.day));
  return days;
}

ScoreboardDay _addDays(ScoreboardDay a, ScoreboardDay b) {
  return ScoreboardDay(
    day: a.day,
    sends: _sumCounts(a.sends, b.sends),
    accepts: _sumCounts(a.accepts, b.accepts),
    fails: _sumCounts(a.fails, b.fails),
    taps: _sumCounts(a.taps, b.taps),
    returnedNextDay: _sumCounts(a.returnedNextDay, b.returnedNextDay),
    permissionGranted: a.permissionGranted + b.permissionGranted,
    permissionDeclined: a.permissionDeclined + b.permissionDeclined,
  );
}

Map<String, int> _sumCounts(Map<String, int> a, Map<String, int> b) {
  final Map<String, int> sums = Map<String, int>.of(a);
  b.forEach((String kind, int count) => sums[kind] = (sums[kind] ?? 0) + count);
  return sums;
}

String _dayId(DateTime utc) {
  final String month = utc.month.toString().padLeft(2, '0');
  final String day = utc.day.toString().padLeft(2, '0');
  return '${utc.year}-$month-$day';
}

class ScoreboardDay {
  const ScoreboardDay({
    required this.day,
    this.sends = const <String, int>{},
    this.accepts = const <String, int>{},
    this.fails = const <String, int>{},
    this.taps = const <String, int>{},
    this.returnedNextDay = const <String, int>{},
    this.permissionGranted = 0,
    this.permissionDeclined = 0,
  });

  final String day;
  final Map<String, int> sends;
  final Map<String, int> accepts;
  final Map<String, int> fails;
  final Map<String, int> taps;
  final Map<String, int> returnedNextDay;
  final int permissionGranted;
  final int permissionDeclined;

  factory ScoreboardDay.fromMap(String day, Map<String, dynamic> data) {
    return ScoreboardDay(
      day: day,
      sends: _counts(data['sends']),
      accepts: _counts(data['accepts']),
      fails: _counts(data['fails']),
      taps: _counts(data['taps']),
      returnedNextDay: _counts(data['returnedNextDay']),
      permissionGranted: _int(data['permissionGranted']),
      permissionDeclined: _int(data['permissionDeclined']),
    );
  }
}

/// One line for the admin list. Accepted is an FCM API accept, not a view.
String formatScoreboardLine(ScoreboardDay day) {
  final List<String> kinds = <String>{
    ...day.sends.keys,
    ...day.accepts.keys,
    ...day.fails.keys,
    ...day.taps.keys,
    ...day.returnedNextDay.keys,
  }.toList()..sort();
  final List<String> parts = <String>[
    for (final String kind in kinds)
      if (_total(day, kind) > 0) _formatKindLine(day, kind),
  ];
  if (day.permissionGranted > 0 || day.permissionDeclined > 0) {
    parts.add('permission ${day.permissionGranted} on, ${day.permissionDeclined} off');
  }
  if (parts.isEmpty) return day.day;
  return '${day.day}  ${parts.join(' · ')}';
}

String _formatKindLine(ScoreboardDay day, String kind) {
  return '$kind ${day.sends[kind] ?? 0} sent, ${day.accepts[kind] ?? 0} accepted, '
      '${day.fails[kind] ?? 0} failed, ${day.taps[kind] ?? 0} taps, ${day.returnedNextDay[kind] ?? 0} back';
}

int _total(ScoreboardDay day, String kind) {
  return (day.sends[kind] ?? 0) +
      (day.accepts[kind] ?? 0) +
      (day.fails[kind] ?? 0) +
      (day.taps[kind] ?? 0) +
      (day.returnedNextDay[kind] ?? 0);
}

Map<String, int> _counts(Object? raw) {
  if (raw is! Map) return const <String, int>{};
  final Map<String, int> counts = <String, int>{};
  raw.forEach((Object? key, Object? value) {
    if (key != null && value is num) counts[key.toString()] = value.toInt();
  });
  return counts;
}

int _int(Object? value) => value is num ? value.toInt() : 0;
