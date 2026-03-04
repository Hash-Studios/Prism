import 'package:Prism/core/persistence/local_store.dart';
import 'package:Prism/core/persistence/persistence_keys.dart';
import 'package:Prism/core/persistence/persistence_runtime.dart';

class PrefsCompat {
  PrefsCompat(this._store);

  factory PrefsCompat.fromRuntime() => PrefsCompat(PersistenceRuntime.store);

  final LocalStore _store;

  bool get isOpen => _store.isReady;

  Object? get(String key, {Object? defaultValue}) {
    final Object? value = _store.get(PersistenceKeys.settings(key));
    return value ?? defaultValue;
  }

  Future<void> put(String key, Object? value) {
    return _store.set(PersistenceKeys.settings(key), value);
  }

  Future<void> delete(String key) {
    return _store.delete(PersistenceKeys.settings(key));
  }
}
