class PublicProfileEntity {
  const PublicProfileEntity({
    required this.id,
    required this.name,
    required this.email,
    required this.username,
    required this.profilePhoto,
    required this.bio,
    required this.followers,
    required this.following,
    required this.links,
    required this.coverPhoto,
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
  final List<String> followers;
  final List<String> following;
  final Map<String, String> links;
  final String coverPhoto;

  /// Earned badge ids.
  final List<String> badges;

  /// Equipped cosmetics, from `cosmetics.frame` and `cosmetics.nameGlow`.
  final String? frameId;
  final String? nameGlowId;
  final int xp;
  final bool premium;
}
