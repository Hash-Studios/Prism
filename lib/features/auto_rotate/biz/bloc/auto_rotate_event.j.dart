part of 'auto_rotate_bloc.j.dart';

@freezed
abstract class AutoRotateEvent with _$AutoRotateEvent {
  const factory AutoRotateEvent.started() = _Started;
  const factory AutoRotateEvent.sourceTypeChanged({
    required AutoRotateSourceType sourceType,
    String? name,
  }) = _SourceTypeChanged;
  const factory AutoRotateEvent.targetChanged({required aw.WallpaperTarget target}) = _TargetChanged;
  const factory AutoRotateEvent.intervalChanged({required int minutes}) = _IntervalChanged;
  const factory AutoRotateEvent.chargingTriggerToggled() = _ChargingTriggerToggled;
  const factory AutoRotateEvent.orderChanged({required AutoRotateOrder order}) = _OrderChanged;
  const factory AutoRotateEvent.startRequested() = _StartRequested;
  const factory AutoRotateEvent.stopRequested() = _StopRequested;
  const factory AutoRotateEvent.statusRefreshRequested() = _StatusRefreshRequested;
  const factory AutoRotateEvent.rotateNowRequested() = _RotateNowRequested;
}
