import 'dart:typed_data';

import 'package:Prism/features/desktop_submission/biz/desktop_review_queue_cubit.dart';
import 'package:Prism/features/desktop_submission/data/desktop_submission_repository.dart';
import 'package:Prism/features/desktop_submission/domain/entities/desktop_submission.dart';
import 'package:flutter_test/flutter_test.dart';

DesktopSubmission _submission({String id = 'sub-1'}) {
  return DesktopSubmission(
    id: id,
    wallDocId: 'wall-1',
    shareId: 'wall-share-1',
    creatorUid: 'uid-1',
    state: DesktopSubmissionState.pending,
    reason: null,
    thumbUrl: '',
    sourceWidth: 2560,
    sourceHeight: 1600,
    aspect: '16:10',
    wallThumb: '',
    wallTitle: 'Harbour',
    creatorName: 'Creator',
    replaces: false,
    createdAt: DateTime.utc(2026, 11),
  );
}

class _FakeRepo implements DesktopSubmissionRepository {
  final List<Stream<List<DesktopSubmission>>> queueStreams = <Stream<List<DesktopSubmission>>>[];
  final List<({String submissionId, bool approve, String? reason, String? reasonCode})> reviews = [];
  Object? reviewError;

  @override
  Stream<List<DesktopSubmission>> watchReviewQueue() => queueStreams.removeAt(0);

  @override
  Future<void> review({required String submissionId, required bool approve, String? reason, String? reasonCode}) async {
    reviews.add((submissionId: submissionId, approve: approve, reason: reason, reasonCode: reasonCode));
    final Object? error = reviewError;
    if (error != null) throw error;
  }

  @override
  Future<String> submit({required String wallDocId, required Uint8List bytes}) => throw UnimplementedError();

  @override
  Stream<bool> watchPendingForWall({required String wallDocId, required String uid}) => throw UnimplementedError();
}

void main() {
  test('starts loading and then shows the queued submissions', () async {
    final _FakeRepo repo = _FakeRepo()
      ..queueStreams.add(Stream<List<DesktopSubmission>>.value(<DesktopSubmission>[_submission()]));
    final DesktopReviewQueueCubit cubit = DesktopReviewQueueCubit(repo);

    expect(cubit.state.submissions, isNull);
    expect(cubit.state.error, isFalse);

    cubit.start();
    await Future<void>.delayed(Duration.zero);

    expect(cubit.state.submissions?.map((DesktopSubmission s) => s.id), <String>['sub-1']);
    expect(cubit.state.error, isFalse);
    await cubit.close();
  });

  test('a queue error shows the error and retry loads again', () async {
    final _FakeRepo repo = _FakeRepo()
      ..queueStreams.add(Stream<List<DesktopSubmission>>.error(Exception('queue failed')))
      ..queueStreams.add(Stream<List<DesktopSubmission>>.value(<DesktopSubmission>[_submission()]));
    final DesktopReviewQueueCubit cubit = DesktopReviewQueueCubit(repo);

    cubit.start();
    await Future<void>.delayed(Duration.zero);
    expect(cubit.state.error, isTrue);

    cubit.retry();
    expect(cubit.state.error, isFalse);
    expect(cubit.state.submissions, isNull);
    await Future<void>.delayed(Duration.zero);

    expect(cubit.state.error, isFalse);
    expect(cubit.state.submissions?.single.id, 'sub-1');
    await cubit.close();
  });

  test('approve reports done when the review goes through', () async {
    final _FakeRepo repo = _FakeRepo();
    final DesktopReviewQueueCubit cubit = DesktopReviewQueueCubit(repo);

    final DesktopReviewOutcome outcome = await cubit.approve(_submission());

    expect(outcome, DesktopReviewOutcome.done);
    expect(repo.reviews.single.submissionId, 'sub-1');
    expect(repo.reviews.single.approve, isTrue);
    await cubit.close();
  });

  test('approve reports wallUnavailable when the wall is no longer approved', () async {
    final _FakeRepo repo = _FakeRepo()..reviewError = const DesktopReviewWallUnavailable();
    final DesktopReviewQueueCubit cubit = DesktopReviewQueueCubit(repo);

    final DesktopReviewOutcome outcome = await cubit.approve(_submission());

    expect(outcome, DesktopReviewOutcome.wallUnavailable);
    await cubit.close();
  });

  test('approve reports failed for any other error', () async {
    final _FakeRepo repo = _FakeRepo()..reviewError = Exception('network');
    final DesktopReviewQueueCubit cubit = DesktopReviewQueueCubit(repo);

    final DesktopReviewOutcome outcome = await cubit.approve(_submission());

    expect(outcome, DesktopReviewOutcome.failed);
    await cubit.close();
  });

  test('reject passes the reason and reason code and rethrows errors', () async {
    final _FakeRepo repo = _FakeRepo();
    final DesktopReviewQueueCubit cubit = DesktopReviewQueueCubit(repo);

    await cubit.reject(_submission(), reason: 'Too blurry', reasonCode: 'blurry');

    expect(repo.reviews.single.approve, isFalse);
    expect(repo.reviews.single.reason, 'Too blurry');
    expect(repo.reviews.single.reasonCode, 'blurry');

    repo.reviewError = Exception('reject failed');
    await expectLater(
      cubit.reject(_submission(), reason: 'Too blurry', reasonCode: 'blurry'),
      throwsA(isA<Exception>()),
    );
    await cubit.close();
  });
}
