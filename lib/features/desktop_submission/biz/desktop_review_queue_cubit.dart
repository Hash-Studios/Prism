import 'dart:async';

import 'package:Prism/features/desktop_submission/data/desktop_submission_repository.dart';
import 'package:Prism/features/desktop_submission/domain/entities/desktop_submission.dart';
import 'package:Prism/logger/logger.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'desktop_review_queue_cubit.freezed.dart';

enum DesktopReviewOutcome { done, wallUnavailable, failed }

/// Loading while [submissions] is null and [error] is false.
@freezed
abstract class DesktopReviewQueueState with _$DesktopReviewQueueState {
  const factory DesktopReviewQueueState({List<DesktopSubmission>? submissions, @Default(false) bool error}) =
      _DesktopReviewQueueState;
}

class DesktopReviewQueueCubit extends Cubit<DesktopReviewQueueState> {
  DesktopReviewQueueCubit(this._repository) : super(const DesktopReviewQueueState());

  final DesktopSubmissionRepository _repository;
  StreamSubscription<List<DesktopSubmission>>? _subscription;

  void start() => _subscribe();

  void retry() {
    emit(const DesktopReviewQueueState());
    _subscribe();
  }

  void _subscribe() {
    unawaited(_subscription?.cancel());
    _subscription = _repository.watchReviewQueue().listen(
      (List<DesktopSubmission> submissions) {
        if (!isClosed) emit(DesktopReviewQueueState(submissions: submissions));
      },
      onError: (Object _) {
        if (!isClosed) emit(const DesktopReviewQueueState(error: true));
      },
    );
  }

  Future<DesktopReviewOutcome> approve(DesktopSubmission submission) async {
    try {
      await _repository.review(submissionId: submission.id, approve: true);
      return DesktopReviewOutcome.done;
    } on DesktopReviewWallUnavailable {
      return DesktopReviewOutcome.wallUnavailable;
    } catch (error, stackTrace) {
      logger.e('Desktop version approve failed', tag: 'AdminReview', error: error, stackTrace: stackTrace);
      return DesktopReviewOutcome.failed;
    }
  }

  Future<void> reject(DesktopSubmission submission, {required String reason, required String reasonCode}) {
    return _repository.review(submissionId: submission.id, approve: false, reason: reason, reasonCode: reasonCode);
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    return super.close();
  }
}
