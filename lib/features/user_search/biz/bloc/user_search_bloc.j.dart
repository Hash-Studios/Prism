import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/features/user_search/domain/entities/user_search_user.dart';
import 'package:Prism/features/user_search/domain/usecases/search_users_usecase.dart';
import 'package:bloc/bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';

part 'user_search_event.j.dart';
part 'user_search_state.j.dart';
part 'user_search_bloc.j.freezed.dart';

@injectable
class UserSearchBloc extends Bloc<UserSearchEvent, UserSearchState> {
  UserSearchBloc(this._searchUsersUseCase) : super(UserSearchState.initial()) {
    on<_SearchRequested>(_onSearchRequested);
    on<_Cleared>(_onCleared);
  }

  final SearchUsersUseCase _searchUsersUseCase;

  Future<void> _onSearchRequested(_SearchRequested event, Emitter<UserSearchState> emit) async {
    emit(
      state.copyWith(
        status: LoadStatus.loading,
        actionStatus: ActionStatus.inProgress,
        query: event.query,
        failure: null,
      ),
    );

    final result = await _searchUsersUseCase(SearchUsersParams(query: event.query));

    result.fold(
      onSuccess: (users) => emit(
        state.copyWith(status: LoadStatus.success, actionStatus: ActionStatus.success, users: users, failure: null),
      ),
      onFailure: (failure) =>
          emit(state.copyWith(status: LoadStatus.failure, actionStatus: ActionStatus.failure, failure: failure)),
    );
  }

  void _onCleared(_Cleared event, Emitter<UserSearchState> emit) {
    emit(UserSearchState.initial());
  }
}
