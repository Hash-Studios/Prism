import 'package:flutter/foundation.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// The disk cache for full-size wallpapers. The default manager keeps 200 files for 30 days, which at 2 to 5 MB each
/// can grow to about 1 GB. This one keeps 60 files for 7 days.
class PrismFullImageCache {
  PrismFullImageCache._();

  static const String key = 'prism_full';
  static const int maxObjects = 60;
  static const Duration stalePeriod = Duration(days: 7);

  static BaseCacheManager? _shared;

  /// Created on first use, so nothing touches the file system before an image loads.
  static BaseCacheManager get instance =>
      testOverride ??
      (_shared ??= CacheManager(Config(key, stalePeriod: stalePeriod, maxNrOfCacheObjects: maxObjects)));

  /// Replaces the cache manager in tests. Set it back to `null` to restore the shared one.
  @visibleForTesting
  static BaseCacheManager? testOverride;
}
