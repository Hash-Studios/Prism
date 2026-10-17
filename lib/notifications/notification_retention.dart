import 'dart:convert';

/// Kinds shared with `functions/src/notificationScoreboard.ts`.
const List<String> notificationScoreboardKinds = <String>[
  'wotd',
  'wotd_creator',
  'streak_reminder',
  'follower',
  'post',
  'moderation',
  'campaign',
  'rejection',
  'win_back',
];

const Duration appOpenStampDebounce = Duration(minutes: 15);

/// Device offset in minutes, rounded to 15, from -12:00 to +14:00. Same grid as Wall of the Day.
int roundedTimezoneOffsetMinutes(Duration offset) {
  final int minutes = (offset.inMinutes / 15).round() * 15;
  if (minutes < -720) return -720;
  if (minutes > 840) return 840;
  return minutes;
}

bool shouldStampAppOpen({DateTime? last, required DateTime now}) {
  if (last == null) return true;
  return now.difference(last) >= appOpenStampDebounce;
}

String localDayKey(DateTime local) {
  final String month = local.month.toString().padLeft(2, '0');
  final String day = local.day.toString().padLeft(2, '0');
  return '${local.year}-$month-$day';
}

bool isNextLocalDay(String tapDay, DateTime openedAt) {
  final List<String> parts = tapDay.split('-');
  if (parts.length != 3) return false;
  final int? year = int.tryParse(parts[0]);
  final int? month = int.tryParse(parts[1]);
  final int? day = int.tryParse(parts[2]);
  if (year == null || month == null || day == null) return false;
  final DateTime next = DateTime(year, month, day + 1);
  return openedAt.year == next.year && openedAt.month == next.month && openedAt.day == next.day;
}

class PendingPushReturns {
  const PendingPushReturns({required this.localDay, required this.kinds, required this.reported});

  final String localDay;
  final Set<String> kinds;
  final Set<String> reported;

  PendingPushReturns addKind(String kind) {
    return PendingPushReturns(localDay: localDay, kinds: {...kinds, kind}, reported: reported);
  }
}

/// Kinds tapped on the previous local day that this open can credit, once each.
List<String> returnsToReport(PendingPushReturns? pending, DateTime openedAt) {
  if (pending == null || !isNextLocalDay(pending.localDay, openedAt)) return const <String>[];
  final List<String> due = pending.kinds.where((String kind) => !pending.reported.contains(kind)).toList()..sort();
  return due;
}

PendingPushReturns rememberTap(PendingPushReturns? current, String kind, DateTime now) {
  final String day = localDayKey(now);
  if (current == null || current.localDay != day) {
    return PendingPushReturns(localDay: day, kinds: <String>{kind}, reported: const <String>{});
  }
  return current.addKind(kind);
}

PendingPushReturns? pendingAfterTapAttempt({
  required PendingPushReturns? current,
  required String kind,
  required DateTime now,
  required bool returnReportSucceeded,
}) {
  if (returnsToReport(current, now).isNotEmpty) {
    if (!returnReportSucceeded) return current;
    return rememberTap(null, kind, now);
  }
  return rememberTap(current, kind, now);
}

PendingPushReturns markReported(PendingPushReturns pending, Iterable<String> kinds) {
  return PendingPushReturns(
    localDay: pending.localDay,
    kinds: pending.kinds,
    reported: <String>{...pending.reported, ...kinds},
  );
}

String encodePending(PendingPushReturns pending) {
  final List<String> kinds = pending.kinds.toList()..sort();
  final List<String> reported = pending.reported.toList()..sort();
  return jsonEncode(<String, Object>{'day': pending.localDay, 'kinds': kinds, 'reported': reported});
}

PendingPushReturns? decodePending(String raw) {
  if (raw.trim().isEmpty) return null;
  try {
    final Object? decoded = jsonDecode(raw);
    if (decoded is! Map) return null;
    final Object? day = decoded['day'];
    if (day is! String || day.isEmpty) return null;
    return PendingPushReturns(
      localDay: day,
      kinds: _strings(decoded['kinds']),
      reported: _strings(decoded['reported']),
    );
  } catch (_) {
    return null;
  }
}

Set<String> _strings(Object? value) {
  if (value is! List) return <String>{};
  return value.whereType<String>().toSet();
}
