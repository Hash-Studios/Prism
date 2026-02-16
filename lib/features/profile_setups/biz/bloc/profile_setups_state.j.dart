part of 'profile_setups_bloc.j.dart';

@freezed
abstract class ProfileSetupsState with _$ProfileSetupsState {
  const factory ProfileSetupsState({
    required LoadStatus status,
    required ActionStatus actionStatus,
    required String email,
    required List<ProfileSetupEntity> items,
    required bool hasMore,
    required String? nextCursor,
    required bool isFetchingMore,
    Failure? failure,
  }) = _ProfileSetupsState;

  factory ProfileSetupsState.initial() => const ProfileSetupsState(
        status: LoadStatus.initial,
        actionStatus: ActionStatus.idle,
        email: '',
        items: <ProfileSetupEntity>[],
        hasMore: true,
        nextCursor: null,
        isFetchingMore: false,
      );
}
