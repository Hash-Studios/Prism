class OnboardingStarterCreatorEntity {
  const OnboardingStarterCreatorEntity({
    required this.userId,
    required this.email,
    required this.name,
    required this.photoUrl,
    required this.previewUrls,
    required this.rank,
    required this.bio,
    required this.followerCount,
  });

  final String userId;
  final String email;
  final String name;
  final String photoUrl;
  final List<String> previewUrls;
  final int rank;
  final String bio;
  final int followerCount;

  /// Parses only the curation fields from Remote Config (`email` and `rank`).
  /// Profile data is fetched live from Firestore; other fields default to empty.
  factory OnboardingStarterCreatorEntity.fromCurationMap(Map<String, dynamic> map) {
    return OnboardingStarterCreatorEntity(
      userId: '',
      email: map['email']?.toString() ?? '',
      name: '',
      photoUrl: '',
      previewUrls: const <String>[],
      rank: (map['rank'] as num?)?.toInt() ?? 0,
      bio: '',
      followerCount: 0,
    );
  }
}
