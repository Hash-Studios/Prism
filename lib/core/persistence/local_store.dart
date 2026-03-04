abstract class LocalStore {
  Future<void> init();

  bool get isReady;

  Object? get(String key);

  Future<void> set(String key, Object? value);

  Future<void> delete(String key);

  Future<List<String>> keys();

  Future<void> clearPrefix(String prefix);

  Future<void> clearAll();
}
