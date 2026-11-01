import 'dart:async';

import 'package:Prism/core/firestore/firestore_client.dart';
import 'package:Prism/core/user_blocks/blocked_creators.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/features/user_blocks/domain/repositories/user_block_repository.dart';
import 'package:Prism/features/wall_remix/biz/remixes_cubit.dart';
import 'package:Prism/features/wall_remix/data/wall_remix_repository.dart';
import 'package:Prism/features/wall_remix/domain/wall_remix.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../wall_remix_fixture.dart';

class _MockFirestoreClient extends Mock implements FirestoreClient {}

class _MockUserBlockRepository extends Mock implements UserBlockRepository {}

/// Answers each call from the given closures and records the cursors that fetchRemixes received.
class _ScriptedRepository extends WallRemixRepository {
  _ScriptedRepository({required this.onFetchRemixes, required this.onFetchApproved})
    : super(_MockFirestoreClient(), _MockUserBlockRepository());

  final Future<List<PrismWallpaper>> Function(String originalDocId, String? startAfterDocId) onFetchRemixes;
  final Future<PrismWallpaper?> Function(String docId) onFetchApproved;
  final List<String?> cursors = <String?>[];

  @override
  Future<List<PrismWallpaper>> fetchRemixes(String originalDocId, {String? startAfterDocId}) {
    cursors.add(startAfterDocId);
    return onFetchRemixes(originalDocId, startAfterDocId);
  }

  @override
  Future<PrismWallpaper?> fetchApprovedWall(String docId) => onFetchApproved(docId);

  @override
  Future<BlockedCreators> loadBlockedCreators() async => KnownBlockedCreators(const <String>{});
}

WallViewer _viewer({Set<String> blocked = const <String>{}}) => WallViewer(
  isPremium: true,
  premiumCollections: const <String>['space'],
  blockedCreators: KnownBlockedCreators(blocked),
);

/// Serves the same fakes but reports the block list as not loaded.
class _UnknownBlocksRepository extends _ScriptedRepository {
  _UnknownBlocksRepository({required super.onFetchRemixes, required super.onFetchApproved});

  @override
  Future<BlockedCreators> loadBlockedCreators() async => const UnknownBlockedCreators();
}

List<PrismWallpaper> _page(String prefix, int count, {required String authorUid}) => <PrismWallpaper>[
  for (int i = 0; i < count; i++)
    remixWall(
      id: '$prefix-$i',
      docId: '$prefix-$i',
      authorName: 'Creator $prefix $i',
      authorEmail: '$prefix$i@example.com',
      authorUid: authorUid,
    ),
];

void main() {
  final PrismWallpaper original = remixWall(id: 'orig', docId: 'doc-orig', remixCount: 30);

  test('pages past hidden remixes until two visible ones are found', () async {
    final List<PrismWallpaper> firstPage = _page('blocked', WallRemixRepository.remixLimit, authorUid: 'uid-blocked');
    final List<PrismWallpaper> secondPage = <PrismWallpaper>[
      remixWall(id: 'c1', docId: 'c1-doc', authorName: 'Chloe', authorUid: 'uid-chloe'),
      remixWall(id: 'c2', docId: 'c2-doc', authorName: 'Dev', authorUid: 'uid-dev'),
    ];
    final _ScriptedRepository repository = _ScriptedRepository(
      onFetchRemixes: (String docId, String? cursor) async => cursor == null ? firstPage : secondPage,
      onFetchApproved: (String docId) async => original,
    );
    final RemixesCubit cubit = RemixesCubit(repository);
    addTearDown(cubit.close);

    await cubit.load(original, viewer: _viewer(blocked: const <String>{'uid-blocked'}));

    final RemixesState state = cubit.state;
    expect(state, isA<RemixesLoaded>());
    final RemixesLoaded loaded = state as RemixesLoaded;
    expect(loaded.remixes.map((PrismWallpaper wall) => wall.id), <String>['c1', 'c2']);
    expect(loaded.total, 30);
    expect(repository.cursors, <String?>[null, 'blocked-23']);
  });

  test('drops every remix with an author UID when the block list is unknown', () async {
    // The original needs no author UID: with an unknown block list, a wall that has one is never viewable.
    final PrismWallpaper ownerless = remixWall(id: 'orig', docId: 'doc-orig', remixCount: 30, authorUid: null);
    final _UnknownBlocksRepository repository = _UnknownBlocksRepository(
      onFetchRemixes: (String docId, String? cursor) async => <PrismWallpaper>[
        remixWall(id: 'uid-wall', docId: 'uid-wall-doc', authorName: 'Uma', authorUid: 'uid-uma'),
        remixWall(id: 'no-uid', docId: 'no-uid-doc', authorName: 'Anon', authorUid: null),
      ],
      onFetchApproved: (String docId) async => ownerless,
    );
    final RemixesCubit cubit = RemixesCubit(repository);
    addTearDown(cubit.close);

    await cubit.load(ownerless);

    final RemixesState state = cubit.state;
    expect(state, isA<RemixesLoaded>());
    expect((state as RemixesLoaded).remixes.map((PrismWallpaper wall) => wall.id), <String>['no-uid']);
  });

  test('emits empty when there are no remixes', () async {
    final _ScriptedRepository repository = _ScriptedRepository(
      onFetchRemixes: (String docId, String? cursor) async => const <PrismWallpaper>[],
      onFetchApproved: (String docId) async => original,
    );
    final RemixesCubit cubit = RemixesCubit(repository);
    addTearDown(cubit.close);

    await cubit.load(original, viewer: _viewer());

    expect(cubit.state, isA<RemixesEmpty>());
    expect(repository.cursors, <String?>[null]);
  });

  test('emits empty when the repository throws', () async {
    final RemixesCubit cubit = RemixesCubit(
      _ScriptedRepository(
        onFetchRemixes: (String docId, String? cursor) async => throw StateError('offline'),
        onFetchApproved: (String docId) async => original,
      ),
    );
    addTearDown(cubit.close);

    await cubit.load(original, viewer: _viewer());

    expect(cubit.state, isA<RemixesEmpty>());
  });

  test('a second load that starts before the first finishes wins', () async {
    final Completer<List<PrismWallpaper>> firstResponse = Completer<List<PrismWallpaper>>();
    final _ScriptedRepository repository = _ScriptedRepository(
      onFetchRemixes: (String docId, String? cursor) {
        if (docId == 'doc-a') return firstResponse.future;
        return Future<List<PrismWallpaper>>.value(<PrismWallpaper>[
          remixWall(id: 'current', docId: 'current-doc', authorName: 'Current', authorUid: 'uid-current'),
        ]);
      },
      onFetchApproved: (String docId) async => remixWall(id: docId, docId: docId, remixCount: 1),
    );
    final RemixesCubit cubit = RemixesCubit(repository);
    addTearDown(cubit.close);

    final Future<void> first = cubit.load(
      remixWall(id: 'a', docId: 'doc-a', remixCount: 1),
      viewer: _viewer(),
    );
    await cubit.load(
      remixWall(id: 'b', docId: 'doc-b', remixCount: 1),
      viewer: _viewer(),
    );
    firstResponse.complete(<PrismWallpaper>[
      remixWall(id: 'stale', docId: 'stale-doc', authorName: 'Stale', authorUid: 'uid-stale'),
    ]);
    await first;

    final RemixesState state = cubit.state;
    expect(state, isA<RemixesLoaded>());
    expect((state as RemixesLoaded).remixes.map((PrismWallpaper wall) => wall.id), <String>['current']);
  });
}
