import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/features/wallpaper_history/domain/entities/history_wall.dart';
import 'package:Prism/features/wallpaper_history/domain/recently_viewed_rules.dart';
import 'package:flutter_test/flutter_test.dart';

HistoryWall _wall(String id, DateTime at) => HistoryWall.tryCreate(
  id: id,
  source: WallpaperSource.wallhaven,
  thumbnailUrl: 'https://th.wallhaven.cc/small/ab/$id.jpg',
  action: HistoryAction.view,
  at: at,
)!;

final DateTime _sessionStart = DateTime.utc(2026, 10, 20, 12);

DateTime _hoursBefore(int hours) => _sessionStart.subtract(Duration(hours: hours));

void main() {
  group('ViewRecorder', () {
    testWidgets('shown then 2s counts once', (tester) async {
      int views = 0;
      final ViewRecorder recorder = ViewRecorder(() {
        views++;
      });
      recorder.shown();
      await tester.pump(const Duration(seconds: 2));
      expect(views, 1);
      await tester.pump(const Duration(seconds: 5));
      expect(views, 1);
    });

    testWidgets('a swipe past before the dwell does not count', (tester) async {
      int views = 0;
      final ViewRecorder recorder = ViewRecorder(() {
        views++;
      });
      recorder.shown();
      await tester.pump(const Duration(seconds: 1));
      recorder.hidden();
      await tester.pump(const Duration(seconds: 5));
      expect(views, 0);
    });

    testWidgets('coming back restarts the dwell', (tester) async {
      int views = 0;
      final ViewRecorder recorder = ViewRecorder(() {
        views++;
      });
      recorder.shown();
      await tester.pump(const Duration(seconds: 1));
      recorder.hidden();
      recorder.shown();
      await tester.pump(const Duration(milliseconds: 1500));
      expect(views, 0);
      await tester.pump(const Duration(milliseconds: 600));
      expect(views, 1);
    });

    testWidgets('acted counts at once and only once', (tester) async {
      int views = 0;
      final ViewRecorder recorder = ViewRecorder(() {
        views++;
      });
      recorder.acted();
      expect(views, 1);
      recorder.shown();
      await tester.pump(const Duration(seconds: 3));
      expect(views, 1);
    });

    testWidgets('dispose cancels a pending dwell', (tester) async {
      int views = 0;
      final ViewRecorder recorder = ViewRecorder(() {
        views++;
      });
      recorder.shown();
      recorder.dispose();
      await tester.pump(const Duration(seconds: 3));
      expect(views, 0);
    });
  });

  group('pickUpWalls', () {
    test('empty on a first session', () {
      final List<HistoryWall> walls = pickUpWalls(
        viewedNewestFirst: <HistoryWall>[for (int i = 1; i <= 5; i++) _wall('q$i', _hoursBefore(i))],
        sessionStart: _sessionStart,
        returningSession: false,
        kept: (_) => false,
      );
      expect(walls, isEmpty);
    });

    test('keeps only walls viewed in the 7 days before the session', () {
      final List<HistoryWall> walls = pickUpWalls(
        viewedNewestFirst: <HistoryWall>[
          _wall('after', _sessionStart.add(const Duration(hours: 1))),
          _wall('q1', _hoursBefore(1)),
          _wall('q2', _hoursBefore(2)),
          _wall('q3', _hoursBefore(3)),
          _wall('q4', _hoursBefore(4)),
          _wall('old', _sessionStart.subtract(const Duration(days: 8))),
        ],
        sessionStart: _sessionStart,
        returningSession: true,
        kept: (_) => false,
      );
      expect(walls.map((wall) => wall.id), <String>['q1', 'q2', 'q3', 'q4']);
    });

    test('excludes walls that are already kept', () {
      final List<HistoryWall> walls = pickUpWalls(
        viewedNewestFirst: <HistoryWall>[for (int i = 1; i <= 5; i++) _wall('q$i', _hoursBefore(i))],
        sessionStart: _sessionStart,
        returningSession: true,
        kept: (wall) => wall.id == 'q2',
      );
      expect(walls.map((wall) => wall.id), <String>['q1', 'q3', 'q4', 'q5']);
    });

    test('empty when fewer than 4 qualify', () {
      final List<HistoryWall> walls = pickUpWalls(
        viewedNewestFirst: <HistoryWall>[for (int i = 1; i <= 3; i++) _wall('q$i', _hoursBefore(i))],
        sessionStart: _sessionStart,
        returningSession: true,
        kept: (_) => false,
      );
      expect(walls, isEmpty);
    });

    test('returns exactly 4 when 4 qualify', () {
      final List<HistoryWall> walls = pickUpWalls(
        viewedNewestFirst: <HistoryWall>[for (int i = 1; i <= 4; i++) _wall('q$i', _hoursBefore(i))],
        sessionStart: _sessionStart,
        returningSession: true,
        kept: (_) => false,
      );
      expect(walls.map((wall) => wall.id), <String>['q1', 'q2', 'q3', 'q4']);
    });

    test('returns the first 10 qualifying walls in input order', () {
      final List<HistoryWall> walls = pickUpWalls(
        viewedNewestFirst: <HistoryWall>[for (int i = 1; i <= 15; i++) _wall('q$i', _hoursBefore(i))],
        sessionStart: _sessionStart,
        returningSession: true,
        kept: (_) => false,
      );
      expect(walls.map((wall) => wall.id), <String>['q1', 'q2', 'q3', 'q4', 'q5', 'q6', 'q7', 'q8', 'q9', 'q10']);
    });
  });
}
