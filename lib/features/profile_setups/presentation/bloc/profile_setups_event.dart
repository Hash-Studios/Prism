part of 'profile_setups_bloc.dart';

@freezed
abstract class ProfileSetupsEvent with _$ProfileSetupsEvent {
  const factory ProfileSetupsEvent.started({required String email}) = _Started;
  const factory ProfileSetupsEvent.refreshRequested() = _RefreshRequested;
  const factory ProfileSetupsEvent.fetchMoreRequested() = _FetchMoreRequested;
}
