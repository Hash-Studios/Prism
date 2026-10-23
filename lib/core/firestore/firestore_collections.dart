class FirebaseCollections {
  const FirebaseCollections._();

  static const String usersV2 = 'usersv2';
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

  /// `usersv2/{uid}/private`, the owner-only subcollection that holds the `economy` doc.
  static String userPrivate(String uid) => '$usersV2/$uid/private';
}
