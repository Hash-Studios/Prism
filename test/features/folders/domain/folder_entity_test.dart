import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/features/favourite_walls/domain/entities/favourite_wall_entity.dart';
import 'package:Prism/features/folders/domain/entities/folder_entity.dart';
import 'package:flutter_test/flutter_test.dart';

FolderEntity folder(String id, {int count = 0, List<String> covers = const <String>[]}) => FolderEntity(
  id: id,
  ownerId: 'u1',
  name: 'F-$id',
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
  itemCount: count,
  covers: covers,
);

final DateTime _at = DateTime.utc(2026, 2);

void main() {
  group('folderItemKey', () {
    test('prefixes the item id with the lowercased provider', () {
      const PrismFavouriteWall prism = PrismFavouriteWall(
        id: 'x',
        wallpaper: PrismWallpaper(
          core: WallpaperCore(id: 'x', source: WallpaperSource.prism, fullUrl: 'https://x/x.jpg', thumbnailUrl: 't'),
        ),
      );
      const WallhavenFavouriteWall wallhaven = WallhavenFavouriteWall(
        id: 'x',
        wallpaper: WallhavenWallpaper(
          core: WallpaperCore(
            id: 'x',
            source: WallpaperSource.wallhaven,
            fullUrl: 'https://x/x.jpg',
            thumbnailUrl: 't',
          ),
        ),
      );
      const PexelsFavouriteWall pexels = PexelsFavouriteWall(
        id: 'x',
        wallpaper: PexelsWallpaper(
          core: WallpaperCore(id: 'x', source: WallpaperSource.pexels, fullUrl: 'https://x/x.jpg', thumbnailUrl: 't'),
        ),
      );

      expect(folderItemKey(prism), 'prism_x');
      expect(folderItemKey(wallhaven), 'wallhaven_x');
      expect(folderItemKey(pexels), 'pexels_x');
    });
  });

  group('normalizeFolderName', () {
    test('trims the name', () {
      expect(normalizeFolderName('  Blue  '), 'Blue');
    });

    test('returns null when the name is empty or only spaces', () {
      expect(normalizeFolderName(''), isNull);
      expect(normalizeFolderName('   '), isNull);
    });

    test('accepts 50 characters and rejects 51', () {
      expect(normalizeFolderName('x' * 50), 'x' * 50);
      expect(normalizeFolderName('x' * 51), isNull);
    });
  });

  group('withItemAdded', () {
    test('adds one to the count and puts the new thumb first', () {
      final FolderEntity next = folder('a', count: 1, covers: <String>['t1']).withItemAdded('t2', _at);

      expect(next.itemCount, 2);
      expect(next.covers, <String>['t2', 't1']);
      expect(next.updatedAt, _at);
    });

    test('keeps at most 4 covers, newest first', () {
      final FolderEntity next = folder(
        'a',
        count: 4,
        covers: <String>['t1', 't2', 't3', 't4'],
      ).withItemAdded('t5', _at);

      expect(next.covers, <String>['t5', 't1', 't2', 't3']);
    });

    test('does not duplicate a thumb that is already a cover', () {
      final FolderEntity next = folder('a', count: 2, covers: <String>['t1', 't2']).withItemAdded('t1', _at);

      expect(next.itemCount, 3);
      expect(next.covers, <String>['t1', 't2']);
    });
  });

  group('withItemRemoved', () {
    test('subtracts one from the count and sets covers from the remaining items', () {
      final FolderEntity next = folder(
        'a',
        count: 2,
        covers: <String>['t1', 't2'],
      ).withItemRemoved(<String>['t3'], _at);

      expect(next.itemCount, 1);
      expect(next.covers, <String>['t3']);
      expect(next.updatedAt, _at);
    });

    test('never takes the count below 0', () {
      final FolderEntity next = folder('a').withItemRemoved(<String>[], _at);

      expect(next.itemCount, 0);
      expect(next.covers, isEmpty);
    });

    test('keeps at most 4 covers', () {
      final FolderEntity next = folder('a', count: 9).withItemRemoved(<String>['a', 'b', 'c', 'd', 'e'], _at);

      expect(next.covers, <String>['a', 'b', 'c', 'd']);
    });
  });

  group('newFolderId', () {
    test('is 20 alphanumeric characters', () {
      final String id = newFolderId();

      expect(id, hasLength(20));
      expect(RegExp(r'^[A-Za-z0-9]{20}$').hasMatch(id), isTrue);
    });
  });
}
