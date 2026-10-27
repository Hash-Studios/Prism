part of 'folders_bloc.j.dart';

@freezed
abstract class FoldersState with _$FoldersState {
  const factory FoldersState({
    required LoadStatus status,
    required String userId,
    required List<FolderEntity> folders,

    /// Loaded walls per folder id, newest first.
    @Default(<String, List<FavouriteWallEntity>>{}) Map<String, List<FavouriteWallEntity>> items,
    @Default(<String, LoadStatus>{}) Map<String, LoadStatus> itemsStatus,

    /// Folder ids that hold each wall, keyed by [folderItemKey].
    @Default(<String, Set<String>>{}) Map<String, Set<String>> membership,
    @Default(<String, LoadStatus>{}) Map<String, LoadStatus> membershipStatus,
    @Default(ActionStatus.idle) ActionStatus actionStatus,
    @Default(0) int completedOperationId,
    Failure? failure,
  }) = _FoldersState;

  const FoldersState._();

  factory FoldersState.initial() =>
      const FoldersState(status: LoadStatus.initial, userId: '', folders: <FolderEntity>[]);

  FolderEntity? folder(String id) => folders.where((folder) => folder.id == id).firstOrNull;
}
