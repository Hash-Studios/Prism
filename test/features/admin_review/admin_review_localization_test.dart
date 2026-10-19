import 'package:Prism/core/utils/localized_relative_time.dart';
import 'package:Prism/features/admin_review/biz/admin_review_localization.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

void main() {
  late AppLocalizations l10n;

  setUpAll(() async {
    await initializeDateFormatting('en');
    l10n = await loadAppLocalizations(const Locale('en'));
  });

  test('maps report reason wire values to localized labels and unknown values to Other', () {
    expect(adminReviewReportReasonLabel('copyright', l10n), l10n.coreReportReasonCopyright);
    expect(adminReviewReportReasonLabel('Harassment', l10n), l10n.coreReportReasonHarassment);
    expect(adminReviewReportReasonLabel('sexual', l10n), l10n.coreReportReasonSexual);
    expect(adminReviewReportReasonLabel(' Spam ', l10n), l10n.coreReportReasonSpam);
    expect(adminReviewReportReasonLabel('unrecognized', l10n), l10n.coreReportReasonOther);
  });

  test('maps report content types and uses the localized unknown fallback', () {
    expect(adminReviewContentTypeLabel('user', l10n), l10n.coreContentReportUser);
    expect(adminReviewContentTypeLabel('wall', l10n), l10n.coreContentReportWallpaper);
    expect(adminReviewContentTypeLabel('setup', l10n), l10n.coreContentReportWallpaper);
    expect(adminReviewContentTypeLabel('future_type', l10n), l10n.notifReportUnknownContentType);
  });

  test('formats recent and future durations with localized labels, then falls back to locale dates', () {
    const Locale locale = Locale('en');
    final DateTime now = DateTime.utc(2026, 10, 19, 12);

    expect(
      localizedRelativeTime(l10n, now.subtract(const Duration(seconds: 30)), locale: locale, now: now),
      'Just now',
    );
    expect(
      localizedRelativeTime(l10n, now.subtract(const Duration(minutes: 3)), locale: locale, now: now),
      l10n.coreRelativeTimeMinutesAgo(3),
    );
    expect(
      localizedRelativeTime(l10n, now.subtract(const Duration(hours: 2)), locale: locale, now: now),
      l10n.coreRelativeTimeHoursAgo(2),
    );
    expect(
      localizedRelativeTime(l10n, now.subtract(const Duration(days: 2)), locale: locale, now: now),
      l10n.coreRelativeTimeDaysAgo(2),
    );
    expect(
      localizedRelativeTime(l10n, now.add(const Duration(minutes: 5)), locale: locale, now: now),
      l10n.coreRelativeTimeMinutesFromNow(5),
    );
    expect(
      localizedRelativeTime(l10n, DateTime.utc(2026, 3, 8, 15), locale: locale, now: DateTime.utc(2026, 3, 9, 14)),
      l10n.coreRelativeTimeHoursAgo(23),
      reason: 'a 23-hour interval stays 23 hours across a DST spring-forward day',
    );
    expect(
      localizedRelativeTime(l10n, DateTime.utc(2026, 10, 1, 12), locale: locale, now: now),
      DateFormat.yMMMd(locale.toLanguageTag()).format(DateTime.utc(2026, 10, 1, 12).toLocal()),
    );
  });
}
