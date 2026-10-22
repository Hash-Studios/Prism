import 'package:Prism/core/firestore/firestore_document.dart';
import 'package:Prism/core/wallpaper/wall_depth.dart';
import 'package:Prism/features/admin_review/biz/depth_override.dart';
import 'package:Prism/features/admin_review/biz/drop_reserve.dart';
import 'package:Prism/features/admin_review/data/admin_moderation_repository.dart';
import 'package:Prism/features/admin_review/data/review_batch_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

part 'review_batch_event.dart';
part 'review_batch_state.dart';

enum ReviewAction { approve, reject, reserve }

class UndoableAction {
  final FirestoreDocument wall;
  final ReviewAction action;

  const UndoableAction({required this.wall, required this.action});
}

@injectable
class ReviewBatchBloc extends Bloc<ReviewBatchEvent, ReviewBatchState> {
  final ReviewBatchRepository _repository;
  final AdminModerationRepository _moderation;

  static const int _maxUndoStack = 5;
  String? _lastWallId;

  ReviewBatchBloc(this._repository, this._moderation) : super(const ReviewBatchState()) {
    on<ReviewBatchLoadRequested>((event, emit) => _exclusive(event, emit, _onLoadRequested));
    on<ReviewBatchSwipeApproved>((event, emit) => _exclusive(event, emit, _onSwipeApproved));
    on<ReviewBatchSwipeRejected>((event, emit) => _exclusive(event, emit, _onSwipeRejected));
    on<ReviewBatchSwipeReserved>((event, emit) => _exclusive(event, emit, _onSwipeReserved));
    // One write at a time and in order, so two quick picks cannot reach Firestore the wrong way round.
    on<ReviewBatchDepthChanged>(
      (event, emit) => _exclusive(event, emit, _onDepthChanged),
      transformer: (events, mapper) => events.asyncExpand(mapper),
    );
    on<ReviewBatchSwipeSkipped>((event, emit) => _exclusive(event, emit, _onSwipeSkipped));
    on<ReviewBatchUndoRequested>((event, emit) => _exclusive(event, emit, _onUndoRequested));
    on<ReviewBatchNextBatchRequested>((event, emit) => _exclusive(event, emit, _onNextBatchRequested));
  }

  Future<void> _exclusive<E extends ReviewBatchEvent>(
    E event,
    Emitter<ReviewBatchState> emit,
    Future<void> Function(E, Emitter<ReviewBatchState>) action,
  ) async {
    // One guard across event types. Repeated input belongs to the displayed wall, not the next wall.
    if (state.isBusy) return;
    emit(state.copyWith(isBusy: true));
    try {
      await action(event, emit);
    } finally {
      if (!emit.isDone) emit(state.copyWith(isBusy: false));
    }
  }

  Future<void> _onLoadRequested(ReviewBatchLoadRequested event, Emitter<ReviewBatchState> emit) async {
    emit(state.copyWith(status: ReviewBatchStatus.loading));

    try {
      final walls = await _repository.fetchPendingWallsBatch();

      if (walls.isNotEmpty) {
        await _repository.categorizeWalls(walls);
        final categorizedWalls = await _repository.fetchPendingWallsBatch();
        final totalPending = await _repository.getPendingWallsCount();
        _lastWallId = categorizedWalls.isEmpty ? null : categorizedWalls.last.id;

        emit(
          state.copyWith(
            status: ReviewBatchStatus.loaded,
            walls: categorizedWalls,
            currentIndex: 0,
            totalPending: totalPending,
          ),
        );
      } else {
        _lastWallId = null;
        emit(state.copyWith(status: ReviewBatchStatus.loaded, walls: walls, currentIndex: 0, totalPending: 0));
      }
    } catch (e) {
      emit(state.copyWith(status: ReviewBatchStatus.error, errorMessage: e.toString()));
    }
  }

  Future<void> _onSwipeApproved(ReviewBatchSwipeApproved event, Emitter<ReviewBatchState> emit) async {
    if (state.currentIndex >= state.walls.length) return;

    final currentWall = state.walls[state.currentIndex];
    final undoStack = List<UndoableAction>.from(state.undoStack);

    if (undoStack.length >= _maxUndoStack) {
      undoStack.removeAt(0);
    }
    undoStack.add(UndoableAction(wall: currentWall, action: ReviewAction.approve));

    try {
      await _moderation.approveWall(currentWall);
      emit(
        state.copyWith(
          status: ReviewBatchStatus.loaded,
          currentIndex: state.currentIndex + 1,
          undoStack: undoStack,
          totalPending: state.totalPending - 1,
        ),
      );
    } catch (e) {
      emit(state.copyWith(status: ReviewBatchStatus.error, errorMessage: 'Failed to approve: $e'));
    }
  }

