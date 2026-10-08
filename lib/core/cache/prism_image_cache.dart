import 'package:flutter/foundation.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// The one disk cache for wallpaper thumbnails. It holds more objects than the default manager (200) so a long
/// scroll does not evict thumbnails that are still near the viewport.
class PrismImageCache {
  PrismImageCache._();

  static const String key = 'prism_images';
  static const int maxObjects = 2000;
  static const Duration stalePeriod = Duration(days: 14);

  static BaseCacheManager? _shared;

  /// Created on first use, so nothing touches the file system before an image loads.
  static BaseCacheManager get instance =>
      testOverride ??
      (_shared ??= CacheManager(Config(key, stalePeriod: stalePeriod, maxNrOfCacheObjects: maxObjects)));

  /// Replaces the cache manager in tests. Set it back to `null` to restore the shared one.
  @visibleForTesting
  static BaseCacheManager? testOverride;
}
