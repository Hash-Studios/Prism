/// Editors a folder can have, besides its owner. The server enforces it (functions/src/sharedFolders.ts).
const int folderMaxEditors = 10;

enum FolderRole { owner, editor }

/// A person who can add and remove walls in a folder. Only the server adds or removes members.
class FolderMember {
  const FolderMember({required this.uid, required this.role, required this.addedBy, required this.addedAt});

  final String uid;
  final FolderRole role;

  /// The uid of the owner who invited this member. The owner's own entry names the owner.
  final String addedBy;
  final DateTime addedAt;

  @override
  bool operator ==(Object other) =>
      other is FolderMember &&
      other.uid == uid &&
      other.role == role &&
      other.addedBy == addedBy &&
      other.addedAt == addedAt;

  @override
  int get hashCode => Object.hash(uid, role, addedBy, addedAt);
}
