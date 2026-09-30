part of 'auto_rotate_bloc.j.dart';

@freezed
abstract class AutoRotateEvent with _$AutoRotateEvent {
  const factory AutoRotateEvent.started({required List<String> favouriteUrls, required bool isPro}) = _Started;
  const factory AutoRotateEvent.entitlementChanged({required bool isPro, required String userId}) = _EntitlementChanged;
  const factory AutoRotateEvent.favouritesChanged(List<String> favouriteUrls) = _FavouritesChanged;
  const factory AutoRotateEvent.toggled(bool enabled) = _Toggled;
  const factory AutoRotateEvent.intervalChanged(int minutes) = _IntervalChanged;
  const factory AutoRotateEvent.targetChanged(WallpaperTarget target) = _TargetChanged;
  const factory AutoRotateEvent.shuffleChanged(bool shuffle) = _ShuffleChanged;
  const factory AutoRotateEvent.rotateNowPressed() = _RotateNowPressed;
}
