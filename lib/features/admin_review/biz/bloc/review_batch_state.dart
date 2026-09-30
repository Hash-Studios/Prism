part of 'review_batch_bloc.dart';

enum ReviewBatchStatus { initial, loading, loaded, batchComplete, error }

class ReviewBatchState extends Equatable {
  final ReviewBatchStatus status;
  final List<FirestoreDocument> walls;
  final List<UndoableAction> undoStack;
  final int currentIndex;
  final int totalPending;
  final int undoCount;
  final String? errorMessage;

  const ReviewBatchState({
    this.status = ReviewBatchStatus.initial,
    this.walls = const [],
    this.undoStack = const [],
    this.currentIndex = 0,
    this.totalPending = 0,
    this.undoCount = 0,
    this.errorMessage,
  });

  bool get canUndo => undoStack.isNotEmpty;
  bool get hasMoreWalls => currentIndex < walls.length;
  FirestoreDocument? get currentWall => hasMoreWalls ? walls[currentIndex] : null;

  ReviewBatchState copyWith({
    ReviewBatchStatus? status,
    List<FirestoreDocument>? walls,
    List<UndoableAction>? undoStack,
    int? currentIndex,
    int? totalPending,
    int? undoCount,
    String? errorMessage,
  }) {
    return ReviewBatchState(
      status: status ?? this.status,
      walls: walls ?? this.walls,
      undoStack: undoStack ?? this.undoStack,
      currentIndex: currentIndex ?? this.currentIndex,
      totalPending: totalPending ?? this.totalPending,
      undoCount: undoCount ?? this.undoCount,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, walls, undoStack, currentIndex, totalPending, undoCount, errorMessage];
}
