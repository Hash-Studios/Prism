part of 'folders_bloc.j.dart';

@freezed
abstract class FoldersEvent with _$FoldersEvent {
  const factory FoldersEvent.started({required String userId, @Default(0) int operationId}) = _Started;
  const factory FoldersEvent.cleared() = _Cleared;
  const factory FoldersEvent.folderOpened({required String folderId, @Default(0) int operationId}) = _FolderOpened;
  const factory FoldersEvent.membershipRequested({required FavouriteWallEntity wall, @Default(0) int operationId}) =
      _MembershipRequested;
  const factory FoldersEvent.createRequested({
    required String name,
    FavouriteWallEntity? wall,
    @Default(0) int operationId,
  }) = _CreateRequested;
  const factory FoldersEvent.renameRequested({
    required String folderId,
    required String name,
    @Default(0) int operationId,
  }) = _RenameRequested;
  const factory FoldersEvent.deleteRequested({required String folderId, @Default(0) int operationId}) =
      _DeleteRequested;

  /// Puts [wall] in exactly [folderIds] plus a new folder per name in [newNames], and takes it out of the rest.
  const factory FoldersEvent.saveRequested({
    required FavouriteWallEntity wall,
    required Set<String> folderIds,
    @Default(<String>[]) List<String> newNames,
    @Default(0) int operationId,
  }) = _SaveRequested;
  const factory FoldersEvent.itemRemoved({
    required String folderId,
    required FavouriteWallEntity wall,
    @Default(0) int operationId,
  }) = _ItemRemoved;
}
