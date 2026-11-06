import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/features/folders/domain/entities/folder_invite.dart';

/// A refused shared folder request. [refusal] is set when the server refused a join or an invite.
class SharedFolderFailure extends Failure {
  const SharedFolderFailure(super.message, {this.refusal, super.code});

  final FolderJoinRefusal? refusal;
}

/// Invites and members. The server owns both; each call goes through a callable.
abstract class SharedFoldersRepository {
  /// A new single-use code for [folderId]. Only the owner can make one.
  Future<Result<FolderInvite>> createInvite(String folderId);

  /// The folder behind [code], or the reason the server refuses it.
  Future<Result<FolderInvitePreview>> previewInvite(String code);

  /// Makes the user an editor. Returns the folder id. A refusal is a [SharedFolderFailure] with a [FolderJoinRefusal].
  Future<Result<String>> join(String code);

  /// The owner removes an editor.
  Future<Result<void>> removeMember(String folderId, String uid);

  /// An editor leaves the folder.
  Future<Result<void>> leave(String folderId);

  /// The uid of the person who added [itemKey], or null when the item is gone.
  Future<Result<String?>> addedBy(String folderId, String itemKey);
}
