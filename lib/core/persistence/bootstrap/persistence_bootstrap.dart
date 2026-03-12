import 'package:Prism/core/persistence/local_store.dart';
import 'package:Prism/core/persistence/local_store_backend.dart';
import 'package:Prism/core/persistence/persistence_runtime.dart';
import 'package:Prism/core/persistence/store_adapters/shared_prefs_store_adapter.dart';
import 'package:Prism/env/env.dart';

class PersistenceBootstrap {
  PersistenceBootstrap._();

  static Future<void> initialize() async {
    final LocalStoreBackend backend = LocalStoreBackendX.fromDefine(Env.localPersistenceBackend);
    
    final LocalStore store;
    switch (backend) {
      case LocalStoreBackend.sharedPrefs:
        store = SharedPrefsStoreAdapter();
    }

    await store.init();
    
    PersistenceRuntime.initialize(store: store, backend: backend);
  }
}
