class UserSummaryEntity {
  const UserSummaryEntity({
    required this.id,
    required this.email,
    required this.name,
    required this.username,
    required this.profilePhoto,
    required this.isFollowedByCurrentUser,
  });

  final String id;
  final String email;
  final String name;
  final String username;
  final String profilePhoto;

  /// Whether the currently logged-in user follows this person.
  final bool isFollowedByCurrentUser;

  UserSummaryEntity copyWith({
    String? id,
    String? email,
    String? name,
    String? username,
    String? profilePhoto,
    bool? isFollowedByCurrentUser,
  }) {
    return UserSummaryEntity(
      id: id ?? this.id,
      email: email ?? this.email,
      name: name ?? this.name,
      username: username ?? this.username,
      profilePhoto: profilePhoto ?? this.profilePhoto,
      isFollowedByCurrentUser: isFollowedByCurrentUser ?? this.isFollowedByCurrentUser,
    );
  }
}
