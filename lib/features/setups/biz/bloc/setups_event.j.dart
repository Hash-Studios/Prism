part of 'setups_bloc.j.dart';

@freezed
abstract class SetupsEvent with _$SetupsEvent {
  const factory SetupsEvent.started() = _Started;
  const factory SetupsEvent.refreshRequested() = _RefreshRequested;
  const factory SetupsEvent.fetchMoreRequested() = _FetchMoreRequested;
}
