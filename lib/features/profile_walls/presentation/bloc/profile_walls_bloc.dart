import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/features/profile_walls/domain/entities/profile_wall_entity.dart';
import 'package:Prism/features/profile_walls/domain/usecases/profile_walls_usecases.dart';
import 'package:bloc/bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';

part 'profile_walls_event.dart';
part 'profile_walls_state.dart';
part 'profile_walls_bloc.freezed.dart';

@injectable
class ProfileWallsBloc extends Bloc<ProfileWallsEvent, ProfileWallsState> {
  ProfileWallsBloc(this._fetchProfileWallsUseCase)
      : super(ProfileWallsState.initial()) {
    on<_Started>(_onStarted);
    on<_RefreshRequested>(_onRefreshRequested);
    on<_FetchMoreRequested>(_onFetchMoreRequested);
  }

  final FetchProfileWallsUseCase _fetchProfileWallsUseCase;

  Future<void> _onStarted(
      _Started event, Emitter<ProfileWallsState> emit) async {
    emit(state.copyWith(email: event.email));
    await _load(refresh: true, emit: emit);
  }

  Future<void> _onRefreshRequested(
    _RefreshRequested event,
    Emitter<ProfileWallsState> emit,
  ) {
    return _load(refresh: true, emit: emit);
  }

  Future<void> _onFetchMoreRequested(
    _FetchMoreRequested event,
    Emitter<ProfileWallsState> emit,
  ) async {
    if (state.isFetchingMore || !state.hasMore) {
      return;
    }
    emit(state.copyWith(
        isFetchingMore: true, actionStatus: ActionStatus.inProgress));
    await _load(refresh: false, emit: emit);
  }

  Future<void> _load(
      {required bool refresh, required Emitter<ProfileWallsState> emit}) async {
    if (state.email.isEmpty) {
      emit(state.copyWith(
        status: LoadStatus.failure,
        actionStatus: ActionStatus.failure,
        failure: const ValidationFailure('email is required'),
      ));
      return;
    }

    if (refresh) {
      emit(state.copyWith(
          status: LoadStatus.loading, actionStatus: ActionStatus.inProgress));
    }

    final result = await _fetchProfileWallsUseCase(
      FetchProfileWallsParams(email: state.email, refresh: refresh),
    );

    result.fold(
      onSuccess: (page) {
        final merged = refresh
            ? page.items
            : <ProfileWallEntity>[...state.items, ...page.items];
        final deduped = <String, ProfileWallEntity>{
          for (final item in merged) item.id: item,
        }.values.toList(growable: false);

        emit(state.copyWith(
          status: LoadStatus.success,
          actionStatus: ActionStatus.success,
          items: deduped,
          hasMore: page.hasMore,
          nextCursor: page.nextCursor,
          isFetchingMore: false,
          failure: null,
        ));
      },
      onFailure: (failure) => emit(state.copyWith(
        status: LoadStatus.failure,
        actionStatus: ActionStatus.failure,
        isFetchingMore: false,
        failure: failure,
      )),
    );
  }
}
