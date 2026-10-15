import 'package:Prism/core/persistence/bootstrap/persistence_bootstrap.dart';
import 'package:Prism/core/persistence/persistence_keys.dart';
import 'package:Prism/core/persistence/persistence_runtime.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/in_memory_local_store.dart';

class _ThrowingGetStore extends InMemoryLocalStore {
  @override
  Object? get(String key) => throw const FormatException('corrupt value');
}

void main() {
  test('a migration that throws does not stop initialize, and the store is still published', () async {
    final store = _ThrowingGetStore();

    await PersistenceBootstrap.initialize(store: store);

    expect(PersistenceRuntime.store, same(store));
  });

  test('a healthy store is migrated and published', () async {
    final store = InMemoryLocalStore();

    await PersistenceBootstrap.initialize(store: store);

    expect(PersistenceRuntime.store, same(store));
    expect(store.get(PersistenceKeys.schemaVersion), 4);
  });
}
