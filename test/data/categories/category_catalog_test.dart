import 'package:Prism/core/constants/app_constants.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/data/categories/categories.dart';
import 'package:Prism/data/categories/category_catalog.dart';
import 'package:Prism/data/categories/category_definition.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockRemoteConfig extends Mock implements FirebaseRemoteConfig {}

_MockRemoteConfig _remoteConfig(String value) {
  final config = _MockRemoteConfig();
  when(() => config.getString(categoriesRemoteConfigKey)).thenReturn(value);
  return config;
}

void main() {
  tearDown(CategoryCatalog.debugReset);

  group('decode', () {
    test('keeps the remote order and fills the optional fields', () {
      final categories = CategoryCatalog.decode('''
[
  {"name":" Diwali ","source":"pexels","imageUrl":"https://img/diwali.jpg"},
  {"name":"Nature","source":"wallhaven","imageUrl":"https://img/a.jpg","secondaryImageUrl":"https://img/b.jpg"}
]
''')!;

      expect(categories.map((category) => category.name), <String>['Diwali', 'Nature']);
      expect(categories.first.source, WallpaperSource.pexels);
      expect(categories.first.searchType, CategorySearchType.search);
      expect(categories.first.secondaryImageUrl, 'https://img/diwali.jpg');
      expect(categories.first.hasPrismWalls, isFalse);
      expect(categories.last.source, WallpaperSource.wallhaven);
      expect(categories.last.secondaryImageUrl, 'https://img/b.jpg');
      expect(categories.last.hasPrismWalls, isTrue);
    });

    test('skips entries the feed cannot show', () {
      final categories = CategoryCatalog.decode('''
[
  "Diwali",
  {"source":"pexels","imageUrl":"https://img/x.jpg"},
  {"name":"No image","source":"pexels"},
  {"name":"Prism","source":"prism","imageUrl":"https://img/x.jpg"},
  {"name":"Unknown","source":"unsplash","imageUrl":"https://img/x.jpg"},
  {"name":42,"source":"pexels","imageUrl":"https://img/x.jpg"},
  {"name":"Map image","source":"pexels","imageUrl":{"url":"https://img/x.jpg"}},
  {"name":"Halloween","source":"wallhaven","imageUrl":"https://img/h.jpg","secondaryImageUrl":7},
  {"name":"halloween","source":"pexels","imageUrl":"https://img/h2.jpg"}
]
''')!;

      expect(categories.map((category) => category.name), <String>['Halloween']);
      expect(categories.single.source, WallpaperSource.wallhaven);
      expect(categories.single.secondaryImageUrl, 'https://img/h.jpg');
    });

    test('returns null when nothing is usable', () {
      expect(CategoryCatalog.decode(''), isNull);
      expect(CategoryCatalog.decode('not json'), isNull);
      expect(CategoryCatalog.decode('{"name":"Diwali"}'), isNull);
      expect(CategoryCatalog.decode('[]'), isNull);
      expect(CategoryCatalog.decode('[{"name":"Diwali","source":"pexels"}]'), isNull);
    });
  });

  group('resolve', () {
    test('uses the built-in list until Remote Config is ready', () {
      expect(CategoryCatalog.resolve(null), same(categoryDefinitions));

      final categories = CategoryCatalog.resolve(
        _remoteConfig('[{"name":"Diwali","source":"pexels","imageUrl":"https://img/d.jpg"}]'),
      );

      expect(categories.map((category) => category.name), <String>['Diwali']);
    });

    test('keeps the first remote list for the session', () {
      final first = _remoteConfig('[{"name":"Diwali","source":"pexels","imageUrl":"https://img/d.jpg"}]');
      final later = _remoteConfig('[{"name":"Halloween","source":"pexels","imageUrl":"https://img/h.jpg"}]');

      CategoryCatalog.resolve(first);

      expect(CategoryCatalog.resolve(later).map((category) => category.name), <String>['Diwali']);
      expect(CategoryCatalog.current.map((category) => category.name), <String>['Diwali']);
      verifyNever(() => later.getString(any()));
    });

    test('falls back to the built-in list when the remote value is empty or broken', () {
      expect(CategoryCatalog.resolve(_remoteConfig('')), same(categoryDefinitions));
      CategoryCatalog.debugReset();
      expect(CategoryCatalog.resolve(_remoteConfig('[{"name":"x"}]')), same(categoryDefinitions));
    });
  });
}
