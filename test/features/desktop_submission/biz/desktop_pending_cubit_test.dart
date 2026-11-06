import 'dart:async';
import 'dart:typed_data';

import 'package:Prism/features/desktop_submission/biz/desktop_pending_cubit.dart';
import 'package:Prism/features/desktop_submission/data/desktop_submission_repository.dart';
import 'package:Prism/features/desktop_submission/domain/entities/desktop_submission.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeRepo implements DesktopSubmissionRepository {
  _FakeRepo(this.pending);

  final Stream<bool> pending;

  @override
  Stream<bool> watchPendingForWall({required String wallDocId, required String uid}) => pending;

  @override
  Future<String> submit({required String wallDocId, required Uint8List bytes}) => throw UnimplementedError();

  @override
  Stream<List<DesktopSubmission>> watchReviewQueue() => throw UnimplementedError();

  @override
  Future<void> review({required String submissionId, required bool approve, String? reason, String? reasonCode}) =>
      throw UnimplementedError();
}

void main() {
  test('reports a pending version for the wall', () async {
    final DesktopPendingCubit cubit = DesktopPendingCubit(
      _FakeRepo(Stream<bool>.value(true)),
      wallDocId: 'wall_1',
      uid: 'uid_1',
    );
    await Future<void>.delayed(Duration.zero);

    expect(cubit.state, isTrue);
    await cubit.close();
  });

  test('reports no pending version for the wall', () async {
    final DesktopPendingCubit cubit = DesktopPendingCubit(
      _FakeRepo(Stream<bool>.value(false)),
      wallDocId: 'wall_1',
      uid: 'uid_1',
    );
    await Future<void>.delayed(Duration.zero);

    expect(cubit.state, isFalse);
    await cubit.close();
  });

  test('a watch error reads as not pending', () async {
    final StreamController<bool> controller = StreamController<bool>();
    final DesktopPendingCubit cubit = DesktopPendingCubit(
      _FakeRepo(controller.stream),
      wallDocId: 'wall_1',
      uid: 'uid_1',
    );
    controller.add(true);
    await Future<void>.delayed(Duration.zero);
    expect(cubit.state, isTrue);

    controller.addError(Exception('watch failed'));
    await Future<void>.delayed(Duration.zero);

    expect(cubit.state, isFalse);
    await cubit.close();
    await controller.close();
  });

  test('a null repository reads as not pending', () async {
    final DesktopPendingCubit cubit = DesktopPendingCubit(null, wallDocId: 'wall_1', uid: 'uid_1');

    expect(cubit.state, isFalse);
    await cubit.close();
  });
}
