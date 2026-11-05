part of 'day_night_bloc.j.dart';

@freezed
abstract class DayNightEvent with _$DayNightEvent {
  /// [isPro] is true for Pro and for an active auto-rotate pass. [passUntil] is the pass end, null for Pro.
  const factory DayNightEvent.entitlementChanged({required bool isPro, required String userId, DateTime? passUntil}) =
      _EntitlementChanged;
  const factory DayNightEvent.wallPicked(DayNightSlot slot, DayNightWall wall) = _WallPicked;
  const factory DayNightEvent.variantsPicked({required DayNightWall day, required DayNightWall night}) =
      _VariantsPicked;
  const factory DayNightEvent.timesChanged({required DayTime dayStart, required DayTime nightStart}) = _TimesChanged;
  const factory DayNightEvent.targetChanged(WallpaperTarget target) = _TargetChanged;
  const factory DayNightEvent.toggled(bool enabled) = _Toggled;
  const factory DayNightEvent.retryPressed() = _RetryPressed;
  const factory DayNightEvent.proLapseAcknowledged() = _ProLapseAcknowledged;
}
