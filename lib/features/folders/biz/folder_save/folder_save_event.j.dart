part of 'folder_save_bloc.j.dart';

/// Tells the user how a run ended when no folder page shows it. The page passes it with its localized copy.
typedef FolderSaveAnnouncer = void Function(FolderSaveTarget target, FolderSaveRun run);

@freezed
sealed class FolderSaveEvent with _$FolderSaveEvent {
  const factory FolderSaveEvent.planRequested({required FolderSaveTarget target, required List<FolderSaveWall> walls}) =
      _PlanRequested;
  const factory FolderSaveEvent.started({required FolderSaveChoice choice, FolderSaveAnnouncer? announce}) = _Started;
  const factory FolderSaveEvent.cancelRequested() = _CancelRequested;
  const factory FolderSaveEvent.retryRequested({FolderSaveAnnouncer? announce}) = _RetryRequested;
  const factory FolderSaveEvent.dismissed() = _Dismissed;
}
