import 'package:Prism/core/persistence/local_store.dart';
import 'package:Prism/core/persistence/migrations/persistence_migration_runner.dart';
import 'package:Prism/core/persistence/persistence_runtime.dart';
import 'package:Prism/core/persistence/store_adapters/shared_prefs_store_adapter.dart';
import 'package:Prism/logger/logger.dart';
import 'package:flutter/foundation.dart';

class PersistenceBootstrap {
  PersistenceBootstrap._();

  static Future<void> initialize({@visibleForTesting LocalStore? store}) async {
    final LocalStore resolved = store ?? SharedPrefsStoreAdapter();
    await resolved.init();
    // A migration that throws on odd stored data must not stop startup. It would throw again on every launch.
    try {
      await PersistenceMigrationRunner.run(resolved);
    } catch (error, stackTrace) {
      logger.e(
        'Persistence migration failed; starting with the stored data as it is.',
        error: error,
        stackTrace: stackTrace,
      );
    }

    PersistenceRuntime.store = resolved;
  }
}
