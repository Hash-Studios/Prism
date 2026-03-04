import 'package:Prism/core/persistence/local_store.dart';
import 'package:Prism/core/persistence/local_store_backend.dart';

class PersistenceRuntime {
  PersistenceRuntime._();

  static LocalStore? _store;
  static LocalStoreBackend? _backend;

  static LocalStore get store {
    final resolved = _store;
    if (resolved == null) {
      throw StateError('PersistenceRuntime.store accessed before initialization.');
    }
    return resolved;
  }

  static LocalStoreBackend get backend {
    final resolved = _backend;
    if (resolved == null) {
      throw StateError('PersistenceRuntime.backend accessed before initialization.');
    }
    return resolved;
  }

  static bool get isInitialized => _store != null;

  static void initialize({required LocalStore store, required LocalStoreBackend backend}) {
    _store = store;
    _backend = backend;
  }
}
