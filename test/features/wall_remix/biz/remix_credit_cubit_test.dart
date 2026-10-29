import 'package:Prism/core/firestore/firestore_client.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/features/user_blocks/domain/repositories/user_block_repository.dart';
import 'package:Prism/features/wall_remix/biz/remix_credit_cubit.dart';
import 'package:Prism/features/wall_remix/data/wall_remix_repository.dart';
import 'package:Prism/features/wall_remix/domain/wall_remix.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../wall_remix_fixture.dart';

class _MockFirestoreClient extends Mock implements FirestoreClient {}

class _MockUserBlockRepository extends Mock implements UserBlockRepository {}

/// Answers the original lookup from [onFetchApproved].
class _ScriptedRepository extends WallRemixRepository {
  _ScriptedRepository(this.onFetchApproved) : super(_MockFirestoreClient(), _MockUserBlockRepository());

  final Future<PrismWallpaper?> Function(String docId) onFetchApproved;

  @override
  Future<PrismWallpaper?> fetchApprovedWall(String docId) => onFetchApproved(docId);

  @override
  Future<Set<String>> blockedCreatorUids({bool waitForInitialLoad = true}) async => const <String>{};
}

WallViewer _viewer({bool isPremium = true, Set<String> blocked = const <String>{}}) =>
    WallViewer(isPremium: isPremium, premiumCollections: const <String>['space'], blockedCreatorUids: blocked);

void main() {
  test('shows the original of a remix the viewer may open', () async {
    final PrismWallpaper original = remixWall(id: 'orig', docId: 'doc-orig');
    final RemixCreditCubit cubit = RemixCreditCubit(_ScriptedRepository((String docId) async => original));
    addTearDown(cubit.close);

    await cubit.load('doc-orig', viewer: _viewer());

    expect(cubit.state, isA<RemixCreditShown>());
    expect((cubit.state as RemixCreditShown).original, original);
  });

  test('hides the credit when the original is missing', () async {
    final RemixCreditCubit cubit = RemixCreditCubit(_ScriptedRepository((String docId) async => null));
    addTearDown(cubit.close);

    await cubit.load('doc-orig', viewer: _viewer());

    expect(cubit.state, isA<RemixCreditHidden>());
  });

  test('hides the credit when the original is premium-gated for a free viewer', () async {
    final RemixCreditCubit cubit = RemixCreditCubit(
      _ScriptedRepository(
        (String docId) async => remixWall(id: 'orig', docId: 'doc-orig', collections: const <String>['space']),
      ),
    );
    addTearDown(cubit.close);

    await cubit.load('doc-orig', viewer: _viewer(isPremium: false));

    expect(cubit.state, isA<RemixCreditHidden>());
  });

  test('hides the credit when the original creator is blocked', () async {
    final RemixCreditCubit cubit = RemixCreditCubit(
      _ScriptedRepository((String docId) async => remixWall(id: 'orig', docId: 'doc-orig')),
    );
    addTearDown(cubit.close);

    await cubit.load('doc-orig', viewer: _viewer(blocked: const <String>{'uid-asha'}));

    expect(cubit.state, isA<RemixCreditHidden>());
  });

  test('hides the credit when the lookup throws', () async {
    final RemixCreditCubit cubit = RemixCreditCubit(
      _ScriptedRepository((String docId) async => throw StateError('offline')),
    );
    addTearDown(cubit.close);

    await cubit.load('doc-orig', viewer: _viewer());

    expect(cubit.state, isA<RemixCreditHidden>());
  });
}
