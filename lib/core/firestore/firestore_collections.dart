class FirebaseCollections {
  const FirebaseCollections._();

  static const String usersV2 = 'usersv2';
  static const String profiles = 'profiles';
  static const String usernames = 'usernames';
  static const String walls = 'walls';
  static const String contentReports = 'contentReports';
  static const String rejectedWalls = 'rejectedWalls';
  static const String notifications = 'notifications';
  static const String collections = 'collections';
  static const String aiGenerations = 'aiGenerations';
  static const String coinTransactions = 'coinTransactions';
  static const String wallOfTheDay = 'wall_of_the_day';
  static const String wallpaperStats = 'wallpaper_stats';
  static const String notificationRequests = 'notificationRequests';
  static const String economyConfig = 'economyConfig';
  static const String drops = 'drops';
  static const String boosts = 'boosts';
  static const String draws = 'draws';
  static const String drawTickets = 'drawTickets';
  static const String leaderboards = 'leaderboards';
  static const String folders = 'folders';
  static const String moods = 'moods';

  /// `folders/{folderId}/items`, one doc per saved wall.
  static String folderItems(String folderId) => '$folders/$folderId/items';

  /// `publicFolders/{folderId}`, the server projection of a public folder.
  static const String publicFolders = 'publicFolders';

  /// `publicFolders/{folderId}/items`, the walls others see.
  static String publicFolderItems(String folderId) => '$publicFolders/$folderId/items';

  /// `usersv2/{uid}/followedFolders`, the public folders a user follows.
  static String followedFolders(String userId) => '$usersV2/$userId/followedFolders';

  /// `usersv2/{uid}/private`, the owner-only subcollection that holds the `economy` doc.
  static String userPrivate(String uid) => '$usersV2/$uid/private';

  static String profileFollowing(String uid) => '$profiles/$uid/following';

  static String profileFollowers(String uid) => '$profiles/$uid/followers';
}
