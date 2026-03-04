import 'package:Prism/core/persistence/local_store.dart';
import 'package:Prism/core/persistence/store_value_codec.dart';
import 'package:hive_io/hive_io.dart';

class HiveStoreAdapter implements LocalStore {
  HiveStoreAdapter({this.boxName = 'local_store_v2'});

  final String boxName;
  Box<String>? _box;

  Box<String> get _requireBox {
    final resolved = _box;
    if (resolved == null) {
      throw StateError('HiveStoreAdapter used before init().');
    }
    return resolved;
  }

  @override
  bool get isReady => _box?.isOpen == true;

  @override
  Future<void> init() async {
    final existing = Hive.isBoxOpen(boxName) ? Hive.box<String>(boxName) : await Hive.openBox<String>(boxName);
    _box = existing;
  }

  @override
  Object? get(String key) {
    final String? raw = _requireBox.get(key);
    if (raw == null) {
      return null;
    }
    return StoreValueCodec.decode(raw);
  }

  @override
  Future<void> set(String key, Object? value) async {
    await _requireBox.put(key, StoreValueCodec.encode(value));
  }

  @override
  Future<void> delete(String key) async {
    await _requireBox.delete(key);
  }

  @override
  Future<List<String>> keys() async {
    return _requireBox.keys.whereType<String>().toList(growable: false);
  }

  @override
  Future<void> clearPrefix(String prefix) async {
    final targetKeys = _requireBox.keys.whereType<String>().where((key) => key.startsWith(prefix)).toList();
    if (targetKeys.isEmpty) {
      return;
    }
    await _requireBox.deleteAll(targetKeys);
  }

  @override
  Future<void> clearAll() async {
    await _requireBox.clear();
  }
}
