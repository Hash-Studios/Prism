part of 'review_batch_bloc.dart';

abstract class ReviewBatchEvent {
  const ReviewBatchEvent();
}

class ReviewBatchLoadRequested extends ReviewBatchEvent {
  const ReviewBatchLoadRequested();
}

class ReviewBatchSwipeApproved extends ReviewBatchEvent {
  const ReviewBatchSwipeApproved();
}

class ReviewBatchSwipeRejected extends ReviewBatchEvent {
  final String reason;
  const ReviewBatchSwipeRejected({this.reason = 'Does not meet community guidelines'});
}

class ReviewBatchSwipeReserved extends ReviewBatchEvent {
  const ReviewBatchSwipeReserved();
}

class ReviewBatchDepthChanged extends ReviewBatchEvent {
  final String wallId;
  final WallDepthTier tier;
  const ReviewBatchDepthChanged(this.wallId, this.tier);
}

class ReviewBatchSwipeSkipped extends ReviewBatchEvent {
  const ReviewBatchSwipeSkipped();
}

class ReviewBatchUndoRequested extends ReviewBatchEvent {
  const ReviewBatchUndoRequested();
}

class ReviewBatchNextBatchRequested extends ReviewBatchEvent {
  const ReviewBatchNextBatchRequested();
}
