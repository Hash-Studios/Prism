import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/features/favourite_walls/domain/entities/favourite_wall_entity.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fav_fixtures.dart';

void main() {
  final items = <FavouriteWallEntity>[
    prismFav('p_old', author: 'Ada', category: 'Nature', createdAt: DateTime.utc(2024)),
    wallhavenFav('w_new', category: 'Abstract', createdAt: DateTime.utc(2025, 6)),
    pexelsFav('x_mid', author: 'Grace Hopper', category: 'Space', createdAt: DateTime.utc(2024, 9)),
    legacyFav('l_undated', author: 'Old Timer'),
  ];

  List<String> ids(List<FavouriteWallEntity> walls) => walls.map((wall) => wall.id).toList();

  test('recently added sorts newest first and keeps undated entries last', () {
    expect(ids(applyFavouritesView(items)), <String>['w_new', 'x_mid', 'p_old', 'l_undated']);
  });

  test('wallhaven and pexels favourites use their stored date', () {
    expect(wallhavenFav('w', createdAt: DateTime.utc(2025)).createdAt, DateTime.utc(2025));
    expect(pexelsFav('x', createdAt: DateTime.utc(2025)).createdAt, DateTime.utc(2025));
  });

  test('oldest sorts oldest first and keeps undated entries last', () {
    expect(ids(applyFavouritesView(items, sort: FavouriteSort.oldest)), <String>[
      'p_old',
      'x_mid',
      'w_new',
      'l_undated',
    ]);
  });

  test('source sort groups by source and then newest first', () {
    final more = <FavouriteWallEntity>[...items, prismFav('p_new', createdAt: DateTime.utc(2025))];
    expect(ids(applyFavouritesView(more, sort: FavouriteSort.source)), <String>[
      'p_new',
      'p_old',
      'w_new',
      'x_mid',
      'l_undated',
    ]);
  });

  test('source filter keeps only that source', () {
    expect(ids(applyFavouritesView(items, source: WallpaperSource.pexels)), <String>['x_mid']);
  });

  test('search matches author or category, ignoring case and spaces', () {
    expect(ids(applyFavouritesView(items, query: '  GRACE ')), <String>['x_mid']);
    expect(ids(applyFavouritesView(items, query: 'abstract')), <String>['w_new']);
    expect(ids(applyFavouritesView(items, query: 'old timer')), <String>['l_undated']);
    expect(applyFavouritesView(items, query: 'nothing matches'), isEmpty);
  });

  test('filter and search combine', () {
    expect(applyFavouritesView(items, source: WallpaperSource.prism, query: 'grace'), isEmpty);
    expect(ids(applyFavouritesView(items, source: WallpaperSource.prism, query: 'nature')), <String>['p_old']);
  });
}
