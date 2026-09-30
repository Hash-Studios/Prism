import 'package:Prism/core/persistence/local_store.dart';
import 'package:Prism/core/persistence/persistence_keys.dart';
import 'package:injectable/injectable.dart';

@lazySingleton
class FavoritesLocalDataSource {
  FavoritesLocalDataSource(this._store);

  final LocalStore _store;

  static const String defaultUserScope = '__global';

  String _scope(String userId) => userId.trim().isEmpty ? defaultUserScope : userId.trim();

  Set<String> _wallSet(String scope) {
    final raw = _store.get(PersistenceKeys.favoritesWallSet(scope));
    if (raw is! List) return <String>{};
    return Set<String>.from(raw.cast<String>());
  }

  Future<void> _saveWallSet(String scope, Set<String> ids) {
    return _store.set(PersistenceKeys.favoritesWallSet(scope), ids.toList(growable: false));
  }

  bool isWallFavourite(String userId, String itemId) {
    return _wallSet(_scope(userId)).contains(itemId);
  }

  Future<void> setWallFavourite(String userId, String itemId, bool value) async {
    final scope = _scope(userId);
    final ids = _wallSet(scope);
    if (value) {
      ids.add(itemId);
    } else {
      ids.remove(itemId);
    }
    await _saveWallSet(scope, ids);
  }

  Future<void> replaceWallFavourites(String userId, Iterable<String> itemIds) {
    return _saveWallSet(_scope(userId), itemIds.where((id) => id.isNotEmpty).toSet());
  }

  Future<void> setSeeded(String userId, bool value) async {
    final scope = _scope(userId);
    final key = PersistenceKeys.favoritesSeeded(scope);
    if (!value) {
      await _store.delete(key);
      return;
    }
    await _store.set(key, true);
  }

  bool isSeeded(String userId) {
    final scope = _scope(userId);
    return (_store.get(PersistenceKeys.favoritesSeeded(scope)) as bool?) ?? false;
  }
}
