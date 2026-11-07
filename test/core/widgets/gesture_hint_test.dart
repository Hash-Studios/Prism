import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/persistence/persistence_keys.dart';
import 'package:Prism/core/persistence/local_store.dart';
import 'package:Prism/core/widgets/gesture_hint.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _DelayedStore implements LocalStore {
  bool ready = false;
  final Map<String, Object?> values = <String, Object?>{};
  @override
  Future<void> init() async => ready = true;
  @override
  bool get isReady => ready;
  @override
  Object? get(String key) => values[key];
  @override
  Future<void> set(String key, Object? value) async => values[key] = value;
  @override
  Future<void> delete(String key) async => values.remove(key);
  @override
  Future<List<String>> keys() async => values.keys.toList();
  @override
  Future<void> clearPrefix(String prefix) async => values.removeWhere((key, _) => key.startsWith(prefix));
  @override
  Future<void> clearAll() async => values.clear();
}

void main() {
  tearDown(() {
    GestureHints.resetForTest();
    getIt.reset();
  });

  test('hydrates a hint seen before settings open once persisted settings are ready', () async {
    final _DelayedStore store = _DelayedStore();
    final SettingsLocalDataSource settings = SettingsLocalDataSource(store);
    getIt.registerSingleton<SettingsLocalDataSource>(settings);

    expect(GestureHints.seen(GestureHint.holdToSave).value, isTrue, reason: 'hide hints until settings are ready');
    store.values[PersistenceKeys.settings('gestureHintSeen.holdToSave')] = false;
    await store.init();

    final ValueNotifier<bool> notifier = GestureHints.seen(GestureHint.holdToSave);
    await Future<void>.delayed(Duration.zero);
    expect(notifier.value, isFalse);
  });

  test('a gesture in the hydration frame wins over an old unseen value', () async {
    final _DelayedStore store = _DelayedStore()..ready = true;
    store.values[PersistenceKeys.settings('gestureHintSeen.holdToSave')] = false;
    getIt.registerSingleton<SettingsLocalDataSource>(SettingsLocalDataSource(store));

    GestureHints.seen(GestureHint.holdToSave);
    GestureHints.markSeen(GestureHint.holdToSave);
    await Future<void>.delayed(Duration.zero);

    expect(GestureHints.seen(GestureHint.holdToSave).value, isTrue);
    expect(store.values[PersistenceKeys.settings('gestureHintSeen.holdToSave')], isTrue);
  });

  test('persists a gesture performed before settings are registered', () async {
    GestureHints.markSeen(GestureHint.holdToSave);
    final _DelayedStore store = _DelayedStore();
    final SettingsLocalDataSource settings = SettingsLocalDataSource(store);
    getIt.registerSingleton<SettingsLocalDataSource>(settings);
    await store.init();

    GestureHints.seen(GestureHint.holdToSave);
    await Future<void>.delayed(Duration.zero);
    expect(store.values[PersistenceKeys.settings('gestureHintSeen.holdToSave')], isTrue);
  });
}
