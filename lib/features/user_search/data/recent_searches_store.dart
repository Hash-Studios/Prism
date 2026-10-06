import 'dart:convert';

import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/persistence/persistence_keys.dart';

/// The last [maxItems] wallpaper searches, newest first, kept in local settings.
class RecentSearchesStore {
  RecentSearchesStore(this._settings);

  static const int maxItems = 10;

  final SettingsLocalDataSource _settings;

  List<String> read() {
    final String raw = _settings.get<String>(PersistenceKeys.recentSearches, defaultValue: '');
    if (raw.isEmpty) {
      return const <String>[];
    }
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded.whereType<String>().take(maxItems).toList(growable: false);
      }
    } on FormatException {
      return const <String>[];
    }
    return const <String>[];
  }

  /// Puts [query] first. A repeat of an older query, ignoring case, moves it instead of adding a copy.
  Future<List<String>> add(String query) async {
    final String trimmed = query.trim();
    if (trimmed.isEmpty) {
      return read();
    }
    final List<String> next = <String>[
      trimmed,
      ...read().where((item) => item.toLowerCase() != trimmed.toLowerCase()),
    ].take(maxItems).toList(growable: false);
    await _settings.set(PersistenceKeys.recentSearches, jsonEncode(next));
    return next;
  }

  Future<void> clear() => _settings.delete(PersistenceKeys.recentSearches);
}
