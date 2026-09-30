import 'package:Prism/core/persistence/local_store.dart';

class PersistenceRuntime {
  PersistenceRuntime._();

  static LocalStore? _store;

  static LocalStore get store {
    final resolved = _store;
    if (resolved == null) {
      throw StateError('PersistenceRuntime.store accessed before initialization.');
    }
    return resolved;
  }

  static bool get isInitialized => _store != null;

  static set store(LocalStore store) => _store = store;
}
