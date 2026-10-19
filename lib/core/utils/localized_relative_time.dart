import 'package:Prism/l10n/l10n.dart';
import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

/// Formats relative durations with ARB labels and older dates with the active locale's date order.
String localizedRelativeTime(AppLocalizations l10n, DateTime when, {required Locale locale, DateTime? now}) {
  final DateTime local = when.toLocal();
  final Duration difference = (now ?? DateTime.now()).toUtc().difference(local.toUtc());
  final bool isFuture = difference.isNegative;
  final int seconds = difference.inSeconds.abs();
  if (seconds < 60) return l10n.coreRelativeTimeJustNow;
  if (seconds < const Duration(hours: 1).inSeconds) {
    final int minutes = seconds ~/ 60;
    return isFuture ? l10n.coreRelativeTimeMinutesFromNow(minutes) : l10n.coreRelativeTimeMinutesAgo(minutes);
  }
  if (seconds < const Duration(days: 1).inSeconds) {
    final int hours = seconds ~/ const Duration(hours: 1).inSeconds;
    return isFuture ? l10n.coreRelativeTimeHoursFromNow(hours) : l10n.coreRelativeTimeHoursAgo(hours);
  }
  if (seconds < const Duration(days: 7).inSeconds) {
    final int days = seconds ~/ const Duration(days: 1).inSeconds;
    return isFuture ? l10n.coreRelativeTimeDaysFromNow(days) : l10n.coreRelativeTimeDaysAgo(days);
  }
  return DateFormat.yMMMd(locale.toLanguageTag()).format(local);
}
