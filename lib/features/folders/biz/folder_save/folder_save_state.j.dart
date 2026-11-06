part of 'folder_save_bloc.j.dart';

@freezed
sealed class FolderSaveState with _$FolderSaveState {
  const factory FolderSaveState.idle() = FolderSaveIdle;
  const factory FolderSaveState.planning({required FolderSaveTarget target}) = FolderSavePlanning;
  const factory FolderSaveState.planned({required FolderSaveTarget target, required FolderSavePlan plan}) =
      FolderSavePlanned;
  const factory FolderSaveState.planFailed({required FolderSaveTarget target}) = FolderSavePlanFailed;

  /// Photos or storage access was refused before anything was charged.
  const factory FolderSaveState.accessDenied({required FolderSaveTarget target}) = FolderSaveAccessDenied;
  const factory FolderSaveState.running({
    required FolderSaveTarget target,
    required FolderSaveRun run,
    @Default(false) bool cancelling,
  }) = FolderSaveRunning;
  const factory FolderSaveState.finished({
    required FolderSaveTarget target,
    required FolderSaveRun run,
    @Default(false) bool cancelled,
  }) = FolderSaveFinished;

  const FolderSaveState._();

  FolderSaveTarget? get target => switch (this) {
    FolderSaveIdle() => null,
    FolderSavePlanning(:final target) ||
    FolderSavePlanned(:final target) ||
    FolderSavePlanFailed(:final target) ||
    FolderSaveAccessDenied(:final target) ||
    FolderSaveRunning(:final target) ||
    FolderSaveFinished(:final target) => target,
  };
}
