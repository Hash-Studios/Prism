class UserSearchUser {
  const UserSearchUser({
    required this.id,
    required this.name,
    required this.username,
    required this.email,
    required this.profilePhoto,
    required this.premium,
  });

  final String id;
  final String name;
  final String username;
  final String email;
  final String profilePhoto;
  final bool premium;
}
