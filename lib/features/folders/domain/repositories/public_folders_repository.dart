import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/features/folders/domain/entities/public_folder_entity.dart';

/// A refused public folder request. [refusal] is null for network and other errors.
class PublicFolderFailure extends Failure {
  const PublicFolderFailure(super.message, {this.refusal, super.code});

  final PublicFolderRefusal? refusal;
}

abstract class PublicFoldersRepository {
  /// The folder, or null when it is private, gone, or hidden from this viewer by a block.
  Future<Result<PublicFolderEntity?>> fetchFolder(String folderId);

  /// The wall ids in the folder, newest first.
  Future<Result<List<String>>> fetchWallIds(String folderId);

  /// The public folders of [ownerId], most recently updated first.
  Future<Result<List<PublicFolderEntity>>> fetchOwnerFolders(String ownerId);

  /// The public folders [userId] follows, newest follow first. Folders that went private are left out.
  Future<Result<List<PublicFolderEntity>>> fetchFollowedFolders(String userId);

  Future<Result<bool>> isFollowing(String folderId, String userId);

  Future<Result<void>> setFollowing(String folderId, {required bool following});

  /// Returns true when the folder is public after the change.
  Future<Result<bool>> setPublic(String folderId, {required bool isPublic});
}
