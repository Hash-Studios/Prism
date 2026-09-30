import 'package:Prism/core/persistence/persistence_keys.dart';
import 'package:Prism/core/persistence/store_adapters/lazy_file_cache.dart';
import 'package:injectable/injectable.dart';

@lazySingleton
class AppIconsLocalDataSource {
  AppIconsLocalDataSource();

  final LazyFileCache _cache = LazyFileCache('icons_cache');

  Future<void> clear() async {
    await _cache.delete(PersistenceKeys.cacheIconsAppsPayload);
    await _cache.delete(PersistenceKeys.cacheIconsAppsUpdatedAtUtc);
  }
}
