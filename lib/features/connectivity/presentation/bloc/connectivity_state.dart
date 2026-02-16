part of 'connectivity_bloc.dart';

@freezed
abstract class ConnectivityState with _$ConnectivityState {
  const factory ConnectivityState({
    required LoadStatus status,
    required ActionStatus actionStatus,
    required ConnectivityEntity connectivity,
    Failure? failure,
  }) = _ConnectivityState;

  factory ConnectivityState.initial() => const ConnectivityState(
        status: LoadStatus.initial,
        actionStatus: ActionStatus.idle,
        connectivity: ConnectivityEntity(isConnected: true),
      );
}
