class SessionEntity {
  const SessionEntity({
    required this.userId,
    required this.email,
    required this.name,
    required this.username,
    required this.profilePhoto,
    required this.coverPhoto,
    required this.bio,
    required this.loggedIn,
    required this.premium,
    required this.subscriptionTier,
    required this.coins,
    required this.links,
    required this.followers,
    required this.following,
    required this.badges,
    required this.transactions,
    required this.subPrisms,
    required this.uploadsWeekStart,
    required this.uploadsThisWeek,
  });

  final String userId;
  final String email;
  final String name;
  final String username;
  final String profilePhoto;
  final String coverPhoto;
  final String bio;
  final bool loggedIn;
  final bool premium;
  final String subscriptionTier;
  final int coins;
  final Map<String, dynamic> links;
  final List<dynamic> followers;
  final List<dynamic> following;
  final List<dynamic> badges;
  final List<dynamic> transactions;
  final List<dynamic> subPrisms;
  final String uploadsWeekStart;
  final int uploadsThisWeek;

  static const SessionEntity guest = SessionEntity(
    userId: '',
    email: '',
    name: '',
    username: '',
    profilePhoto: '',
    coverPhoto: '',
    bio: '',
    loggedIn: false,
    premium: false,
    subscriptionTier: 'free',
    coins: 0,
    links: <String, dynamic>{},
    followers: <dynamic>[],
    following: <dynamic>[],
    badges: <dynamic>[],
    transactions: <dynamic>[],
    subPrisms: <dynamic>[],
    uploadsWeekStart: '',
    uploadsThisWeek: 0,
  );
}
