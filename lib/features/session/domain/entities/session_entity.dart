class SessionEntity {
  const SessionEntity({
    required this.userId,
    required this.loggedIn,
    required this.premium,
    required this.subscriptionTier,
  });

  final String userId;
  final bool loggedIn;
  final bool premium;
  final String subscriptionTier;

  static const SessionEntity guest = SessionEntity(
    userId: '',
    loggedIn: false,
    premium: false,
    subscriptionTier: 'free',
  );
}
