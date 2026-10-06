class PersistenceKeys {
  const PersistenceKeys._();

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

  static String favoritesSeeded(String userId) => '$favoritesSeededPrefix$userId';

  /// Set-based favorites keys (v3+): store the full set of favorited IDs as a
  /// JSON list under a single key per user scope.
  static String favoritesWallSet(String userId) => '${favoritesWallPrefix}__set.$userId';

  // Notification preferences
  static const String notifWotd = 'notif.wotd';

  // Auto-rotate wallpapers (Android, Pro). Read through SettingsLocalDataSource.
  static const String autoRotateEnabled = 'autoRotate.enabled';
  static const String autoRotateIntervalMinutes = 'autoRotate.intervalMinutes';
  static const String autoRotateTarget = 'autoRotate.target';
  static const String autoRotateShuffle = 'autoRotate.shuffle';
  static const String autoRotateChargingOnly = 'autoRotate.chargingOnly';
  static const String autoRotateBatteryTipShown = 'autoRotate.batteryTipShown';

  // Default target when the user taps Set: 'ask' | 'home' | 'lock' | 'both'.
  static const String defaultApplyTarget = 'wallpaper.defaultApplyTarget';

  // JSON list of applied wallpapers, newest first. Owned by wallpaper_history.
  static const String wallpaperHistoryItems = 'wallpaper.history.items';

  // JSON list of recent search queries, newest first.
  static const String recentSearches = 'search.recent';

  // Notification ids the user deleted, so a remote sync does not restore them.
  static const String notificationsDeletedIds = 'notifications.deleted_ids';

  // Download quality: 'original' | 'compressed'
  static const String downloadQuality = 'downloadQuality';

  // Quick tile configuration, written as raw strings so native TileServices
  // can read them directly from SharedPreferences without the Flutter codec.
  static const String quickTileCategoryName = 'quick_tile.category.name';
  static const String quickTileCategorySource = 'quick_tile.category.source';
  static const String quickTileCategoryTarget = 'quick_tile.category.target';
  static const String quickTilePexelsApiKey = 'quick_tile.pexels.api_key';

  static const String quickTileWotdTarget = 'quick_tile.wotd.target';
  // Pre-cached WOTD wallpaper URL written by Flutter when WOTD loads.
  static const String quickTileWotdUrl = 'quick_tile.wotd.url';

  static const String quickTileFavsTarget = 'quick_tile.favs.target';
  // JSON-encoded list of full-resolution URLs from the user's favourites.
  static const String quickTileFavWallUrls = 'quick_tile.favs.wall_urls';
}
