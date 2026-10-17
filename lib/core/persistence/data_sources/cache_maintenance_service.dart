import 'dart:io';

import 'package:Prism/core/cache/prism_full_image_cache.dart';
import 'package:Prism/core/cache/prism_image_cache.dart';
import 'package:Prism/core/offline/offline_asset_store.dart';
import 'package:Prism/core/persistence/data_sources/app_icons_local_data_source.dart';
import 'package:Prism/features/wallpaper_detail/data/wallpaper_tint_renderer.dart';
import 'package:Prism/logger/logger.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:injectable/injectable.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

@lazySingleton
class CacheMaintenanceService {
  CacheMaintenanceService(
    this._appIconsLocal, {
    @ignoreParam BaseCacheManager? imageCache,
    @ignoreParam BaseCacheManager? thumbnailCache,
    @ignoreParam BaseCacheManager? fullImageCache,
    @ignoreParam OfflineAssetStore? offlineAssetStore,
  }) : _imageCache = imageCache,
       _thumbnailCache = thumbnailCache,
       _fullImageCache = fullImageCache,
       _offlineAssetStore = offlineAssetStore;

  final AppIconsLocalDataSource _appIconsLocal;
  final BaseCacheManager? _imageCache;
  final BaseCacheManager? _thumbnailCache;
  final BaseCacheManager? _fullImageCache;
  final OfflineAssetStore? _offlineAssetStore;

  Future<int> retainedAssetBytes() => (_offlineAssetStore ?? OfflineAssetStore.instance).storedBytes;

  Future<Map<String, String>> retainedAssetPaths() => (_offlineAssetStore ?? OfflineAssetStore.instance).localPaths();

  Future<void> clearRetainedAssets() => (_offlineAssetStore ?? OfflineAssetStore.instance).clearRetained();

  Future<void> clearTransientCache() async {
    final steps = <Future<void> Function()>[
      () => (_imageCache ?? DefaultCacheManager()).emptyCache(),
      () => (_thumbnailCache ?? PrismImageCache.instance).emptyCache(),
      () => (_fullImageCache ?? PrismFullImageCache.instance).emptyCache(),
      () async => PaintingBinding.instance.imageCache.clear(),
      clearTintedWallpapers,
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
            } catch (error, stackTrace) {
              logger.w('Could not delete editor scratch entry', tag: 'Cache', error: error, stackTrace: stackTrace);
            }
          }
        }
      },
    ];

    for (final step in steps) {
      try {
        await step();
      } catch (error, stackTrace) {
        logger.w('A cache clear step failed', tag: 'Cache', error: error, stackTrace: stackTrace);
      }
    }
  }
}
