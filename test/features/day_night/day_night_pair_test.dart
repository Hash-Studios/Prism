import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/features/day_night/domain/entities/day_night_pair.dart';
import 'package:flutter_test/flutter_test.dart';

DayNightTimes _times(DayTime dayStart, DayTime nightStart) => DayNightTimes.tryCreate(dayStart, nightStart)!;

void main() {
  group('DayNightTimes.slotAt', () {
    final DayNightTimes standard = DayNightTimes.tryCreate(DayTime.hm(7, 0), DayTime.hm(19, 0))!;

    test('standard times switch at 07:00 and 19:00', () {
      expect(standard.slotAt(DayTime.hm(6, 59)), DayNightSlot.night);
      expect(standard.slotAt(DayTime.hm(7, 0)), DayNightSlot.day);
      expect(standard.slotAt(DayTime.hm(18, 59)), DayNightSlot.day);
      expect(standard.slotAt(DayTime.hm(19, 0)), DayNightSlot.night);
      expect(standard.slotAt(DayTime.hm(0, 0)), DayNightSlot.night);
    });

    test('day wraps past midnight when night starts before day', () {
      final DayNightTimes wrapped = _times(DayTime.hm(22, 0), DayTime.hm(6, 0));

      expect(wrapped.slotAt(DayTime.hm(23, 30)), DayNightSlot.day);
      expect(wrapped.slotAt(DayTime.hm(3, 0)), DayNightSlot.day);
      expect(wrapped.slotAt(DayTime.hm(6, 0)), DayNightSlot.night);
      expect(wrapped.slotAt(DayTime.hm(12, 0)), DayNightSlot.night);
    });
  });

  group('DayNightTimes.tryCreate', () {
    test('returns null for equal times', () {
      expect(DayNightTimes.tryCreate(DayTime.hm(7, 0), DayTime.hm(7, 0)), isNull);
    });
  });

  group('DayNightTimes.slotAtInstant', () {
    final DayNightTimes standard = DayNightTimes.tryCreate(DayTime.hm(7, 0), DayTime.hm(19, 0))!;
    final DateTime instant = DateTime.utc(2026, 3, 8, 14, 30);

    test('a +05:30 zone reads 20:00 as night', () {
      expect(standard.slotAtInstant(instant, const Duration(hours: 5, minutes: 30)), DayNightSlot.night);
    });

    test('a -08:00 zone reads 06:30 as night', () {
      expect(standard.slotAtInstant(instant, const Duration(hours: -8)), DayNightSlot.night);
    });

    test('a +00:00 zone reads 14:30 as day', () {
      expect(standard.slotAtInstant(instant, Duration.zero), DayNightSlot.day);
    });

    test('one hour of offset across 07:00 flips from night to day', () {
      final DateTime utcInstant = DateTime.utc(2026, 3, 8, 6, 30);

      expect(standard.slotAtInstant(utcInstant, Duration.zero), DayNightSlot.night);
      expect(standard.slotAtInstant(utcInstant, const Duration(hours: 1)), DayNightSlot.day);
    });
  });

  group('DayTime', () {
    test('hm rejects 24:00', () {
      expect(() => DayTime.hm(24, 0), throwsRangeError);
    });

    test('hm rejects a negative hour', () {
      expect(() => DayTime.hm(-1, 0), throwsRangeError);
    });

    test('fromMinutes accepts 0 to 1439 only', () {
      expect(DayTime.fromMinutes(0)?.minutes, 0);
      expect(DayTime.fromMinutes(1439)?.minutes, 1439);
      expect(DayTime.fromMinutes(1440), isNull);
      expect(DayTime.fromMinutes(-1), isNull);
      expect(DayTime.fromMinutes('420'), isNull);
    });
  });

  group('DayNightWall', () {
    const DayNightWall wall = DayNightWall(
      id: 'wall-1',
      source: WallpaperSource.wallhaven,
      fullUrl: 'https://example.com/wall-1.jpg',
      thumbnailUrl: 'https://example.com/wall-1-thumb.jpg',
      mainColor: '#663399',
    );

    test('toJson and fromJson round trip', () {
      expect(DayNightWall.fromJson(wall.toJson()), wall);
    });

    test('toJson writes the wire JSON keys', () {
      expect(wall.toJson(), <String, Object?>{
        'id': 'wall-1',
        'source': 'wallhaven',
        'fullUrl': 'https://example.com/wall-1.jpg',
        'thumbnailUrl': 'https://example.com/wall-1-thumb.jpg',
        'mainColor': '#663399',
      });
    });

    test('fromJson rejects a missing id', () {
      expect(
        DayNightWall.fromJson(<String, Object?>{
          'source': 'prism',
          'fullUrl': 'https://example.com/a.jpg',
          'thumbnailUrl': 'https://example.com/a-thumb.jpg',
        }),
        isNull,
      );
    });

    test('hasPublicImage is false for an empty or http URL and true for https', () {
      const DayNightWall empty = DayNightWall(id: 'a', source: WallpaperSource.prism, fullUrl: '', thumbnailUrl: '');
      const DayNightWall http = DayNightWall(
        id: 'b',
        source: WallpaperSource.prism,
        fullUrl: 'http://',
        thumbnailUrl: '',
      );
      const DayNightWall https = DayNightWall(
        id: 'c',
        source: WallpaperSource.prism,
        fullUrl: 'https://',
        thumbnailUrl: '',
      );

      expect(empty.hasPublicImage, isFalse);
      expect(http.hasPublicImage, isFalse);
      expect(https.hasPublicImage, isTrue);
    });
  });
}
