part of 'startup_bloc.dart';

@freezed
abstract class StartupEvent with _$StartupEvent {
  const factory StartupEvent.started({String? currentVersion}) = _Started;
  const factory StartupEvent.retryRequested({String? currentVersion}) = _RetryRequested;
  const factory StartupEvent.notchMeasured({required double notchHeight}) = _NotchMeasured;
}
