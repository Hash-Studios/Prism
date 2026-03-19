import 'package:Prism/core/persistence/data_sources/app_icons_local_data_source.dart';
import 'package:Prism/core/persistence/data_sources/feed_cache_local_data_source.dart';
import 'package:Prism/core/persistence/data_sources/notifications_local_data_source.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:injectable/injectable.dart';

@lazySingleton
class CacheMaintenanceService {
  CacheMaintenanceService(this._notificationsLocal, this._feedCacheLocal, this._appIconsLocal);

  final NotificationsLocalDataSource _notificationsLocal;
  final FeedCacheLocalDataSource _feedCacheLocal;
  final AppIconsLocalDataSource _appIconsLocal;

  Future<void> clearTransientCache() async {
    await DefaultCacheManager().emptyCache();
    PaintingBinding.instance.imageCache.clear();
    await _notificationsLocal.clearAll();
    await _notificationsLocal.clearLastFetchAtUtc();
    await _feedCacheLocal.clearAllFeedCaches();
    await _appIconsLocal.clear();
  }
}
