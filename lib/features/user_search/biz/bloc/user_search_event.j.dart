part of 'user_search_bloc.j.dart';

@freezed
abstract class UserSearchEvent with _$UserSearchEvent {
  const factory UserSearchEvent.searchRequested({required String query}) = _SearchRequested;
  const factory UserSearchEvent.cleared() = _Cleared;
}
