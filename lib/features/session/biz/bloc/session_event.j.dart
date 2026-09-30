part of 'session_bloc.j.dart';

@freezed
abstract class SessionEvent with _$SessionEvent {
  const factory SessionEvent.started() = _Started;
}
