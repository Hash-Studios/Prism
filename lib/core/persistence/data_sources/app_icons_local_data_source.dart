import 'package:Prism/core/persistence/persistence_keys.dart';
import 'package:Prism/core/persistence/store_adapters/lazy_file_cache.dart';
import 'package:injectable/injectable.dart';

@lazySingleton
class AppIconsLocalDataSource {
  AppIconsLocalDataSource();

  final LazyFileCache _cache = LazyFileCache('icons_cache');

  Future<Map<String, dynamic>> readIconsPayload() async {
    final raw = await _cache.get(PersistenceKeys.cacheIconsAppsPayload);
    if (raw is Map<String, dynamic>) {
      return raw;
    }
    if (raw is Map) {
      return raw.map<String, dynamic>((key, value) => MapEntry(key.toString(), value));
    }
    return <String, dynamic>{};
  }

  Future<void> writeIconsPayload(Map<String, dynamic> payload) async {
    await _cache.set(PersistenceKeys.cacheIconsAppsPayload, payload);
    await _cache.set(PersistenceKeys.cacheIconsAppsUpdatedAtUtc, DateTime.now().toUtc().toIso8601String());
  }

  Future<DateTime?> lastUpdatedAtUtc() async {
    final raw = await _cache.get(PersistenceKeys.cacheIconsAppsUpdatedAtUtc);
    if (raw is! String) {
      return null;
    }
    return DateTime.tryParse(raw)?.toUtc();
  }

  Future<void> clear() async {
    await _cache.delete(PersistenceKeys.cacheIconsAppsPayload);
    await _cache.delete(PersistenceKeys.cacheIconsAppsUpdatedAtUtc);
  }
}
