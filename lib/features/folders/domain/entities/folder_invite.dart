/// Why the server refused a join. The wire value is the callable error message.
enum FolderJoinRefusal {
  notFound('not_found'),
  expired('expired'),
  used('used'),
  full('full'),
  blocked('blocked'),
  account('account');

  const FolderJoinRefusal(this.wireValue);

  final String wireValue;

  static FolderJoinRefusal? fromWire(String value) =>
      FolderJoinRefusal.values.where((refusal) => refusal.wireValue == value).firstOrNull;
}

/// A single-use invite the owner shares. It expires 7 days after it is made.
class FolderInvite {
  const FolderInvite({required this.code, required this.folderId, required this.expiresAt});

  final String code;
  final String folderId;
  final DateTime expiresAt;

  /// The app opens this link on the join page. The short link points here.
  Uri get canonicalLink => Uri.https('prismwalls.com', '/folder/$folderId', <String, String>{'invite': code});
}

/// What the join page shows for a code.
sealed class FolderInvitePreview {
  const FolderInvitePreview();
}

/// The code is good. [isMember] is true when the viewer already owns or edits the folder.
class FolderInviteOpen extends FolderInvitePreview {
  const FolderInviteOpen({
    required this.folderId,
    required this.name,
    required this.ownerId,
    required this.itemCount,
    required this.covers,
    required this.memberCount,
    required this.isMember,
  });

  final String folderId;
  final String name;
  final String ownerId;
  final int itemCount;
  final List<String> covers;

  /// The owner and the editors.
  final int memberCount;
  final bool isMember;
}

/// The server refused the code. The preview shows nothing of the folder.
class FolderInviteRefused extends FolderInvitePreview {
  const FolderInviteRefused(this.refusal);

  final FolderJoinRefusal refusal;
}
