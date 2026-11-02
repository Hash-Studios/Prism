/// A folder its owner made public, `publicFolders/{id}`. The server writes it from the private folder.
class PublicFolderEntity {
  const PublicFolderEntity({
    required this.id,
    required this.ownerId,
    required this.name,
    required this.itemCount,
    required this.covers,
    required this.followerCount,
    this.shareImage = '',
  });

  final String id;
  final String ownerId;
  final String name;
  final int itemCount;

  /// Up to 4 thumbnail URLs, newest first.
  final List<String> covers;
  final int followerCount;

  /// The 4-wall image for link previews. Empty until the server has made it.
  final String shareImage;

  PublicFolderEntity copyWith({int? followerCount}) => PublicFolderEntity(
    id: id,
    ownerId: ownerId,
    name: name,
    itemCount: itemCount,
    covers: covers,
    followerCount: followerCount ?? this.followerCount,
    shareImage: shareImage,
  );
}

/// Why a follow or a visibility change was refused.
enum PublicFolderRefusal {
  /// The name cannot be shown to others.
  name,

  /// A moderator hid the folder.
  hidden,

  /// The folder is private or gone.
  unavailable,

  /// Too many changes today.
  limit,
}
