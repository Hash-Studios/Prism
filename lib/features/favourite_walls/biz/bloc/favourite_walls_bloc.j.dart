import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/features/favourite_walls/domain/entities/favourite_wall_entity.dart';
import 'package:Prism/features/favourite_walls/domain/usecases/favourite_walls_usecases.dart';
import 'package:bloc/bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';

part 'favourite_walls_event.j.dart';
part 'favourite_walls_state.j.dart';
part 'favourite_walls_bloc.j.freezed.dart';

@injectable
class FavouriteWallsBloc extends Bloc<FavouriteWallsEvent, FavouriteWallsState> {
  FavouriteWallsBloc(
    this._fetchFavouriteWallsUseCase,
    this._toggleFavouriteWallUseCase,
    this._removeFavouriteWallUseCase,
    this._clearFavouriteWallsUseCase,
  ) : super(FavouriteWallsState.initial()) {
    on<_Started>(_onStarted);
    on<_RefreshRequested>(_onRefreshRequested);
    on<_ToggleRequested>(_onToggleRequested);
    on<_RemoveRequested>(_onRemoveRequested);
    on<_ClearRequested>(_onClearRequested);
  }

  final FetchFavouriteWallsUseCase _fetchFavouriteWallsUseCase;
  final ToggleFavouriteWallUseCase _toggleFavouriteWallUseCase;
  final RemoveFavouriteWallUseCase _removeFavouriteWallUseCase;
  final ClearFavouriteWallsUseCase _clearFavouriteWallsUseCase;

  bool _containsWall(String wallId) {
    return state.items.any((item) => item.id == wallId);
  }

  List<FavouriteWallEntity> _upsertWall(FavouriteWallEntity wall) {
    final List<FavouriteWallEntity> next = <FavouriteWallEntity>[
      ...state.items.where((item) => item.id != wall.id),
      wall,
    ];
    next.sort((a, b) {
      final DateTime? aDate = a.createdAt;
      final DateTime? bDate = b.createdAt;
      if (aDate == null && bDate == null) return 0;
      if (aDate == null) return 1;
      if (bDate == null) return -1;
      return bDate.compareTo(aDate);
    });
    return next;
  }

  List<FavouriteWallEntity> _removeWall(String wallId) {
    return state.items.where((item) => item.id != wallId).toList(growable: false);
  }

  Future<void> _onStarted(_Started event, Emitter<FavouriteWallsState> emit) async {
    emit(
      state.copyWith(
        status: LoadStatus.loading,
        actionStatus: ActionStatus.inProgress,
        userId: event.userId,
        failure: null,
      ),
    );
    await _fetch(emit);
  }

  Future<void> _onRefreshRequested(_RefreshRequested event, Emitter<FavouriteWallsState> emit) {
    emit(state.copyWith(status: LoadStatus.loading, actionStatus: ActionStatus.inProgress));
    return _fetch(emit);
  }

  Future<void> _fetch(Emitter<FavouriteWallsState> emit) async {
    if (state.userId.isEmpty) {
      emit(
        state.copyWith(
          status: LoadStatus.failure,
          actionStatus: ActionStatus.failure,
          failure: const ValidationFailure('userId is required'),
        ),
      );
      return;
    }

    final result = await _fetchFavouriteWallsUseCase(FetchFavouriteWallsParams(userId: state.userId));

    result.fold(
      onSuccess: (items) => emit(
        state.copyWith(status: LoadStatus.success, actionStatus: ActionStatus.success, items: items, failure: null),
      ),
      onFailure: (failure) =>
          emit(state.copyWith(status: LoadStatus.failure, actionStatus: ActionStatus.failure, failure: failure)),
    );
  }

  Future<void> _onToggleRequested(_ToggleRequested event, Emitter<FavouriteWallsState> emit) async {
    emit(state.copyWith(actionStatus: ActionStatus.inProgress, failure: null));
    final bool currentlyFavourited = _containsWall(event.wall.id);
    final result = await _toggleFavouriteWallUseCase(
      ToggleFavouriteWallParams(userId: state.userId, wall: event.wall, currentlyFavourited: currentlyFavourited),
    );

    result.fold(
      onSuccess: (isNowFavourite) => emit(
        state.copyWith(
          status: LoadStatus.success,
          actionStatus: ActionStatus.success,
          items: isNowFavourite ? _upsertWall(event.wall) : _removeWall(event.wall.id),
          failure: null,
        ),
      ),
      onFailure: (failure) => emit(state.copyWith(actionStatus: ActionStatus.failure, failure: failure)),
    );
  }

  Future<void> _onRemoveRequested(_RemoveRequested event, Emitter<FavouriteWallsState> emit) async {
    emit(state.copyWith(actionStatus: ActionStatus.inProgress, failure: null));
    final result = await _removeFavouriteWallUseCase(
      RemoveFavouriteWallParams(userId: state.userId, wallId: event.wallId),
    );

    result.fold(
      onSuccess: (_) => emit(
        state.copyWith(
          status: LoadStatus.success,
          actionStatus: ActionStatus.success,
          items: _removeWall(event.wallId),
          failure: null,
        ),
      ),
      onFailure: (failure) => emit(state.copyWith(actionStatus: ActionStatus.failure, failure: failure)),
    );
  }

  Future<void> _onClearRequested(_ClearRequested event, Emitter<FavouriteWallsState> emit) async {
    emit(state.copyWith(actionStatus: ActionStatus.inProgress, failure: null));
    final result = await _clearFavouriteWallsUseCase(
      ClearFavouriteWallsParams(
        userId: state.userId,
        wallIds: state.items.map((item) => item.id).toList(growable: false),
      ),
    );

    result.fold(
      onSuccess: (_) => emit(
        state.copyWith(
          status: LoadStatus.success,
          actionStatus: ActionStatus.success,
          items: const <FavouriteWallEntity>[],
          failure: null,
        ),
      ),
      onFailure: (failure) => emit(state.copyWith(actionStatus: ActionStatus.failure, failure: failure)),
    );
  }
}
