class PersistenceKeys {
  const PersistenceKeys._();

  static const int currentSchemaVersion = 2;

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
}
