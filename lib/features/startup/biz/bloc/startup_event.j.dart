part of 'startup_bloc.j.dart';

@freezed
abstract class StartupEvent with _$StartupEvent {
  const factory StartupEvent.started({String? currentVersion}) = _Started;
}
