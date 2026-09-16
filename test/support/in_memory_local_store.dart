import 'package:Prism/core/persistence/local_store.dart';

class InMemoryLocalStore implements LocalStore {
  final Map<String, Object?> data = <String, Object?>{};
  bool ready = true;

  @override
  Future<void> clearAll() async {
    data.clear();
  }

  @override
  Future<void> clearPrefix(String prefix) async {
    data.removeWhere((key, value) => key.startsWith(prefix));
  }

  @override
  Future<void> delete(String key) async {
    data.remove(key);
  }

  @override
  Object? get(String key) => data[key];

  @override
  Future<void> init() async {}

  @override
  bool get isReady => ready;

  @override
  Future<List<String>> keys() async => data.keys.toList(growable: false);

  @override
  Future<void> set(String key, Object? value) async {
    data[key] = value;
  }
}
