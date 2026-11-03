import 'dart:io';

import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/data/categories/categories.dart';
import 'package:Prism/data/categories/category_cover.dart';
import 'package:Prism/data/categories/category_definition.dart';
import 'package:Prism/l10n/generated/app_localizations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

CategoryDefinition _category(String name) => categoryDefinitions.singleWhere((category) => category.name == name);

void main() {
  test('lists the built-in categories in display order', () {
    expect(categoryDefinitions.map((category) => category.name), <String>[
      'AI Art',
      'Aesthetic',
      'Pastel',
      'Cyberpunk',
      'Gaming',
      '3D Render',
      'Desktop',
      'Gradient',
      'Minimal',
      'Dark',
      'Nature',
      'Landscape',
      'Space',
      'Anime',
      'Neon',
      'Abstract',
      'Architecture',
      'Ocean',
      'Forest',
      'Galaxy',
      'Vintage',
      'Flowers',
      'Cars',
      'AMOLED',
    ]);
  });

  test('searches Pexels with the query, or the name when there is no query', () {
    final pastel = _category('Pastel');
    expect(pastel.source, WallpaperSource.pexels);
    expect(pastel.searchQuery, 'pastel aesthetic');

    final gaming = _category('Gaming');
    expect(gaming.source, WallpaperSource.pexels);
    expect(gaming.searchQuery, 'gaming wallpaper');

    final render = _category('3D Render');
    expect(render.source, WallpaperSource.pexels);
    expect(render.searchQuery, '3d render abstract');

    final nature = _category('Nature');
    expect(nature.query, isNull);
    expect(nature.searchQuery, 'Nature');
  });

  test('Desktop lists the Prism walls that have a desktop version', () {
    final desktop = _category('Desktop');
    expect(desktop.source, WallpaperSource.prism);
    expect(desktop.searchType, CategorySearchType.desktop);
    expect(desktop.hasPrismWalls, isFalse);
  });

  test('only the categories the classifier writes have Prism walls', () {
    expect(_category('Pastel').hasPrismWalls, isTrue);
    expect(_category('Gaming').hasPrismWalls, isTrue);
    expect(prismClassifierCategories, isNot(contains('Desktop')));
  });

  test('every built-in Pexels cover has a bundled asset that exists', () {
    final pexelsCategories = categoryDefinitions.where(
      (category) => category.imageUrl.startsWith('https://images.pexels.com/'),
    );
    expect(pexelsCategories, isNotEmpty);

    for (final category in pexelsCategories) {
      final asset = bundledCoverAsset(category.imageUrl);
      expect(asset, isNotNull, reason: category.name);
      expect(File(asset!).existsSync(), isTrue, reason: category.name);
    }
  });

  test('categoryDisplayName uses the localized names', () {
    final AppLocalizations en = lookupAppLocalizations(const Locale('en'));
    expect(categoryDisplayName('Pastel', en), 'Pastel');
    expect(categoryDisplayName('Desktop', en), 'Desktop');
    expect(categoryDisplayName('Gaming', en), 'Gaming');

    final AppLocalizations de = lookupAppLocalizations(const Locale('de'));
    expect(categoryDisplayName('Pastel', de), 'Pastell');
  });

  test('a category needs at least 12 walls to be listed', () {
    expect(minimumCategoryWalls, 12);
  });
}
