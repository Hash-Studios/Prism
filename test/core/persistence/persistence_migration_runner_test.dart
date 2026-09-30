import 'package:Prism/core/persistence/migrations/persistence_migration_runner.dart';
import 'package:Prism/core/persistence/persistence_keys.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/in_memory_local_store.dart';

void main() {
  test('older schemas migrate wallpaper favorites before clearing setup favorites', () async {
    final store = InMemoryLocalStore()
      ..data.addAll(<String, Object?>{
        PersistenceKeys.schemaVersion: 2,
        '${PersistenceKeys.favoritesWallPrefix}user-1.legacy-wall': true,
        PersistenceKeys.favoritesWallSet('user-1'): <String>['existing-wall'],
        '${PersistenceKeys.favoritesSetupPrefix}user-1.setup-1': true,
      });

    await PersistenceMigrationRunner.run(store);

    expect(store.get(PersistenceKeys.favoritesWallSet('user-1')), <String>['existing-wall', 'legacy-wall']);
    expect(store.data.keys.where((key) => key.startsWith(PersistenceKeys.favoritesSetupPrefix)), isEmpty);
    expect(store.get(PersistenceKeys.schemaVersion), 4);
  });

  test('v4 clears setup favorites for v3 installs and preserves wallpaper favorites on repeat', () async {
    final store = InMemoryLocalStore()
      ..data.addAll(<String, Object?>{
        PersistenceKeys.schemaVersion: 3,
        '${PersistenceKeys.favoritesSetupPrefix}user-1.setup-1': true,
        '${PersistenceKeys.favoritesSetupPrefix}__set.user-1': <String>['setup-2'],
        PersistenceKeys.favoritesWallSet('user-1'): <String>['wall-1', 'wall-2'],
      });

    await PersistenceMigrationRunner.run(store);
    await PersistenceMigrationRunner.run(store);

    expect(store.data.keys.where((key) => key.startsWith(PersistenceKeys.favoritesSetupPrefix)), isEmpty);
    expect(store.get(PersistenceKeys.favoritesWallSet('user-1')), <String>['wall-1', 'wall-2']);
    expect(store.get(PersistenceKeys.schemaVersion), 4);
  });
}
