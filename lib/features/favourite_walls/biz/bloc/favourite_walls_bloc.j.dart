import 'dart:async';

import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/rating/rate_prompt_service.dart';
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/features/favourite_walls/domain/entities/favourite_wall_entity.dart';
import 'package:Prism/features/favourite_walls/domain/usecases/favourite_walls_usecases.dart';
import 'package:Prism/logger/logger.dart';
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
    on<_Started>((event, emit) => _serial(() => _onStarted(event, emit), emit, event.operationId, isLoad: true));
    on<_Synced>(_onSynced);
    on<_RefreshRequested>(
      (event, emit) => _serial(() => _onRefreshRequested(event, emit), emit, event.operationId, isLoad: true),
    );
    on<_ToggleRequested>((event, emit) => _serial(() => _onToggleRequested(event, emit), emit, event.operationId));
    on<_ClearRequested>((event, emit) => _serial(() => _onClearRequested(event, emit), emit, event.operationId));
    on<_SortChanged>((event, emit) => emit(state.copyWith(sort: event.sort)));
    on<_SourceFilterChanged>((event, emit) => emit(state.copyWith(sourceFilter: event.source)));
    on<_QueryChanged>((event, emit) => emit(state.copyWith(query: event.query)));
    on<_RemoveRequested>((event, emit) => _serial(() => _onRemoveRequested(event, emit), emit, event.operationId));
    on<_RestoreRequested>((event, emit) => _serial(() => _onRestoreRequested(event, emit), emit, event.operationId));
    on<_PinRequested>((event, emit) => _serial(() => _onPinRequested(event, emit), emit, event.operationId));
  }

  final FetchFavouriteWallsUseCase _fetchFavouriteWallsUseCase;
  final ToggleFavouriteWallUseCase _toggleFavouriteWallUseCase;
  final ClearFavouriteWallsUseCase _clearFavouriteWallsUseCase;
  final SetFavouritePinUseCase _setFavouritePinUseCase;

  Future<void> _queueTail = Future<void>.value();
  int _accountGeneration = 0;

  /// Loads and mutations share one queue, so a refresh cannot interleave with a removal or an undo.
  Future<void> _serial(
    Future<void> Function() action,
    Emitter<FavouriteWallsState> emit,
    int operationId, {
    bool isLoad = false,
  }) async {
    final Future<void> previous = _queueTail;
    final Completer<void> done = Completer<void>();
    _queueTail = done.future;
    await previous;
    try {
      await action();
    } catch (error, stackTrace) {
      addError(error, stackTrace);
      logger.e('FavouriteWallsBloc handler failed', error: error, stackTrace: stackTrace);
      if (!emit.isDone) {
        emit(
          state.copyWith(
            status: isLoad ? LoadStatus.failure : state.status,
            actionStatus: ActionStatus.failure,
            completedOperationId: operationId,
            failure: UnknownFailure('Favourite update failed: $error'),
          ),
        );
      }
    } finally {
      done.complete();
    }
  }

  bool _containsWall(String key) {
    return state.items.any((item) => item.key == key);
  }

  List<FavouriteWallEntity> _upsertWall(FavouriteWallEntity wall) {
    final List<FavouriteWallEntity> next = <FavouriteWallEntity>[
      ...state.items.where((item) => item.key != wall.key),
      wall,
    ];
    next.sort(compareByCreatedAtDesc);
    return next;
  }

  List<FavouriteWallEntity> _removeWall(String key) {
    return state.items.where((item) => item.key != key).toList(growable: false);
  }

  Future<void> _onStarted(_Started event, Emitter<FavouriteWallsState> emit) async {
    final bool accountChanged = state.userId != event.userId;
    if (accountChanged) _accountGeneration++;
    emit(
      state.copyWith(
        items: accountChanged ? const <FavouriteWallEntity>[] : state.items,
        status: LoadStatus.loading,
        actionStatus: ActionStatus.inProgress,
        userId: event.userId,
        failure: null,
      ),
    );
    await _fetch(emit, event.operationId);
  }

  void _onSynced(_Synced event, Emitter<FavouriteWallsState> emit) {
    if (state.userId != event.userId) _accountGeneration++;
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
    final int accountGeneration = _accountGeneration;
    final result = await _fetchFavouriteWallsUseCase(FetchFavouriteWallsParams(userId: state.userId));
    if (accountGeneration != _accountGeneration) return;

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
    final bool currentlyFavourited = event.desired == null ? _containsWall(event.wall.key) : !event.desired!;
    final FavouriteWallEntity wall = currentlyFavourited
        ? event.wall
        : event.wall.withFavouritedAt(DateTime.now().toUtc()).withPinnedAt(null);
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
                : _removeWall(wall.key),
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
      current.map((item) => item.key).toList(growable: false),
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
            items: state.items.where((item) => !removedIds.contains(item.key)).toList(growable: false),
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
      if (_containsWall(original.key) || restored.any((item) => item.key == original.key)) continue;
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
    final String userId = state.userId;
    final int accountGeneration = _accountGeneration;
    final FavouriteWallEntity? wall = state.items.where((item) => item.key == event.wallId).firstOrNull;
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
    final result = await _setFavouritePinUseCase(SetFavouritePinParams(userId: userId, wall: wall, pinnedAt: pinnedAt));
    if (userId != state.userId || accountGeneration != _accountGeneration) {
      emit(
        state.copyWith(
          actionStatus: ActionStatus.failure,
          completedOperationId: event.operationId,
          failure: const ValidationFailure('The account changed during this pin update.'),
        ),
      );
      return;
    }
    result.fold(
      onSuccess: (_) => emit(
        state.copyWith(
          actionStatus: ActionStatus.success,
          items: <FavouriteWallEntity>[
            for (final FavouriteWallEntity item in state.items)
              item.key == wall.key ? item.withPinnedAt(pinnedAt) : item,
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
