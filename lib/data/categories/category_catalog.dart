import 'dart:convert';

import 'package:Prism/core/constants/app_constants.dart';
import 'package:Prism/core/startup/firebase_init.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/data/categories/categories.dart';
import 'package:Prism/data/categories/category_definition.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';

/// The browse categories. Remote Config [categoriesRemoteConfigKey] can replace the built-in list, so a new
/// category reaches users without an app update.
class CategoryCatalog {
  const CategoryCatalog._();

  static List<CategoryDefinition>? _session;

  /// The remote list when it has a valid entry, else [categoryDefinitions].
  static List<CategoryDefinition> get current => resolve(FirebaseInit.remoteConfigIfInitialized);

  /// The first list read with Remote Config ready stays for the session, so the Collections tab, search and an open
  /// category screen show the same categories. A value fetched later shows on the next launch.
  @visibleForTesting
  static List<CategoryDefinition> resolve(FirebaseRemoteConfig? remoteConfig) {
    final List<CategoryDefinition>? session = _session;
    if (session != null) return session;
    if (remoteConfig == null) return categoryDefinitions;
    return _session = decode(remoteConfig.getString(categoriesRemoteConfigKey)) ?? categoryDefinitions;
  }

  /// Reads `[{"name", "source": "pexels" | "wallhaven", "imageUrl", "secondaryImageUrl"?}]` in display order. The
  /// name is also the search query. Entries without a text name or image, with another source, or with a name already
  /// listed are skipped. Null when no entry is left.
  @visibleForTesting
  static List<CategoryDefinition>? decode(String raw) {
    final Object? decoded;
    try {
      decoded = json.decode(raw);
    } on FormatException {
      return null;
    }
    if (decoded is! List) return null;
    final Set<String> names = <String>{};
    final List<CategoryDefinition> categories = <CategoryDefinition>[];
    for (final Object? item in decoded) {
      if (item is! Map) continue;
      final Object? rawName = item['name'];
      final Object? rawImageUrl = item['imageUrl'];
      final Object? rawSecondaryImageUrl = item['secondaryImageUrl'];
      final String name = rawName is String ? rawName.trim() : '';
      final WallpaperSource source = WallpaperSourceX.fromWire(item['source']);
      final String imageUrl = rawImageUrl is String ? rawImageUrl.trim() : '';
      final String secondaryImageUrl = rawSecondaryImageUrl is String ? rawSecondaryImageUrl.trim() : '';
      if (name.isEmpty || imageUrl.isEmpty) continue;
      if (source != WallpaperSource.pexels && source != WallpaperSource.wallhaven) continue;
      if (!names.add(name.toLowerCase())) continue;
      categories.add(
        CategoryDefinition(
          name: name,
          source: source,
          searchType: CategorySearchType.search,
          imageUrl: imageUrl,
          secondaryImageUrl: secondaryImageUrl.isEmpty ? imageUrl : secondaryImageUrl,
        ),
      );
    }
    return categories.isEmpty ? null : categories;
  }

  @visibleForTesting
  static void debugReset() => _session = null;
}
