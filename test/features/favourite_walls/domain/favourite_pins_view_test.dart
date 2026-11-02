import 'package:Prism/core/firestore/dtos/wall_doc_dto.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/features/favourite_walls/data/favourite_wall_doc_mapper.dart';
import 'package:Prism/features/favourite_walls/domain/entities/favourite_wall_entity.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fav_fixtures.dart';

List<String> _ids(List<FavouriteWallEntity> walls) => walls.map((wall) => wall.id).toList(growable: false);

void main() {
  group('pin order', () {
    test('pinned walls come first in pin order, then the rest by the sort', () {
      final List<FavouriteWallEntity> items = <FavouriteWallEntity>[
        prismFav('u_new', createdAt: DateTime.utc(2026, 3)),
        prismFav('p2').withPinnedAt(DateTime.utc(2026, 2)),
        prismFav('u_old', createdAt: DateTime.utc(2024)),
        prismFav('p1').withPinnedAt(DateTime.utc(2026)),
        prismFav('p3').withPinnedAt(DateTime.utc(2026, 3)),
      ];

      final List<FavouriteWallEntity> view = applyFavouritesView(items);

      expect(_ids(view), <String>['p1', 'p2', 'p3', 'u_new', 'u_old']);
    });
  });

  group('pinned walls under each sort', () {
    final List<FavouriteWallEntity> items = <FavouriteWallEntity>[
      wallhavenFav('x_wh', createdAt: DateTime.utc(2024, 6)),
      pexelsFav('x_px', createdAt: DateTime.utc(2026)),
      prismFav('x_pr', createdAt: DateTime.utc(2025)),
      pexelsFav('p_late').withPinnedAt(DateTime.utc(2026, 2)),
      wallhavenFav('p_early').withPinnedAt(DateTime.utc(2026)),
    ];

    test('recentlyAdded keeps pinned first and sorts the rest newest first', () {
      final List<FavouriteWallEntity> view = applyFavouritesView(items);

      expect(_ids(view), <String>['p_early', 'p_late', 'x_px', 'x_pr', 'x_wh']);
    });

    test('oldest keeps pinned first and sorts the rest oldest first', () {
      final List<FavouriteWallEntity> view = applyFavouritesView(items, sort: FavouriteSort.oldest);

      expect(_ids(view), <String>['p_early', 'p_late', 'x_wh', 'x_pr', 'x_px']);
    });

    test('source keeps pinned first and sorts the rest by source', () {
      final List<FavouriteWallEntity> view = applyFavouritesView(items, sort: FavouriteSort.source);

      expect(_ids(view), <String>['p_early', 'p_late', 'x_pr', 'x_wh', 'x_px']);
    });
  });

  test('a source filter hides a pinned wall from another source and keeps pinned prism walls first', () {
    final List<FavouriteWallEntity> items = <FavouriteWallEntity>[
      wallhavenFav('wh_pinned').withPinnedAt(DateTime.utc(2026)),
      prismFav('pr_pinned', createdAt: DateTime.utc(2025)).withPinnedAt(DateTime.utc(2026, 2)),
      prismFav('pr_free', createdAt: DateTime.utc(2024)),
      wallhavenFav('wh_free', createdAt: DateTime.utc(2025)),
    ];

    final List<FavouriteWallEntity> view = applyFavouritesView(items, source: WallpaperSource.prism);

    expect(_ids(view), <String>['pr_pinned', 'pr_free']);
  });

  test('a query hides a pinned wall whose author does not match', () {
    final List<FavouriteWallEntity> items = <FavouriteWallEntity>[
      prismFav('pinned_grace', author: 'Grace').withPinnedAt(DateTime.utc(2026)),
      prismFav('pinned_ada', author: 'Ada').withPinnedAt(DateTime.utc(2026, 2)),
      prismFav('free_ada', author: 'Ada', createdAt: DateTime.utc(2025)),
      prismFav('free_linus', author: 'Linus', createdAt: DateTime.utc(2025)),
    ];

    final List<FavouriteWallEntity> view = applyFavouritesView(items, query: ' ada ');

    expect(_ids(view), <String>['pinned_ada', 'free_ada']);
  });

  group('stored pinnedAt', () {
    Map<String, dynamic> doc({Object? pinnedAt, bool withPinnedKey = false}) => <String, dynamic>{
      'id': 'w1',
      'provider': 'prism',
      'url': 'https://example.com/w1.jpg',
      'thumb': 'https://example.com/w1-thumb.jpg',
      if (withPinnedKey) 'pinnedAt': pinnedAt,
    };

    test('an old doc without pinnedAt maps to an unpinned wall', () {
      final FavouriteWallEntity wall = mapFavouriteWallDoc(FavouriteWallDocDto.fromJson(doc()), 'w1');

      expect(wall.pinnedAt, isNull);
      expect(wall.pinned, isFalse);
    });

    test('a DateTime pinnedAt maps to that DateTime', () {
      final DateTime stamp = DateTime.utc(2026, 10, 29, 9, 30);

      final FavouriteWallEntity wall = mapFavouriteWallDoc(
        FavouriteWallDocDto.fromJson(doc(pinnedAt: stamp, withPinnedKey: true)),
        'w1',
      );

      expect(wall.pinnedAt, stamp);
      expect(wall.pinned, isTrue);
    });

    test('a Firestore Timestamp pinnedAt maps to its DateTime', () {
      final DateTime stamp = DateTime.utc(2026, 10, 29, 9, 30);

      final FavouriteWallEntity wall = mapFavouriteWallDoc(
        FavouriteWallDocDto.fromJson(doc(pinnedAt: Timestamp.fromDate(stamp), withPinnedKey: true)),
        'w1',
      );

      // Timestamp.toDate() returns local time, so compare the instant, not the zone.
      expect(wall.pinnedAt!.isAtSameMomentAs(stamp), isTrue);
    });
  });

  group('favouriteWallToDoc', () {
    test('an unpinned wall writes no pinnedAt key', () {
      final Map<String, dynamic> doc = favouriteWallToDoc(prismFav('w1', favouritedAt: DateTime.utc(2026)));

      expect(doc.containsKey('pinnedAt'), isFalse);
    });

    test('a pinned wall writes pinnedAt as the DateTime, and the doc maps back to the same pin', () {
      final DateTime stamp = DateTime.utc(2026, 10, 29, 9, 30);
      final FavouriteWallEntity pinned = prismFav('w1', favouritedAt: DateTime.utc(2026)).withPinnedAt(stamp);

      final Map<String, dynamic> doc = favouriteWallToDoc(pinned);

      expect(doc['pinnedAt'], stamp);
      final FavouriteWallEntity roundTrip = mapFavouriteWallDoc(FavouriteWallDocDto.fromJson(doc), 'w1');
      expect(roundTrip.pinnedAt, stamp);
      expect(roundTrip.favouritedAt, DateTime.utc(2026));
    });
  });
}
