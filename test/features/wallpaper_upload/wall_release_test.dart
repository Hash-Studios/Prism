import 'package:Prism/core/firestore/firestore_document.dart';
import 'package:Prism/features/wallpaper_upload/biz/wall_release.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('en');
  });

  group('releaseTimeProblem', () {
    final DateTime now = DateTime.utc(2026, 11, 5, 10);

    test('refuses a release less than 15 minutes ahead', () {
      expect(releaseTimeProblem(now.add(const Duration(minutes: 14)), now), ReleaseTimeProblem.tooSoon);
    });

    test('accepts a release exactly 15 minutes ahead', () {
      expect(releaseTimeProblem(now.add(const Duration(minutes: 15)), now), isNull);
    });

    test('accepts a release exactly 30 days ahead', () {
      expect(releaseTimeProblem(now.add(const Duration(days: 30)), now), isNull);
    });

    test('refuses a release more than 30 days ahead', () {
      expect(releaseTimeProblem(now.add(const Duration(days: 30, minutes: 1)), now), ReleaseTimeProblem.tooLate);
    });
  });

  group('earliestReleasePick', () {
    test('rounds seconds up instead of shortening the picker lead', () {
      expect(earliestReleasePick(DateTime(2026, 11, 14, 10, 5, 1)), DateTime(2026, 11, 14, 10, 30));
    });

    test('adds the 20 minute picker lead and rounds up to 5 minutes', () {
      expect(earliestReleasePick(DateTime(2026, 11, 14, 10, 3)), DateTime(2026, 11, 14, 10, 25));
      expect(earliestReleasePick(DateTime(2026, 11, 14, 10, 5)), DateTime(2026, 11, 14, 10, 25));
      expect(earliestReleasePick(DateTime(2026, 11, 14, 10, 40)), DateTime(2026, 11, 14, 11));
    });
  });

  group('WallRelease.of', () {
    test('a public wall is published', () {
      final WallRelease release = WallRelease.of(const FirestoreDocument('d', <String, dynamic>{'review': true}));
      expect(release.state, WallReleaseState.published);
      expect(release.releaseAt, isNull);
    });

    test('approved for a later time, not yet public, is scheduled with its UTC release time', () {
      final DateTime local = DateTime.utc(2026, 11, 20, 12, 30).toLocal();
      final WallRelease release = WallRelease.of(
        FirestoreDocument('d', <String, dynamic>{
          'review': false,
          'releaseApprovedAt': DateTime.utc(2026, 11, 5),
          'releaseAt': local,
        }),
      );
      expect(release.state, WallReleaseState.scheduled);
      expect(release.releaseAt!.isUtc, isTrue);
      expect(release.releaseAt, DateTime.utc(2026, 11, 20, 12, 30));
    });

    test('a Timestamp release time is converted to a UTC DateTime', () {
      final WallRelease release = WallRelease.of(
        FirestoreDocument('d', <String, dynamic>{
          'review': false,
          'releaseApprovedAt': DateTime.utc(2026, 11, 5),
          'releaseAt': Timestamp.fromDate(DateTime.utc(2026, 11, 20, 12, 30)),
        }),
      );
      expect(release.state, WallReleaseState.scheduled);
      expect(release.releaseAt!.isUtc, isTrue);
      expect(release.releaseAt, DateTime.utc(2026, 11, 20, 12, 30));
    });

    test('a release time without approval is pending', () {
      final WallRelease release = WallRelease.of(
        FirestoreDocument('d', <String, dynamic>{'review': false, 'releaseAt': DateTime.utc(2026, 11, 20)}),
      );
      expect(release.state, WallReleaseState.pending);
      expect(release.releaseAt, DateTime.utc(2026, 11, 20));
    });

    test('an approved wall that already has publishedAt is held, so it is pending', () {
      final WallRelease release = WallRelease.of(
        FirestoreDocument('d', <String, dynamic>{
          'review': false,
          'releaseApprovedAt': DateTime.utc(2026, 11, 5),
          'publishedAt': DateTime.utc(2026, 11, 20),
          'releaseAt': DateTime.utc(2026, 11, 20),
        }),
      );
      expect(release.state, WallReleaseState.pending);
    });
  });

  group('utcOffsetText', () {
    final RegExp shape = RegExp(r'^UTC[+-]\d{2}:\d{2}$');

    test('formats the offset as UTC+HH:mm or UTC-HH:mm', () {
      expect(utcOffsetText(DateTime.now()), matches(shape));
      expect(utcOffsetText(DateTime.utc(2026, 11, 14, 12, 30).toLocal()), matches(shape));
      expect(utcOffsetText(DateTime.utc(2026, 11, 14, 12, 30)), matches(shape));
    });
  });

  test('releaseUtcText shows the UTC weekday, date and time', () {
    final DateTime releaseAt = DateTime.utc(2026, 11, 14, 12, 30);
    expect(releaseAt.weekday, DateTime.saturday);
    expect(releaseUtcText(releaseAt), 'Sat 14 Nov, 12:30 UTC');
  });

  group('releaseWhenText', () {
    test('seven calendar days uses a date even across the spring DST change', () {
      final DateTime now = DateTime(2026, 3, 7, 10);
      final DateTime releaseAt = DateTime(2026, 3, 14, 18);
      expect(releaseWhenText(releaseAt, now: now, locale: 'en', use24h: true), 'Mar 14 18:00');
    });

    final DateTime now = DateTime(2026, 11, 5, 10);

    test('a release within 6 days shows the weekday and local 24h time', () {
      final DateTime releaseAt = now.add(const Duration(days: 2));
      final DateTime local = releaseAt.toLocal();
      final String text = releaseWhenText(releaseAt, now: now, locale: 'en', use24h: true);

      expect(text, '${DateFormat.E('en').format(local)} ${DateFormat.Hm('en').format(local)}');
      expect(text, matches(RegExp('^[A-Z][a-z]{2} ')));
      expect(text, matches(RegExp(r'\d{2}:\d{2}$')));
    });

    test('a release 10 days ahead shows the month and day', () {
      final DateTime releaseAt = now.add(const Duration(days: 10));
      final DateTime local = releaseAt.toLocal();

      expect(
        releaseWhenText(releaseAt, now: now, locale: 'en', use24h: true),
        '${DateFormat.MMMd('en').format(local)} ${DateFormat.Hm('en').format(local)}',
      );
    });
  });
}
