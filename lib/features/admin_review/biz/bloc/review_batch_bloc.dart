import 'package:Prism/core/firestore/firestore_document.dart';
import 'package:Prism/features/admin_review/data/review_batch_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

part 'review_batch_event.dart';
part 'review_batch_state.dart';

enum ReviewAction { approve, reject, skip }

class UndoableAction {
  final FirestoreDocument wall;
  final ReviewAction action;
  final String? reason;

  const UndoableAction({required this.wall, required this.action, this.reason});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UndoableAction &&
          runtimeType == other.runtimeType &&
          wall.id == other.wall.id &&
          action == other.action &&
          reason == other.reason;

  @override
  int get hashCode => wall.id.hashCode ^ action.hashCode ^ reason.hashCode;
}

@injectable
class ReviewBatchBloc extends Bloc<ReviewBatchEvent, ReviewBatchState> {
  final ReviewBatchRepository _repository;

  static const int _batchSize = 20;
  static const int _maxUndoStack = 5;

  ReviewBatchBloc(this._repository) : super(const ReviewBatchState()) {
    on<ReviewBatchLoadRequested>(_onLoadRequested);
    on<ReviewBatchSwipeApproved>(_onSwipeApproved);
    on<ReviewBatchSwipeRejected>(_onSwipeRejected);
    on<ReviewBatchSwipeSkipped>(_onSwipeSkipped);
    on<ReviewBatchUndoRequested>(_onUndoRequested);
    on<ReviewBatchNextBatchRequested>(_onNextBatchRequested);
  }

  Future<void> _onLoadRequested(ReviewBatchLoadRequested event, Emitter<ReviewBatchState> emit) async {
    emit(state.copyWith(status: ReviewBatchStatus.loading));

    try {
      final walls = await _repository.fetchPendingWallsBatch(limit: _batchSize);

      if (walls.isNotEmpty) {
        await _repository.categorizeWalls(walls);
        final categorizedWalls = await _repository.fetchPendingWallsBatch(limit: _batchSize);

        emit(
          state.copyWith(
            status: ReviewBatchStatus.loaded,
            walls: categorizedWalls,
            currentIndex: 0,
            totalPending: await _repository.getPendingWallsCount(),
          ),
        );
      } else {
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
      await _repository.approveWall(currentWall);
      emit(
        state.copyWith(
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
    undoStack.add(UndoableAction(wall: currentWall, action: ReviewAction.reject, reason: event.reason));

    try {
      await _repository.rejectWall(currentWall, reason: event.reason);
      emit(
        state.copyWith(
          currentIndex: state.currentIndex + 1,
          undoStack: undoStack,
          totalPending: state.totalPending - 1,
        ),
      );
    } catch (e) {
      emit(state.copyWith(status: ReviewBatchStatus.error, errorMessage: 'Failed to reject: $e'));
    }
  }

  Future<void> _onSwipeSkipped(ReviewBatchSwipeSkipped event, Emitter<ReviewBatchState> emit) async {
    if (state.currentIndex >= state.walls.length) return;

    final currentWall = state.walls[state.currentIndex];
    final skippedStack = List<FirestoreDocument>.from(state.skippedStack);
    skippedStack.add(currentWall);

    emit(state.copyWith(currentIndex: state.currentIndex + 1, skippedStack: skippedStack));
  }

  Future<void> _onUndoRequested(ReviewBatchUndoRequested event, Emitter<ReviewBatchState> emit) async {
    if (state.undoStack.isEmpty) return;

    final undoStack = List<UndoableAction>.from(state.undoStack);
    final lastAction = undoStack.removeLast();

    try {
      if (lastAction.action == ReviewAction.approve) {
        await _repository.rejectWall(lastAction.wall, reason: 'Undo: approval reversed');
      } else if (lastAction.action == ReviewAction.reject) {
        await _repository.approveWall(lastAction.wall);
      }

      emit(
        state.copyWith(
          currentIndex: state.currentIndex > 0 ? state.currentIndex - 1 : 0,
          undoStack: undoStack,
          totalPending: state.totalPending + 1,
        ),
      );
    } catch (e) {
      emit(state.copyWith(status: ReviewBatchStatus.error, errorMessage: 'Failed to undo: $e'));
    }
  }

  Future<void> _onNextBatchRequested(ReviewBatchNextBatchRequested event, Emitter<ReviewBatchState> emit) async {
    if (state.currentIndex >= state.walls.length - 1) {
      emit(state.copyWith(status: ReviewBatchStatus.batchComplete));
      return;
    }

    final lastWallId = state.walls.last.id;
    emit(state.copyWith(status: ReviewBatchStatus.loading));

    try {
      final walls = await _repository.fetchPendingWallsBatch(limit: _batchSize, startAfterDocId: lastWallId);

      emit(
        state.copyWith(
          status: ReviewBatchStatus.loaded,
          walls: walls,
          currentIndex: 0,
          undoStack: const [],
          skippedStack: const [],
          totalPending: await _repository.getPendingWallsCount(),
        ),
      );
    } catch (e) {
      emit(state.copyWith(status: ReviewBatchStatus.error, errorMessage: e.toString()));
    }
  }
}
