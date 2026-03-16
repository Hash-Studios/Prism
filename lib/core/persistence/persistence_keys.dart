class PersistenceKeys {
  const PersistenceKeys._();

  static const int currentSchemaVersion = 3;

  static const String schemaVersion = 'schema.version';
  static const String schemaMigratedAtUtc = 'schema.migrated_at_utc';

  static const String sessionCurrentUser = 'session.current_user';

  static const String settingsPrefix = 'settings.';

  static String settings(String key) => '$settingsPrefix$key';

  static const String notificationsItems = 'notifications.items';
  static const String notificationsLastFetchUtc = 'notifications.last_fetch_utc';

  static const String cacheIconsAppsPayload = 'cache.icons.apps.payload';
  static const String cacheIconsAppsUpdatedAtUtc = 'cache.icons.apps.updated_at_utc';

  static const String cacheFeedPrefix = 'cache.feed.';

  static String cacheFeed(String source, String scope) => '$cacheFeedPrefix$source.$scope';

  static const String favoritesWallPrefix = 'favorites.walls.';
  static const String favoritesSetupPrefix = 'favorites.setups.';
  static const String favoritesSeededPrefix = 'favorites.seeded.';

  static String favoriteWall(String userId, String itemId) => '$favoritesWallPrefix$userId.$itemId';

  static String favoriteSetup(String userId, String itemId) => '$favoritesSetupPrefix$userId.$itemId';

  static String favoritesSeeded(String userId) => '$favoritesSeededPrefix$userId';

  /// Set-based favorites keys (v3+): store the full set of favorited IDs as a
  /// JSON list under a single key per user scope.
  static String favoritesWallSet(String userId) => '${favoritesWallPrefix}__set.$userId';

  static String favoritesSetupSet(String userId) => '${favoritesSetupPrefix}__set.$userId';

  // Notification preferences
  static const String notifWotd = 'notif.wotd';
  static const String notifPromo = 'notif.promo';

  // Download quality: 'original' | 'compressed'
  static const String downloadQuality = 'downloadQuality';

  // Quick tile configuration — written as raw strings so native TileServices
  // can read them directly from SharedPreferences without the Flutter codec.
  static const String quickTileCategoryName = 'quick_tile.category.name';
  static const String quickTileCategorySource = 'quick_tile.category.source';
  static const String quickTileCategoryTarget = 'quick_tile.category.target';

  static const String quickTileWotdTarget = 'quick_tile.wotd.target';
  // Pre-cached WOTD wallpaper URL written by Flutter when WOTD loads.
  static const String quickTileWotdUrl = 'quick_tile.wotd.url';

  static const String quickTileFavsTarget = 'quick_tile.favs.target';
  // JSON-encoded list of full-resolution URLs from the user's favourites.
  static const String quickTileFavWallUrls = 'quick_tile.favs.wall_urls';

  // Auto-rotate configuration
  static const String autoRotateEnabled         = 'auto_rotate.enabled';
  static const String autoRotateSourceType      = 'auto_rotate.source_type';
  static const String autoRotateCollectionName  = 'auto_rotate.collection_name';
  static const String autoRotateCategoryName    = 'auto_rotate.category_name';
  static const String autoRotateTarget          = 'auto_rotate.target';
  static const String autoRotateIntervalMinutes = 'auto_rotate.interval_minutes';
  static const String autoRotateChargingTrigger = 'auto_rotate.charging_trigger';
  static const String autoRotateOrder           = 'auto_rotate.order';
}
