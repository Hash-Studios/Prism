part of 'user_search_bloc.j.dart';

@freezed
abstract class UserSearchState with _$UserSearchState {
  const factory UserSearchState({
    required LoadStatus status,
    required ActionStatus actionStatus,
    required String query,
    required List<UserSearchUser> users,
    Failure? failure,
  }) = _UserSearchState;

  factory UserSearchState.initial() => const UserSearchState(
        status: LoadStatus.initial,
        actionStatus: ActionStatus.idle,
        query: '',
        users: <UserSearchUser>[],
      );
}
