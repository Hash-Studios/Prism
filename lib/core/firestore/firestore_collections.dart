class FirebaseCollections {
  const FirebaseCollections._();

  static const String users = 'users';
  static const String usersV2 = 'usersv2';
  static const String walls = 'walls';
  static const String setups = 'setups';
  static const String draftSetups = 'draftSetups';
  static const String rejectedWalls = 'rejectedWalls';
  static const String rejectedSetups = 'rejectedSetups';
  static const String notifications = 'notifications';
  static const String collections = 'collections';
  static const String apps = 'apps';
  static const String codes = 'codes';
  static const String favouritesWalls = 'favouritesWalls';
  static const String favouritesSetups = 'favouritesSetups';
  static const String aiGenerations = 'aiGenerations';
  static const String coinTransactions = 'coinTransactions';
  static const String wallOfTheDay = 'wall_of_the_day';
  static const String pastPicks = 'past_picks';
  static const String notificationRequests = 'notificationRequests';
}

@Deprecated('Use FirebaseCollections instead.')
typedef FirestoreCollections = FirebaseCollections;
