class SessionEntity {
  const SessionEntity({
    required this.userId,
    required this.email,
    required this.name,
    required this.profilePhoto,
    required this.loggedIn,
    required this.premium,
    required this.subscriptionTier,
  });

  final String userId;
  final String email;
  final String name;
  final String profilePhoto;
  final bool loggedIn;
  final bool premium;
  final String subscriptionTier;

  static const SessionEntity guest = SessionEntity(
    userId: '',
    email: '',
    name: '',
    profilePhoto: '',
    loggedIn: false,
    premium: false,
    subscriptionTier: 'free',
  );
}
