part of 'connectivity_bloc.dart';

@freezed
abstract class ConnectivityEvent with _$ConnectivityEvent {
  const factory ConnectivityEvent.started() = _Started;
  const factory ConnectivityEvent.statusChanged(ConnectivityEntity connectivity) = _StatusChanged;
  const factory ConnectivityEvent.recheckRequested() = _RecheckRequested;
}
