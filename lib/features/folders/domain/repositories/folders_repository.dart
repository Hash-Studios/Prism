import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/features/favourite_walls/domain/entities/favourite_wall_entity.dart';
import 'package:Prism/features/folders/domain/entities/folder_entity.dart';

typedef FolderWriteFailure = ({String ownerId, int revision, Failure failure});

abstract class FoldersRepository {
  /// A session records this boundary so late failures from earlier sessions are ignored.
  int get writeRevision;
  Stream<FolderWriteFailure> get writeFailures;

  /// The user's folders, most recently updated first.
  Future<Result<List<FolderEntity>>> fetchFolders(String userId);

  /// The folder's walls, newest first. Null when the folder does not exist or is not the user's.
  Future<Result<List<FavouriteWallEntity>?>> fetchItems(String folderId, {required String userId, int? limit});

  /// The ids in [folderIds] whose folder holds the item [itemKey].
  Future<Result<Set<String>>> foldersContaining(List<String> folderIds, String itemKey);

  /// Writes [folder], and [firstWall] in the same batch when given.
  Future<Result<void>> createFolder(FolderEntity folder, {FavouriteWallEntity? firstWall});

  Future<Result<void>> renameFolder(FolderEntity folder);

  /// Deletes the folder's items, then the folder.
  Future<Result<void>> deleteFolder(String folderId, {required String userId, bool Function()? isCancelled});

  /// Writes [wall] into [folder] and the folder's new count, covers and update time in one batch.
  Future<Result<void>> addItem(FolderEntity folder, FavouriteWallEntity wall);

  /// Deletes [wall] from [folder] and writes the folder's new count, covers and update time in one batch.
  Future<Result<void>> removeItem(FolderEntity folder, FavouriteWallEntity wall);
}
