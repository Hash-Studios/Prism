part of 'session_bloc.j.dart';

@freezed
abstract class SessionState with _$SessionState {
  const factory SessionState({
    required LoadStatus status,
    required ActionStatus actionStatus,
    required SessionEntity session,
    Failure? failure,
  }) = _SessionState;

  factory SessionState.initial() =>
      const SessionState(status: LoadStatus.initial, actionStatus: ActionStatus.idle, session: SessionEntity.guest);
}
