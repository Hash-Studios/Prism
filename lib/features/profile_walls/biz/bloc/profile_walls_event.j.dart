part of 'profile_walls_bloc.j.dart';

@freezed
abstract class ProfileWallsEvent with _$ProfileWallsEvent {
  const factory ProfileWallsEvent.started({required String email}) = _Started;
  const factory ProfileWallsEvent.refreshRequested() = _RefreshRequested;
  const factory ProfileWallsEvent.fetchMoreRequested() = _FetchMoreRequested;
}
