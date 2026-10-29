import 'dart:async';

import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/rating/rate_prompt_service.dart';
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
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
    this._clearFavouriteWallsUseCase,
    this._setFavouritePinUseCase,
  ) : super(FavouriteWallsState.initial()) {
    on<_Started>((event, emit) => _serial(() => _onStarted(event, emit)));
    on<_Synced>(_onSynced);
    on<_RefreshRequested>((event, emit) => _serial(() => _onRefreshRequested(event, emit)));
    on<_ToggleRequested>((event, emit) => _serial(() => _onToggleRequested(event, emit)));
    on<_ClearRequested>((event, emit) => _serial(() => _onClearRequested(event, emit)));
    on<_SortChanged>((event, emit) => emit(state.copyWith(sort: event.sort)));
    on<_SourceFilterChanged>((event, emit) => emit(state.copyWith(sourceFilter: event.source)));
    on<_QueryChanged>((event, emit) => emit(state.copyWith(query: event.query)));
    on<_RemoveRequested>((event, emit) => _serial(() => _onRemoveRequested(event, emit)));
    on<_RestoreRequested>((event, emit) => _serial(() => _onRestoreRequested(event, emit)));
    on<_PinRequested>((event, emit) => _serial(() => _onPinRequested(event, emit)));
  }

  final FetchFavouriteWallsUseCase _fetchFavouriteWallsUseCase;
  final ToggleFavouriteWallUseCase _toggleFavouriteWallUseCase;
  final ClearFavouriteWallsUseCase _clearFavouriteWallsUseCase;
  final SetFavouritePinUseCase _setFavouritePinUseCase;

  Future<void> _queueTail = Future<void>.value();

  /// Loads and mutations share one queue, so a refresh cannot interleave with a removal or an undo.
  Future<void> _serial(Future<void> Function() action) async {
    final Future<void> previous = _queueTail;
    final Completer<void> done = Completer<void>();
    _queueTail = done.future;
    await previous;
    try {
      await action();
    } finally {
      done.complete();
    }
  }

  bool _containsWall(String wallId) {
    return state.items.any((item) => item.id == wallId);
  }

  List<FavouriteWallEntity> _upsertWall(FavouriteWallEntity wall) {
    final List<FavouriteWallEntity> next = <FavouriteWallEntity>[
      ...state.items.where((item) => item.id != wall.id),
      wall,
    ];
    next.sort(compareByCreatedAtDesc);
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
    await _fetch(emit, event.operationId);
  }

  void _onSynced(_Synced event, Emitter<FavouriteWallsState> emit) {
    emit(
      state.copyWith(
        status: LoadStatus.success,
        userId: event.userId,
        items: <FavouriteWallEntity>[...event.items]..sort(compareByCreatedAtDesc),
        failure: null,
      ),
    );
  }

  Future<void> _onRefreshRequested(_RefreshRequested event, Emitter<FavouriteWallsState> emit) {
    emit(state.copyWith(status: LoadStatus.loading, actionStatus: ActionStatus.inProgress));
    return _fetch(emit, event.operationId);
  }

  Future<void> _fetch(Emitter<FavouriteWallsState> emit, [int? operationId]) async {
    final result = await _fetchFavouriteWallsUseCase(FetchFavouriteWallsParams(userId: state.userId));

    result.fold(
      onSuccess: (items) => emit(
        state.copyWith(
          status: LoadStatus.success,
          actionStatus: ActionStatus.success,
          items: items,
          completedOperationId: operationId ?? state.completedOperationId,
          failure: null,
        ),
      ),
      onFailure: (failure) => emit(
        state.copyWith(
          status: LoadStatus.failure,
          actionStatus: ActionStatus.failure,
          completedOperationId: operationId ?? state.completedOperationId,
          failure: failure,
        ),
      ),
    );
  }

  Future<void> _onToggleRequested(_ToggleRequested event, Emitter<FavouriteWallsState> emit) async {
    emit(state.copyWith(actionStatus: ActionStatus.inProgress, failure: null));
    final bool currentlyFavourited = event.desired == null ? _containsWall(event.wall.id) : !event.desired!;
    final FavouriteWallEntity wall = currentlyFavourited
        ? event.wall
        : event.wall.withFavouritedAt(DateTime.now().toUtc());
    final result = await _toggleFavouriteWallUseCase(
      ToggleFavouriteWallParams(userId: state.userId, wall: wall, currentlyFavourited: currentlyFavourited),
    );

    result.fold(
      onSuccess: (isNowFavourite) {
        emit(
          state.copyWith(
            status: LoadStatus.success,
            actionStatus: ActionStatus.success,
            items: isNowFavourite
                ? _upsertWall(wall.withSyncStatus(FavouriteSyncStatus.pending))
                : _removeWall(wall.id),
            completedOperationId: event.operationId,
            failure: null,
          ),
        );
        if (isNowFavourite) unawaited(RatePromptService.instance.maybePrompt(RatePromptTrigger.favourite));
      },
      onFailure: (failure) => emit(
        state.copyWith(actionStatus: ActionStatus.failure, completedOperationId: event.operationId, failure: failure),
      ),
    );
  }

  Future<void> _onClearRequested(_ClearRequested event, Emitter<FavouriteWallsState> emit) async {
    emit(state.copyWith(actionStatus: ActionStatus.inProgress, failure: null));
    // Clear what the server holds now, not what this device last loaded. If the server cannot be read, clear nothing.
    final fetched = await _fetchFavouriteWallsUseCase(FetchFavouriteWallsParams(userId: state.userId));
    final List<FavouriteWallEntity>? current = fetched.data;
    if (current == null) {
      emit(
        state.copyWith(
          actionStatus: ActionStatus.failure,
          completedOperationId: event.operationId,
          failure: fetched.failure,
        ),
      );
      return;
    }
    await _removeAndRefetchOnFailure(
      current.map((item) => item.id).toList(growable: false),
      emit,
      operationId: event.operationId,
    );
  }

  Future<void> _onRemoveRequested(_RemoveRequested event, Emitter<FavouriteWallsState> emit) {
    return _removeAndRefetchOnFailure(event.wallIds, emit, operationId: event.operationId);
  }

  Future<void> _removeAndRefetchOnFailure(
    List<String> wallIds,
    Emitter<FavouriteWallsState> emit, {
    int operationId = 0,
  }) async {
    emit(state.copyWith(actionStatus: ActionStatus.inProgress, failure: null));
    final result = await _clearFavouriteWallsUseCase(ClearFavouriteWallsParams(userId: state.userId, wallIds: wallIds));

    final bool removed = result.fold(
      onSuccess: (_) {
        final Set<String> removedIds = wallIds.toSet();
        emit(
          state.copyWith(
            status: LoadStatus.success,
            actionStatus: ActionStatus.success,
            items: state.items.where((item) => !removedIds.contains(item.id)).toList(growable: false),
            completedOperationId: operationId,
            failure: null,
          ),
        );
        return true;
      },
      onFailure: (failure) {
        emit(state.copyWith(actionStatus: ActionStatus.failure, completedOperationId: operationId, failure: failure));
        return false;
      },
    );
    if (!removed) await _fetch(emit);
  }

  Future<void> _onRestoreRequested(_RestoreRequested event, Emitter<FavouriteWallsState> emit) async {
    emit(state.copyWith(actionStatus: ActionStatus.inProgress, failure: null));
    final List<FavouriteWallEntity> restored = <FavouriteWallEntity>[];
    for (final FavouriteWallEntity original in event.walls) {
      if (_containsWall(original.id) || restored.any((item) => item.id == original.id)) continue;
      // A removed favourite lost its pin, so the undo brings it back unpinned.
      final FavouriteWallEntity wall = original
          .withFavouritedAt(original.favouritedAt ?? original.createdAt ?? DateTime.now().toUtc())
          .withPinnedAt(null);
      final result = await _toggleFavouriteWallUseCase(
        ToggleFavouriteWallParams(userId: state.userId, wall: wall, currentlyFavourited: false),
      );
      if (result.isSuccess) restored.add(wall.withSyncStatus(FavouriteSyncStatus.pending));
    }
    final List<FavouriteWallEntity> next = <FavouriteWallEntity>[...state.items, ...restored]
      ..sort(compareByCreatedAtDesc);
    final bool allRestored = restored.length == event.walls.length;
    emit(
      state.copyWith(
        items: next,
        actionStatus: allRestored ? ActionStatus.success : ActionStatus.failure,
        completedOperationId: event.operationId,
        failure: allRestored ? null : const ServerFailure('Could not restore some favourites'),
      ),
    );
  }

  Future<void> _onPinRequested(_PinRequested event, Emitter<FavouriteWallsState> emit) async {
    final FavouriteWallEntity? wall = state.items.where((item) => item.id == event.wallId).firstOrNull;
    if (wall == null) {
      emit(
        state.copyWith(
          actionStatus: ActionStatus.failure,
          completedOperationId: event.operationId,
          failure: const ValidationFailure('This wall is not a favourite.'),
        ),
      );
      return;
    }
    if (wall.pinned == event.pinned) {
      emit(state.copyWith(actionStatus: ActionStatus.success, completedOperationId: event.operationId, failure: null));
      return;
    }
    if (event.pinned && state.pinnedCount >= maxPinnedFavourites) {
      emit(
        state.copyWith(
          actionStatus: ActionStatus.failure,
          completedOperationId: event.operationId,
          failure: const FavouritePinLimitFailure(),
        ),
      );
      return;
    }
    emit(state.copyWith(actionStatus: ActionStatus.inProgress, failure: null));
    final DateTime? pinnedAt = event.pinned ? DateTime.now().toUtc() : null;
    final result = await _setFavouritePinUseCase(
      SetFavouritePinParams(userId: state.userId, wall: wall, pinnedAt: pinnedAt),
    );
    result.fold(
      onSuccess: (_) => emit(
        state.copyWith(
          actionStatus: ActionStatus.success,
          items: <FavouriteWallEntity>[
            for (final FavouriteWallEntity item in state.items) item.id == wall.id ? item.withPinnedAt(pinnedAt) : item,
          ],
          completedOperationId: event.operationId,
          failure: null,
        ),
      ),
      onFailure: (failure) => emit(
        state.copyWith(actionStatus: ActionStatus.failure, completedOperationId: event.operationId, failure: failure),
      ),
    );
  }
}

/// The user already pinned [maxPinnedFavourites] walls.
class FavouritePinLimitFailure extends ValidationFailure {
  const FavouritePinLimitFailure() : super('Pinned favourites are at the limit.');
}
