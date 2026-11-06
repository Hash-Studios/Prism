import 'dart:typed_data';

import 'package:Prism/features/desktop_submission/desktop_submission.dart';

/// A pending desktop version with empty image URLs, so no test issues a network request.
DesktopSubmission desktopSubmission({String id = 'sub-1', String wallTitle = 'Harbour', bool replaces = false}) {
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
    wallTitle: wallTitle,
    creatorName: 'Creator',
    replaces: replaces,
    createdAt: DateTime.utc(2026, 11),
  );
}

class FakeDesktopSubmissionRepository implements DesktopSubmissionRepository {
  FakeDesktopSubmissionRepository({this.submissions = const <DesktopSubmission>[]});

  final List<DesktopSubmission> submissions;
  final List<({String submissionId, bool approve, String? reason, String? reasonCode})> reviews = [];

  /// Thrown by [review] when set.
  Object? reviewError;

  @override
  Stream<List<DesktopSubmission>> watchReviewQueue() => Stream<List<DesktopSubmission>>.value(submissions);

  @override
  Future<void> review({required String submissionId, required bool approve, String? reason, String? reasonCode}) async {
    reviews.add((submissionId: submissionId, approve: approve, reason: reason, reasonCode: reasonCode));
    if (reviewError != null) throw reviewError!;
  }

  @override
  Future<String> submit({required String wallDocId, required Uint8List bytes}) => throw UnimplementedError();

  @override
  Stream<bool> watchPendingForWall({required String wallDocId, required String uid}) => Stream<bool>.value(false);
}
