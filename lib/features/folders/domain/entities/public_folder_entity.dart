import 'package:Prism/features/folders/domain/entities/folder_section.dart';

/// One wall of a public folder: its wall id and the section it is in, if any.
typedef PublicFolderWall = ({String id, String? sectionId});

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
    this.sections = const <FolderSection>[],
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

  /// The owner's sections, in order.
  final List<FolderSection> sections;

  PublicFolderEntity copyWith({int? followerCount}) => PublicFolderEntity(
    id: id,
    ownerId: ownerId,
    name: name,
    itemCount: itemCount,
    covers: covers,
    followerCount: followerCount ?? this.followerCount,
    shareImage: shareImage,
    sections: sections,
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
