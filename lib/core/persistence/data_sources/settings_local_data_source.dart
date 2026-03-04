import 'package:Prism/core/persistence/local_store.dart';
import 'package:Prism/core/persistence/persistence_keys.dart';
import 'package:injectable/injectable.dart';

@lazySingleton
class SettingsLocalDataSource {
  SettingsLocalDataSource(this._store);

  final LocalStore _store;

  bool get isOpen => _store.isReady;

  T get<T>(String key, {T? defaultValue}) {
    final Object? value = _store.get(PersistenceKeys.settings(key));
    if (value == null) {
      if (defaultValue != null) {
        return defaultValue;
      }
      throw StateError('Missing settings value for "$key" and no default provided for type $T.');
    }
    if (value is T) {
      return value as T;
    }
    if (defaultValue != null) {
      return defaultValue;
    }
    throw StateError('Settings key "$key" has type ${value.runtimeType}, expected $T.');
  }

  Future<void> set(String key, Object? value) {
    return _store.set(PersistenceKeys.settings(key), value);
  }

  Future<void> delete(String key) {
    return _store.delete(PersistenceKeys.settings(key));
  }

  Future<void> clearAllSettings() {
    return _store.clearPrefix(PersistenceKeys.settingsPrefix);
  }
}
