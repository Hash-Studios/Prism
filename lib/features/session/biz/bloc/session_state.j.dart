part of 'session_bloc.j.dart';

@freezed
abstract class SessionState with _$SessionState {
  const factory SessionState({required LoadStatus status, required SessionEntity session}) = _SessionState;

  factory SessionState.initial() => const SessionState(status: LoadStatus.initial, session: SessionEntity.guest);
}
