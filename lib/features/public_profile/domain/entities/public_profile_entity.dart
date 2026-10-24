class PublicProfileEntity {
  const PublicProfileEntity({
    required this.id,
    required this.name,
    required this.email,
    required this.username,
    required this.profilePhoto,
    required this.bio,
    required this.links,
    required this.coverPhoto,
    this.followerCount = 0,
    this.followingCount = 0,
    this.isFollowedByCurrentUser = false,
    this.badges = const <String>[],
    this.frameId,
    this.nameGlowId,
    this.xp = 0,
    this.premium = false,
  });

  final String id;
  final String name;
  final String email;
  final String username;
  final String profilePhoto;
  final String bio;
  final Map<String, String> links;
  final String coverPhoto;
  final int followerCount;
  final int followingCount;
  final bool isFollowedByCurrentUser;

  /// Earned badge ids.
  final List<String> badges;

  /// Equipped cosmetics, from `cosmetics.frame` and `cosmetics.nameGlow`.
  final String? frameId;
  final String? nameGlowId;
  final int xp;
  final bool premium;
}
