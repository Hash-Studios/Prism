import 'dart:io';

import 'package:Prism/core/persistence/data_sources/app_icons_local_data_source.dart';
import 'package:Prism/core/persistence/data_sources/feed_cache_local_data_source.dart';
import 'package:Prism/core/persistence/data_sources/notifications_local_data_source.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:injectable/injectable.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

@lazySingleton
class CacheMaintenanceService {
  CacheMaintenanceService(
    this._notificationsLocal,
    this._feedCacheLocal,
    this._appIconsLocal, {
    @ignoreParam BaseCacheManager? imageCache,
  }) : _imageCache = imageCache;

  final NotificationsLocalDataSource _notificationsLocal;
  final FeedCacheLocalDataSource _feedCacheLocal;
  final AppIconsLocalDataSource _appIconsLocal;
  final BaseCacheManager? _imageCache;

  Future<void> clearTransientCache() async {
    await (_imageCache ?? DefaultCacheManager()).emptyCache();
    PaintingBinding.instance.imageCache.clear();
    await _notificationsLocal.clearAll();
    await _notificationsLocal.clearLastFetchAtUtc();
    await _feedCacheLocal.clearAllFeedCaches();
    await _appIconsLocal.clear();
    final documents = await getApplicationDocumentsDirectory();
    if (await documents.exists()) {
      await for (final entry in documents.list(followLinks: false)) {
        final name = path.basename(entry.path);
        if ((entry is Directory && name == 'images') ||
            (entry is File && name.startsWith('filtered_') && name.endsWith('_pic.jpg'))) {
          await entry.delete(recursive: entry is Directory);
        }
      }
    }
  }
}
