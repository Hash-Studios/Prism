part of 'auto_rotate_bloc.j.dart';

@freezed
abstract class AutoRotateEvent with _$AutoRotateEvent {
  /// [isPro] is true for Pro and for an active auto-rotate pass; [passUntil] is the pass end, null for Pro.
  const factory AutoRotateEvent.started({
    required List<String> favouriteUrls,
    required bool isPro,
    DateTime? passUntil,
  }) = _Started;
  const factory AutoRotateEvent.entitlementChanged({required bool isPro, required String userId, DateTime? passUntil}) =
      _EntitlementChanged;
  const factory AutoRotateEvent.favouritesChanged(List<String> favouriteUrls) = _FavouritesChanged;
  const factory AutoRotateEvent.toggled(bool enabled) = _Toggled;
  const factory AutoRotateEvent.intervalChanged(int minutes) = _IntervalChanged;
  const factory AutoRotateEvent.targetChanged(WallpaperTarget target) = _TargetChanged;
  const factory AutoRotateEvent.shuffleChanged(bool shuffle) = _ShuffleChanged;
  const factory AutoRotateEvent.sourceChanged(AutoRotateSource source) = _SourceChanged;
  const factory AutoRotateEvent.categoryChanged(String category) = _CategoryChanged;
  const factory AutoRotateEvent.folderChosen({
    required String folderId,
    required String name,
    @Default(false) bool enable,
  }) = _FolderChosen;

  /// The folder's walls, name or existence may have changed. [name] is null when the folder is gone from the list.
  const factory AutoRotateEvent.folderChanged({required String folderId, String? name}) = _FolderChanged;
  const factory AutoRotateEvent.folderSettled() = _FolderSettled;
  const factory AutoRotateEvent.folderStopAcknowledged() = _FolderStopAcknowledged;
  const factory AutoRotateEvent.chargingOnlyChanged(bool chargingOnly) = _ChargingOnlyChanged;
  const factory AutoRotateEvent.rotateNowPressed() = _RotateNowPressed;
  const factory AutoRotateEvent.favouritesSettled() = _FavouritesSettled;
  const factory AutoRotateEvent.statusRefreshed() = _StatusRefreshed;
  const factory AutoRotateEvent.batteryTipDismissed() = _BatteryTipDismissed;
  const factory AutoRotateEvent.proLapseAcknowledged() = _ProLapseAcknowledged;
}
