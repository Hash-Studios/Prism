part of 'user_search_bloc.dart';

@freezed
abstract class UserSearchEvent with _$UserSearchEvent {
  const factory UserSearchEvent.searchRequested({required String query}) =
      _SearchRequested;
  const factory UserSearchEvent.cleared() = _Cleared;
}
