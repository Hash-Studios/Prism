import 'dart:typed_data';

import 'package:Prism/features/desktop_submission/biz/desktop_upload_cubit.dart';
import 'package:Prism/features/desktop_submission/data/desktop_submission_repository.dart';
import 'package:Prism/features/desktop_submission/domain/desktop_submit_failure.dart';
import 'package:Prism/features/desktop_submission/domain/entities/desktop_submission.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeRepo implements DesktopSubmissionRepository {
  Object? submitError;

  @override
  Future<String> submit({required String wallDocId, required Uint8List bytes}) async {
    final Object? error = submitError;
    if (error != null) throw error;
    return 'sub_1';
  }

  @override
  Stream<bool> watchPendingForWall({required String wallDocId, required String uid}) => throw UnimplementedError();

  @override
  Stream<List<DesktopSubmission>> watchReviewQueue() => throw UnimplementedError();

  @override
  Future<void> review({required String submissionId, required bool approve, String? reason, String? reasonCode}) =>
      throw UnimplementedError();
}

final Uint8List _bytes = Uint8List.fromList(<int>[1, 2, 3]);

void main() {
  test('a successful submit marks the state sent without a failure', () async {
    final DesktopUploadCubit cubit = DesktopUploadCubit(_FakeRepo());

    await cubit.submit(wallDocId: 'wall_1', bytes: _bytes);

    expect(cubit.state.sent, isTrue);
    expect(cubit.state.failure, isNull);
    await cubit.close();
  });

  test('a rejected submit keeps the failure and stops sending', () async {
    final _FakeRepo repo = _FakeRepo()..submitError = const DesktopSubmitException(DesktopSubmitFailure.alreadyPending);
    final DesktopUploadCubit cubit = DesktopUploadCubit(repo);

    await cubit.submit(wallDocId: 'wall_1', bytes: _bytes);

    expect(cubit.state.failure, DesktopSubmitFailure.alreadyPending);
    expect(cubit.state.sending, isFalse);
    expect(cubit.state.sent, isFalse);
    await cubit.close();
  });

  test('clearFailure removes the server failure', () async {
    final _FakeRepo repo = _FakeRepo()..submitError = const DesktopSubmitException(DesktopSubmitFailure.failed);
    final DesktopUploadCubit cubit = DesktopUploadCubit(repo);
    await cubit.submit(wallDocId: 'wall_1', bytes: _bytes);

    cubit.clearFailure();

    expect(cubit.state.failure, isNull);
    await cubit.close();
  });

  test('a submit that finishes after close does not emit', () async {
    final DesktopUploadCubit cubit = DesktopUploadCubit(_FakeRepo());
    final Future<void> pending = cubit.submit(wallDocId: 'wall_1', bytes: _bytes);
    await cubit.close();

    await expectLater(pending, completes);
  });
}
