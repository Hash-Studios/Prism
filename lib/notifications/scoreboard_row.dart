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
