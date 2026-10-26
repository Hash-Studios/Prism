part of 'drops_bloc.j.dart';

@freezed
abstract class DropsEvent with _$DropsEvent {
  /// No [weekKey] loads this week's Drop and the vault. A [weekKey] loads that one Drop.
  const factory DropsEvent.started({String? weekKey}) = _Started;
  const factory DropsEvent.refreshed() = _Refreshed;

  /// A null [wallId] unlocks every wall left.
  const factory DropsEvent.unlockRequested({String? wallId}) = _UnlockRequested;
  const factory DropsEvent.ticked() = _Ticked;

  /// Admins only. Renames the Drop on the page.
  const factory DropsEvent.renameRequested({required String title}) = _RenameRequested;
  const factory DropsEvent.unlockedChanged(Map<String, DropUnlock> unlocked) = _UnlockedChanged;
}
