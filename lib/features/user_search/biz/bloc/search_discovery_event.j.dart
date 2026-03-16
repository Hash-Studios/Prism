part of 'search_discovery_bloc.j.dart';

@freezed
abstract class SearchDiscoveryEvent with _$SearchDiscoveryEvent {
  const factory SearchDiscoveryEvent.fetchRequested() = _FetchRequested;
  const factory SearchDiscoveryEvent.refreshRequested() = _RefreshRequested;
}
