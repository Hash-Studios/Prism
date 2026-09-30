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
    final steps = <Future<void> Function()>[
      () => (_imageCache ?? DefaultCacheManager()).emptyCache(),
      () async => PaintingBinding.instance.imageCache.clear(),
      _notificationsLocal.clearAll,
      _notificationsLocal.clearLastFetchAtUtc,
      _feedCacheLocal.clearAllFeedCaches,
      _appIconsLocal.clear,
      () async {
        final documents = await getApplicationDocumentsDirectory();
        if (await documents.exists()) {
          await for (final entry in documents.list(followLinks: false)) {
            try {
              final name = path.basename(entry.path);
              if ((entry is Directory && name == 'images') ||
                  (entry is File &&
                      name.startsWith('filtered_') &&
                      name.endsWith('_pic.jpg') &&
                      name.length >= 'filtered__pic.jpg'.length)) {
                await entry.delete(recursive: entry is Directory);
              }
            } catch (_) {}
          }
        }
      },
    ];

    for (final step in steps) {
      try {
        await step();
      } catch (_) {}
    }
  }
}
