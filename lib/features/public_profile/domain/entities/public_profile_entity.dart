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
    required this.premium,
    required this.coverPhoto,
  });

  final String id;
  final String name;
  final String email;
  final String username;
  final String profilePhoto;
  final String bio;
  final List<dynamic> followers;
  final List<dynamic> following;
  final Map<String, dynamic> links;
  final bool premium;
  final String coverPhoto;

  static const PublicProfileEntity empty = PublicProfileEntity(
    id: '',
    name: '',
    email: '',
    username: '',
    profilePhoto: '',
    bio: '',
    followers: <dynamic>[],
    following: <dynamic>[],
    links: <String, dynamic>{},
    premium: false,
    coverPhoto: '',
  );
}
