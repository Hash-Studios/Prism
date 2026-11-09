import 'package:Prism/core/firestore/converters/firestore_json_converters.dart';
import 'package:Prism/core/firestore/firestore_document.dart';
import 'package:intl/intl.dart';

/// The server window for `releaseAt`, measured from the write (functions/src/wallRelease.ts and firestore.rules).
const Duration minReleaseLead = Duration(minutes: 15);
const Duration maxReleaseLead = Duration(days: 30);

/// The picker asks for a little more than [minReleaseLead], so a slow upload still lands inside the window.
const Duration pickerReleaseLead = Duration(minutes: 20);

enum ReleaseTimeProblem { tooSoon, tooLate }

ReleaseTimeProblem? releaseTimeProblem(DateTime releaseAt, DateTime now) {
  if (releaseAt.isBefore(now.add(minReleaseLead))) return ReleaseTimeProblem.tooSoon;
  if (releaseAt.isAfter(now.add(maxReleaseLead))) return ReleaseTimeProblem.tooLate;
  return null;
}

/// The earliest time the picker offers: [pickerReleaseLead] ahead, rounded up to the next 5 minutes.
DateTime earliestReleasePick(DateTime now) {
  final DateTime lead = now.add(pickerReleaseLead);
  final int extra = lead.minute % 5 == 0 && lead.second == 0 && lead.millisecond == 0 && lead.microsecond == 0
      ? 0
      : 5 - lead.minute % 5;
  return DateTime(lead.year, lead.month, lead.day, lead.hour, lead.minute + extra);
}

/// Pending: in review. Scheduled: approved, waits for `releaseAt`. Published: public (`review == true`).
enum WallReleaseState { pending, scheduled, published }

class WallRelease {
  const WallRelease(this.state, this.releaseAt);

  factory WallRelease.of(FirestoreDocument wall) {
    final DateTime? releaseAt = _utc(wall.payload['releaseAt']);
    if (wall.review) return WallRelease(WallReleaseState.published, releaseAt);
    final DateTime? approved = _utc(wall.payload['releaseApprovedAt']);
    final DateTime? published = _utc(wall.payload['publishedAt']);
    final bool scheduled =
        approved != null && (wall.payload['publishedAt'] == null || (published != null && approved.isAfter(published)));
    return WallRelease(
      scheduled && releaseAt != null ? WallReleaseState.scheduled : WallReleaseState.pending,
      releaseAt,
    );
  }

  final WallReleaseState state;

  /// UTC, or null when the wall goes live on approval.
  final DateTime? releaseAt;

  static DateTime? _utc(Object? value) =>
      value is String ? null : const FirestoreDateTimeConverter().fromJson(value)?.toUtc();
}

/// "Fri 18:00" inside the next 6 days, else "14 Nov 18:00", in the device time zone.
String releaseWhenText(DateTime releaseAt, {required DateTime now, required String locale, required bool use24h}) {
  final DateTime local = releaseAt.toLocal();
  final DateTime localNow = now.toLocal();
  final DateTime today = DateTime.utc(localNow.year, localNow.month, localNow.day);
  final int days = DateTime.utc(local.year, local.month, local.day).difference(today).inDays;
  final DateFormat day = days >= 0 && days < 7 ? DateFormat.E(locale) : DateFormat.MMMd(locale);
  return '${day.format(local)} ${(use24h ? DateFormat.Hm(locale) : DateFormat.jm(locale)).format(local)}';
}

/// "UTC+05:30" for the offset that applies at that moment, so a date after a DST change shows its own offset.
String utcOffsetText(DateTime local) {
  final Duration offset = local.timeZoneOffset;
  final String sign = offset.isNegative ? '-' : '+';
  final int minutes = offset.inMinutes.abs();
  return 'UTC$sign${(minutes ~/ 60).toString().padLeft(2, '0')}:${(minutes % 60).toString().padLeft(2, '0')}';
}

/// "Fri 14 Nov, 12:30 UTC", for admins who review creators in every time zone.
String releaseUtcText(DateTime releaseAt) => '${DateFormat('EEE d MMM, HH:mm', 'en').format(releaseAt.toUtc())} UTC';
