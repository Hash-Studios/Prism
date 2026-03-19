class UserSearchUser {
  const UserSearchUser({
    required this.id,
    required this.name,
    required this.username,
    required this.email,
    required this.profilePhoto,
    required this.coverPhoto,
    required this.bio,
    required this.links,
    required this.followers,
    required this.following,
    required this.premium,
  });

  final String id;
  final String name;
  final String username;
  final String email;
  final String profilePhoto;
  final String? coverPhoto;
  final String bio;
  final Map<String, String> links;
  final List<String> followers;
  final List<String> following;
  final bool premium;
}
