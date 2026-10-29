import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/features/wallpaper_history/domain/entities/history_wall.dart';
import 'package:flutter_test/flutter_test.dart';

HistoryWall _wall(String id, {DateTime? at, HistoryAction action = HistoryAction.set}) => HistoryWall.tryCreate(
  id: id,
  source: WallpaperSource.wallhaven,
  thumbnailUrl: 'https://th.wallhaven.cc/small/ab/$id.jpg',
  action: action,
  at: at ?? DateTime.utc(2026, 10, 20, 12),
)!;

HistoryWall? _tryCreate({
  String? id = 'abc',
  WallpaperSource? source = WallpaperSource.wallhaven,
  String? thumbnailUrl = 'https://th.wallhaven.cc/small/ab/abc.jpg',
}) => HistoryWall.tryCreate(
  id: id,
  source: source,
  thumbnailUrl: thumbnailUrl,
  action: HistoryAction.view,
  at: DateTime.utc(2026, 10, 20, 12),
);

void main() {
  group('tryCreate', () {
    test('returns null for an empty id', () {
      expect(_tryCreate(id: ''), isNull);
    });

    test('returns null for an id longer than 128 chars', () {
      expect(_tryCreate(id: 'a' * 129), isNull);
    });

    test('returns null for a downloaded or unknown source', () {
      expect(_tryCreate(source: WallpaperSource.downloaded), isNull);
      expect(_tryCreate(source: WallpaperSource.unknown), isNull);
    });

    test('returns null for a non-https thumbnail', () {
      expect(_tryCreate(thumbnailUrl: 'http://x.com/a.jpg'), isNull);
    });

    test('returns null for a file thumbnail', () {
      expect(_tryCreate(thumbnailUrl: 'file:///a.jpg'), isNull);
    });

    test('returns null for a signed thumbnail', () {
      expect(_tryCreate(thumbnailUrl: 'https://x.com/a.jpg?X-Amz-Signature=abc'), isNull);
    });

    test('returns null for a thumbnail with X-Amz-Credential', () {
      expect(_tryCreate(thumbnailUrl: 'https://x.com/a.jpg?X-Amz-Credential=abc'), isNull);
    });

    test('returns null for a thumbnail longer than 1024 chars', () {
      expect(_tryCreate(thumbnailUrl: 'https://x.com/${'a' * 1024}'), isNull);
    });

    test('returns null for a bare https scheme', () {
      expect(_tryCreate(thumbnailUrl: 'https://'), isNull);
    });
  });

  test('key is provider and id joined with an underscore', () {
    expect(_wall('abc').key, 'wallhaven_abc');
    final HistoryWall prism = HistoryWall.tryCreate(
      id: 'x',
      source: WallpaperSource.prism,
      thumbnailUrl: 'https://th.wallhaven.cc/small/ab/x.jpg',
      action: HistoryAction.set,
      at: DateTime.utc(2026, 10, 20, 12),
    )!;
    expect(prism.key, 'prism_x');
  });

  test('toDoc has exactly the Firestore fields and at is a DateTime', () {
    final doc = _wall('abc').toDoc();
    expect(doc.keys.toSet(), <String>{'id', 'provider', 'thumb', 'action', 'at'});
    expect(doc['at'], isA<DateTime>());
    expect(doc['action'], 'set');
    expect(doc['provider'], 'wallhaven');
  });

  test('tryParse(toJson()) round-trips to an equal wall', () {
    final HistoryWall wall = _wall('abc', action: HistoryAction.download);
    expect(HistoryWall.tryParse(wall.toJson()), wall);
  });

  test('tryParse returns null for a bad action', () {
    final Map<String, Object?> json = _wall('abc').toJson()..['action'] = 'view2';
    expect(HistoryWall.tryParse(json), isNull);
  });

  test('tryParse returns null when at is missing', () {
    final Map<String, Object?> json = _wall('abc').toJson()..remove('at');
    expect(HistoryWall.tryParse(json), isNull);
  });

  group('mergeHistory', () {
    test('keeps the newer entry of a repeated key, with its action', () {
      final List<HistoryWall> merged = mergeHistory(
        <HistoryWall>[_wall('a', at: DateTime.utc(2026, 10, 20, 10), action: HistoryAction.view)],
        <HistoryWall>[_wall('a', at: DateTime.utc(2026, 10, 20, 12))],
        cap: 10,
      );
      expect(merged, hasLength(1));
      expect(merged.single.at, DateTime.utc(2026, 10, 20, 12));
      expect(merged.single.action, HistoryAction.set);
    });

    test('returns newest first', () {
      final List<HistoryWall> merged = mergeHistory(
        <HistoryWall>[_wall('a', at: DateTime.utc(2026, 10, 20, 1)), _wall('c', at: DateTime.utc(2026, 10, 20, 3))],
        <HistoryWall>[_wall('b', at: DateTime.utc(2026, 10, 20, 2))],
        cap: 10,
      );
      expect(merged.map((wall) => wall.id), <String>['c', 'b', 'a']);
    });

    test('caps at 3 of 5 distinct walls and keeps the 3 newest', () {
      final List<HistoryWall> merged = mergeHistory(
        <HistoryWall>[for (int hour = 1; hour <= 5; hour++) _wall('h$hour', at: DateTime.utc(2026, 10, 20, hour))],
        const <HistoryWall>[],
        cap: 3,
      );
      expect(merged.map((wall) => wall.id), <String>['h5', 'h4', 'h3']);
    });

    test('never returns a duplicate key', () {
      final List<HistoryWall> merged = mergeHistory(
        <HistoryWall>[_wall('a', at: DateTime.utc(2026, 10, 20, 1)), _wall('b', at: DateTime.utc(2026, 10, 20, 2))],
        <HistoryWall>[_wall('a', at: DateTime.utc(2026, 10, 20, 3))],
        cap: 10,
      );
      expect(merged.map((wall) => wall.key), <String>['wallhaven_a', 'wallhaven_b']);
    });
  });
}
