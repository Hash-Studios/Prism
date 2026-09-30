import 'package:Prism/core/persistence/local_store.dart';
import 'package:Prism/core/persistence/migrations/persistence_migration_runner.dart';
import 'package:Prism/core/persistence/persistence_runtime.dart';
import 'package:Prism/core/persistence/store_adapters/shared_prefs_store_adapter.dart';

class PersistenceBootstrap {
  PersistenceBootstrap._();

  static Future<void> initialize() async {
    final LocalStore store = SharedPrefsStoreAdapter();
    await store.init();
    await PersistenceMigrationRunner.run(store);

    PersistenceRuntime.store = store;
  }
}
