class UserSearchUser {
  const UserSearchUser({
    required this.id,
    required this.name,
    required this.username,
    required this.profilePhoto,
    required this.followerCount,
  });

  final String id;
  final String name;
  final String username;
  final String profilePhoto;
  final int followerCount;
}
