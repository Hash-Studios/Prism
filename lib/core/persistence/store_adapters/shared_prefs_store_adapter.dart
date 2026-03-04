import 'package:Prism/core/persistence/local_store.dart';
import 'package:Prism/core/persistence/store_value_codec.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SharedPrefsStoreAdapter implements LocalStore {
  SharedPrefsStoreAdapter();

  SharedPreferences? _prefs;

  SharedPreferences get _requirePrefs {
    final resolved = _prefs;
    if (resolved == null) {
      throw StateError('SharedPrefsStoreAdapter used before init().');
    }
    return resolved;
  }

  @override
  bool get isReady => _prefs != null;

  @override
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  @override
  Object? get(String key) {
    final raw = _requirePrefs.getString(key);
    if (raw == null) {
      return null;
    }
    return StoreValueCodec.decode(raw);
  }

  @override
  Future<void> set(String key, Object? value) {
    return _requirePrefs.setString(key, StoreValueCodec.encode(value));
  }

  @override
  Future<void> delete(String key) {
    return _requirePrefs.remove(key);
  }

  @override
  Future<List<String>> keys() async {
    return _requirePrefs.getKeys().toList(growable: false);
  }

  @override
  Future<void> clearPrefix(String prefix) async {
    final keys = _requirePrefs.getKeys().where((key) => key.startsWith(prefix)).toList(growable: false);
    for (final key in keys) {
      await _requirePrefs.remove(key);
    }
  }

  @override
  Future<void> clearAll() {
    return _requirePrefs.clear();
  }
}
