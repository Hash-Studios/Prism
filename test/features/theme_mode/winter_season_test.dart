import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/features/theme_mode/data/seasonal_announcement.dart';
import 'package:Prism/features/theme_mode/seasonal_themes.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/in_memory_local_store.dart';

/// The wall-clock fields of [utc] shifted by [offset], as a local DateTime with no zone.
DateTime wallClock(DateTime utc, Duration offset) {
  final DateTime u = utc.add(offset);
  return DateTime(u.year, u.month, u.day, u.hour, u.minute, u.second);
}

const Map<String, Duration> zones = <String, Duration>{
  'India': Duration(hours: 5, minutes: 30),
  'Los Angeles': Duration(hours: -8),
  'Auckland': Duration(hours: 13),
};

void main() {
  group('winter season window', () {
    for (final MapEntry<String, Duration> zone in zones.entries) {
      test('start and end edges follow the wall clock in ${zone.key}', () {
        final Duration offset = zone.value;
        // The instant whose wall clock in this zone reads [wall], built through wallClock.
        DateTime at(DateTime wall) => wallClock(
          DateTime.utc(wall.year, wall.month, wall.day, wall.hour, wall.minute, wall.second).subtract(offset),
          offset,
        );

        expect(winterSeason.window.contains(at(DateTime.utc(2026, 11, 30, 23, 59, 59))), isFalse);
        expect(winterSeason.window.contains(at(DateTime.utc(2026, 12, 1))), isTrue);
        expect(winterSeason.window.contains(at(DateTime.utc(2027, 1, 6, 23, 59, 59))), isTrue);
        expect(winterSeason.window.contains(at(DateTime.utc(2027, 1, 7))), isFalse);
      });
    }

    test('a UTC instant is read in the local zone of each place', () {
      final DateTime instant = DateTime.utc(2026, 11, 30, 20);

      expect(winterSeason.window.contains(wallClock(instant, zones['Auckland']!)), isTrue, reason: 'Auckland');
      expect(winterSeason.window.contains(wallClock(instant, zones['Los Angeles']!)), isFalse, reason: 'Los Angeles');
      expect(winterSeason.window.contains(wallClock(instant, zones['India']!)), isTrue, reason: 'India');
    });

    test('a UTC DateTime inside the window is read as local time', () {
      expect(winterSeason.window.contains(DateTime(2026, 12, 15).toUtc()), isTrue);
    });

    test('actual UTC inputs use local start and end instants exactly', () {
      final DateTime start = winterSeason.window.start.toUtc();
      final DateTime end = winterSeason.window.end.toUtc();

      expect(winterSeason.window.isUpcoming(start.subtract(const Duration(microseconds: 1))), isTrue);
      expect(winterSeason.window.contains(start.subtract(const Duration(microseconds: 1))), isFalse);
      expect(winterSeason.window.contains(start), isTrue);
      expect(winterSeason.window.isUpcoming(start), isFalse);
      expect(winterSeason.window.contains(end.subtract(const Duration(microseconds: 1))), isTrue);
      expect(winterSeason.window.hasEnded(end.subtract(const Duration(microseconds: 1))), isFalse);
      expect(winterSeason.window.contains(end), isFalse);
      expect(winterSeason.window.hasEnded(end), isTrue);
    });

    test('promo starts one day after the window and ends with it', () {
      expect(winterSeason.inSeason(DateTime(2026, 12, 1, 12)), isFalse);
      expect(winterSeason.inSeason(DateTime(2026, 12, 2)), isTrue);
      expect(winterSeason.inSeason(DateTime(2027, 1, 7)), isFalse);
    });
  });

  group('New Year window', () {
    test('actual UTC inputs use the local greeting boundaries', () {
      final DateTime start = newYearWindow.start.toUtc();
      final DateTime end = newYearWindow.end.toUtc();

      expect(newYearWindow.contains(start.subtract(const Duration(microseconds: 1))), isFalse);
      expect(newYearWindow.contains(start), isTrue);
      expect(newYearWindow.contains(end.subtract(const Duration(microseconds: 1))), isTrue);
      expect(newYearWindow.contains(end), isFalse);
    });

    test('starts on 31 December and ends on 1 January, local time', () {
      expect(newYearWindow.contains(DateTime(2026, 12, 30, 23, 59, 59)), isFalse);
      expect(newYearWindow.contains(DateTime(2026, 12, 31)), isTrue);
      expect(newYearWindow.contains(DateTime(2027, 1, 1, 23, 59, 59)), isTrue);
      expect(newYearWindow.contains(DateTime(2027, 1, 2)), isFalse);
    });

    for (final MapEntry<String, Duration> zone in zones.entries) {
      test('start and end edges follow the wall clock in ${zone.key}', () {
        final Duration offset = zone.value;

        DateTime at(DateTime wall) => wallClock(
          DateTime.utc(wall.year, wall.month, wall.day, wall.hour, wall.minute, wall.second).subtract(offset),
          offset,
        );

        expect(newYearWindow.contains(at(DateTime.utc(2026, 12, 30, 23, 59, 59))), isFalse);
        expect(newYearWindow.contains(at(DateTime.utc(2026, 12, 31))), isTrue);
        expect(newYearWindow.contains(at(DateTime.utc(2027, 1, 1, 23, 59, 59))), isTrue);
        expect(newYearWindow.contains(at(DateTime.utc(2027, 1, 2))), isFalse);
      });
    }
  });

  group('winter announcement for an upcoming season', () {
    late SettingsLocalDataSource settings;
    late List<SeasonalTheme> announced;

    Future<bool> announce(SeasonalTheme season) async {
      announced.add(season);
      return true;
    }

    setUp(() {
      settings = SettingsLocalDataSource(InMemoryLocalStore());
      announced = <SeasonalTheme>[];
    });

    test('an app update before the promo makes it pending without announcing', () async {
      await settings.set('lastSeenVersion', '1.0.0');

      final bool updated = await checkSeasonalAnnouncementOnAppUpdate(
        currentVersion: '1.1.0',
        currentBuild: '348',
        settings: settings,
        seasons: <SeasonalTheme>[winterSeason],
        now: DateTime(2026, 11, 25),
        announce: announce,
      );

      expect(updated, isTrue);
      expect(announced, isEmpty);
      expect(settings.get<bool>(winterSeason.pendingKey, defaultValue: false), isTrue);
    });

    test('launches before the promo keep it pending, and the first launch in the promo announces it once', () async {
      await settings.set('lastSeenVersion', '1.0.0');
      await checkSeasonalAnnouncementOnAppUpdate(
        currentVersion: '1.1.0',
        currentBuild: '348',
        settings: settings,
        seasons: <SeasonalTheme>[winterSeason],
        now: DateTime(2026, 11, 25),
        announce: announce,
      );

      final bool beforePromo = await checkSeasonalAnnouncementOnAppUpdate(
        currentVersion: '1.1.0',
        currentBuild: '348',
        settings: settings,
        seasons: <SeasonalTheme>[winterSeason],
        now: DateTime(2026, 12, 1, 23),
        announce: announce,
      );

      expect(beforePromo, isFalse);
      expect(announced, isEmpty);
      expect(settings.get<bool>(winterSeason.pendingKey, defaultValue: false), isTrue);

      final bool inPromo = await checkSeasonalAnnouncementOnAppUpdate(
        currentVersion: '1.1.0',
        currentBuild: '348',
        settings: settings,
        seasons: <SeasonalTheme>[winterSeason],
        now: DateTime(2026, 12, 2, 9),
        announce: announce,
      );

      expect(inPromo, isFalse);
      expect(announced, <SeasonalTheme>[winterSeason]);
      expect(settings.get<bool>(winterSeason.pendingKey, defaultValue: false), isFalse);
    });

    test('a pending flag after the promo ends is deleted without announcing', () async {
      await settings.set('lastSeenVersion', '1.1.0');
      await settings.set('lastSeenBuildVersion', '348');
      await settings.set(winterSeason.pendingKey, true);

      await checkSeasonalAnnouncementOnAppUpdate(
        currentVersion: '1.1.0',
        currentBuild: '348',
        settings: settings,
        seasons: <SeasonalTheme>[winterSeason],
        now: DateTime(2027, 1, 7),
        announce: announce,
      );

      expect(announced, isEmpty);
      expect(settings.get<bool>(winterSeason.pendingKey, defaultValue: false), isFalse);
    });
  });
}
