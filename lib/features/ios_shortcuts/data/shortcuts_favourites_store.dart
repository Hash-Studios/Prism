import 'dart:convert';

import 'package:Prism/core/persistence/persistence_keys.dart';
import 'package:Prism/features/favourite_walls/domain/entities/favourite_wall_entity.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Writes the user's favourites as a raw JSON string, so the iOS "Get Prism Wallpaper" intent can read it
/// from UserDefaults without a running Flutter engine.
class ShortcutsFavouritesStore {
  const ShortcutsFavouritesStore._();

  static const int maxItems = 200;

  /// A JSON array of `{"id", "url"}`, newest first, at most [maxItems]. Walls without an id or https URL are left out.
  static String encode(Iterable<FavouriteWallEntity> items) {
    final List<FavouriteWallEntity> sorted = items.toList()..sort(compareByCreatedAtDesc);
    final Set<String> seen = <String>{};
    final List<Map<String, String>> entries = <Map<String, String>>[];
    for (final FavouriteWallEntity item in sorted) {
      final String id = item.id.trim();
      final String url = item.fullUrl.trim();
      if (id.isEmpty || !url.startsWith('https://') || !seen.add(id)) continue;
      entries.add(<String, String>{'id': id, 'url': url});
      if (entries.length == maxItems) break;
    }
    return jsonEncode(entries);
  }

  static Future<void> save(Iterable<FavouriteWallEntity> items) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(PersistenceKeys.shortcutsFavourites, encode(items));
  }

  static Future<void> clear() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(PersistenceKeys.shortcutsFavourites, '[]');
  }
}