  Future<void> _onSwipeRejected(ReviewBatchSwipeRejected event, Emitter<ReviewBatchState> emit) async {
    if (state.currentIndex >= state.walls.length) return;

    final currentWall = state.walls[state.currentIndex];
    final undoStack = List<UndoableAction>.from(state.undoStack);

    if (undoStack.length >= _maxUndoStack) {
      undoStack.removeAt(0);
    }
    undoStack.add(UndoableAction(wall: currentWall, action: ReviewAction.reject));

    try {
      await _moderation.rejectWall(currentWall, reason: event.reason);
      emit(
        state.copyWith(
          status: ReviewBatchStatus.loaded,
          currentIndex: state.currentIndex + 1,
          undoStack: undoStack,
          totalPending: state.totalPending - 1,
        ),
      );
    } catch (e) {
      emit(state.copyWith(status: ReviewBatchStatus.error, errorMessage: 'Failed to reject: $e'));
    }
  }

  Future<void> _onSwipeReserved(ReviewBatchSwipeReserved event, Emitter<ReviewBatchState> emit) async {
    if (state.currentIndex >= state.walls.length) return;

    final currentWall = state.walls[state.currentIndex];
    if (!canReserveForDrop(currentWall)) return;
    final undoStack = List<UndoableAction>.from(state.undoStack);

    if (undoStack.length >= _maxUndoStack) {
      undoStack.removeAt(0);
    }
    undoStack.add(UndoableAction(wall: currentWall, action: ReviewAction.reserve));

    try {
      await _moderation.reserveWallForDrop(currentWall);
      emit(
        state.copyWith(
          status: ReviewBatchStatus.loaded,
          currentIndex: state.currentIndex + 1,
          undoStack: undoStack,
          totalPending: state.totalPending - 1,
        ),
      );
    } catch (e) {
      emit(state.copyWith(status: ReviewBatchStatus.error, errorMessage: 'Failed to reserve: $e'));
    }
  }

  Future<void> _onDepthChanged(ReviewBatchDepthChanged event, Emitter<ReviewBatchState> emit) async {
    final int index = state.walls.indexWhere((candidate) => candidate.id == event.wallId);
    if (index < 0) return;
    final FirestoreDocument wall = state.walls[index];

    List<FirestoreDocument> replace(FirestoreDocument replacement) => <FirestoreDocument>[
      for (final FirestoreDocument candidate in state.walls)
        if (candidate.id == wall.id) replacement else candidate,
    ];

    emit(state.copyWith(walls: replace(withDepthOverride(wall, event.tier))));
    try {
      await _moderation.setDepthTier(wall, event.tier);
      if (state.status == ReviewBatchStatus.error) {
        emit(state.copyWith(status: ReviewBatchStatus.loaded, clearErrorMessage: true));
      }
    } catch (e) {
      emit(
        state.copyWith(
          status: ReviewBatchStatus.error,
          walls: replace(wall),
          errorMessage: 'Failed to set Depth Effect: $e',
        ),
      );
    }
  }

  Future<void> _onSwipeSkipped(ReviewBatchSwipeSkipped event, Emitter<ReviewBatchState> emit) async {
    if (state.currentIndex >= state.walls.length) return;

    emit(state.copyWith(currentIndex: state.currentIndex + 1));
  }

  Future<void> _onUndoRequested(ReviewBatchUndoRequested event, Emitter<ReviewBatchState> emit) async {
    if (state.undoStack.isEmpty) return;

    final undoStack = List<UndoableAction>.from(state.undoStack);
    final lastAction = undoStack.removeLast();

    try {
      switch (lastAction.action) {
        case ReviewAction.approve:
          await _moderation.undoApproveWall(lastAction.wall);
        case ReviewAction.reject:
          await _moderation.undoRejectWall(lastAction.wall);
        case ReviewAction.reserve:
          await _moderation.undoReserveWallForDrop(lastAction.wall);
      }

      final restoredIndex = state.walls.indexWhere((wall) => wall.id == lastAction.wall.id);
      emit(
        state.copyWith(
          status: ReviewBatchStatus.loaded,
          currentIndex: restoredIndex >= 0 ? restoredIndex : state.currentIndex,
          undoStack: undoStack,
          totalPending: state.totalPending + 1,
          undoCount: state.undoCount + 1,
        ),
      );
    } catch (e) {
      emit(state.copyWith(status: ReviewBatchStatus.error, errorMessage: 'Failed to undo: $e'));
    }
  }

  Future<void> _onNextBatchRequested(ReviewBatchNextBatchRequested event, Emitter<ReviewBatchState> emit) async {
    if (state.hasMoreWalls) return;

    final lastWallId = _lastWallId;
    emit(state.copyWith(status: ReviewBatchStatus.loading));

    try {
      final walls = await _repository.fetchPendingWallsBatch(startAfterDocId: lastWallId);
      final totalPending = await _repository.getPendingWallsCount();
      if (walls.isNotEmpty) _lastWallId = walls.last.id;

      emit(
        state.copyWith(
          status: ReviewBatchStatus.loaded,
          walls: walls,
          currentIndex: 0,
          undoStack: const [],
          totalPending: totalPending,
        ),
      );
    } catch (e) {
      emit(state.copyWith(status: ReviewBatchStatus.error, errorMessage: e.toString()));
    }
  }
}
