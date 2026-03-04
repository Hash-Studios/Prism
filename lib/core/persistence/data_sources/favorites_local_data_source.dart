import 'package:Prism/core/persistence/local_store.dart';
import 'package:Prism/core/persistence/persistence_keys.dart';
import 'package:injectable/injectable.dart';

@lazySingleton
class FavoritesLocalDataSource {
  FavoritesLocalDataSource(this._store);

  final LocalStore _store;

  static const String defaultUserScope = '__global';

  String _scope(String userId) => userId.trim().isEmpty ? defaultUserScope : userId.trim();

  bool isWallFavourite(String userId, String itemId) {
    final scope = _scope(userId);
    return (_store.get(PersistenceKeys.favoriteWall(scope, itemId)) as bool?) ?? false;
  }

  bool isSetupFavourite(String userId, String itemId) {
    final scope = _scope(userId);
    return (_store.get(PersistenceKeys.favoriteSetup(scope, itemId)) as bool?) ?? false;
  }

  bool isAnyFavourite(String userId, String itemId) {
    return isWallFavourite(userId, itemId) || isSetupFavourite(userId, itemId);
  }

  Future<void> setWallFavourite(String userId, String itemId, bool value) async {
    final scope = _scope(userId);
    final key = PersistenceKeys.favoriteWall(scope, itemId);
    if (!value) {
      await _store.delete(key);
      return;
    }
    await _store.set(key, true);
  }

  Future<void> setSetupFavourite(String userId, String itemId, bool value) async {
    final scope = _scope(userId);
    final key = PersistenceKeys.favoriteSetup(scope, itemId);
    if (!value) {
      await _store.delete(key);
      return;
    }
    await _store.set(key, true);
  }

  Future<void> clearWallFavourites(String userId, {List<String>? onlyIds}) async {
    final scope = _scope(userId);
    if (onlyIds != null && onlyIds.isNotEmpty) {
      for (final id in onlyIds) {
        await _store.delete(PersistenceKeys.favoriteWall(scope, id));
      }
      return;
    }
    await _store.clearPrefix('${PersistenceKeys.favoritesWallPrefix}$scope.');
  }

  Future<void> clearSetupFavourites(String userId, {List<String>? onlyIds}) async {
    final scope = _scope(userId);
    if (onlyIds != null && onlyIds.isNotEmpty) {
      for (final id in onlyIds) {
        await _store.delete(PersistenceKeys.favoriteSetup(scope, id));
      }
      return;
    }
    await _store.clearPrefix('${PersistenceKeys.favoritesSetupPrefix}$scope.');
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
