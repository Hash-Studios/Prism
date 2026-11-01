import 'package:Prism/features/admin_review/biz/bloc/wall_metadata_history_cubit.dart';
import 'package:Prism/features/wallpaper_upload/domain/entities/wall_metadata.dart';
import 'package:Prism/features/wallpaper_upload/domain/usecases/wall_metadata_actions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _Actions extends Mock implements WallMetadataActions {}

void main() {
  const snapshot = WallMetadataSnapshot(
    metadata: PendingWallMetadata(text: WallTextMetadata(title: 'After')),
    approved: true,
    revision: 'rev-1',
  );
  const audit = WallMetadataAudit(
    id: 'audit-1',
    before: {'title': 'Before'},
    after: {'title': 'After'},
    actorUid: 'creator',
    canRevert: true,
  );
  late _Actions actions;
  late WallMetadataHistoryCubit cubit;

  setUp(() {
    actions = _Actions();
    when(() => actions.load('doc', approved: true)).thenAnswer((_) async => snapshot);
    when(
      () => actions.listEdits('doc'),
    ).thenAnswer((_) async => const WallMetadataAuditPage(edits: [audit], cursor: 'next'));
    cubit = WallMetadataHistoryCubit(actions, wallDocId: 'doc');
  });
  tearDown(() => cubit.close());

  test('history obtains the current revision and supports bounded cursor paging', () async {
    await cubit.load();
    expect(cubit.state.edits.single.before, {'title': 'Before'});
    when(
      () => actions.listEdits('doc', cursor: 'next'),
    ).thenAnswer((_) async => const WallMetadataAuditPage(edits: []));
    await cubit.load(more: true);
    expect(cubit.state.edits, [audit]);
    expect(cubit.state.cursor, isNull);
    verify(() => actions.load('doc', approved: true)).called(1);
  });

  test('revert sends only selected audit and acquired revision, then refreshes history', () async {
    await cubit.load();
    when(
      () => actions.revert(
        'doc',
        'audit-1',
        revision: 'rev-1',
        operationId: any(named: 'operationId'),
      ),
    ).thenAnswer((_) async => snapshot);
    await cubit.revert(audit);
    expect(cubit.state.revertedCount, 1);
    verify(
      () => actions.revert(
        'doc',
        'audit-1',
        revision: 'rev-1',
        operationId: any(named: 'operationId'),
      ),
    ).called(1);
    verify(() => actions.listEdits('doc')).called(2);
  });

  test('stale revert preserves diff and requires reload instead of writing another audit', () async {
    await cubit.load();
    when(
      () => actions.revert(
        'doc',
        'audit-1',
        revision: 'rev-1',
        operationId: any(named: 'operationId'),
      ),
    ).thenThrow(const WallMetadataException(WallMetadataFailure.conflict));
    await cubit.revert(audit);
    expect(cubit.state.edits, [audit]);
    expect(cubit.state.failure, WallMetadataFailure.conflict);
    expect(cubit.state.revertedCount, 0);
    await cubit.revert(audit);
    verify(
      () => actions.revert(
        'doc',
        'audit-1',
        revision: 'rev-1',
        operationId: any(named: 'operationId'),
      ),
    ).called(1);
  });

  test('an older audit cannot be reverted through the Cubit', () async {
    await cubit.load();
    await cubit.revert(const WallMetadataAudit(id: 'old', before: {}, after: {}, actorUid: 'creator'));
    verifyNever(
      () => actions.revert(
        any(),
        any(),
        revision: any(named: 'revision'),
        operationId: any(named: 'operationId'),
      ),
    );
  });
}
