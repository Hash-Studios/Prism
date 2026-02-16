part of 'profile_walls_bloc.dart';

@freezed
abstract class ProfileWallsState with _$ProfileWallsState {
  const factory ProfileWallsState({
    required LoadStatus status,
    required ActionStatus actionStatus,
    required String email,
    required List<ProfileWallEntity> items,
    required bool hasMore,
    required String? nextCursor,
    required bool isFetchingMore,
    Failure? failure,
  }) = _ProfileWallsState;

  factory ProfileWallsState.initial() => const ProfileWallsState(
        status: LoadStatus.initial,
        actionStatus: ActionStatus.idle,
        email: '',
        items: <ProfileWallEntity>[],
        hasMore: true,
        nextCursor: null,
        isFetchingMore: false,
      );
}
