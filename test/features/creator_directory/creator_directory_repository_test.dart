import 'package:Prism/core/constants/app_constants.dart' as app_constants;
import 'package:Prism/core/firestore/firestore_client.dart';
import 'package:Prism/core/firestore/firestore_collections.dart';
import 'package:Prism/core/firestore/firestore_query_specs.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/user_blocks/blocked_creators.dart';
import 'package:Prism/features/creator_directory/data/creator_directory_repository_impl.dart';
import 'package:Prism/features/creator_directory/domain/creator_directory_entities.dart';
import 'package:Prism/features/user_blocks/domain/repositories/user_block_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/profile_user_fixture.dart';

const String _viewer = 'viewer';

typedef _Row = ({String id, Map<String, dynamic> data});

/// Serves the three collections the repository reads. Filters on `in`, `==`, and `array-contains` only.
class _FakeFirestore extends Fake implements FirestoreClient {
  _FakeFirestore({required this.directory, this.walls = const <_Row>[], this.following = const <String>[]});

  final List<_Row> directory;
  final List<_Row> walls;
  final List<String> following;
  final List<FirestoreQuerySpec> specs = <FirestoreQuerySpec>[];

  List<_Row> _rows(String collection) {
    if (collection == 'creatorDirectory') return directory;
    if (collection == FirebaseCollections.walls) return walls;
    if (collection == FirebaseCollections.profileFollowing(_viewer)) {
      return <_Row>[
        for (final String uid in following) (id: uid, data: <String, dynamic>{'targetUid': uid}),
      ];
    }
    return const <_Row>[];
  }

  bool _matches(FirestoreFilter f, _Row row) {
    final Object? value = f.field == firestoreDocumentIdField ? row.id : row.data[f.field];
    return switch (f.op) {
      FirestoreFilterOp.whereIn => (f.value! as List<Object?>).contains(value),
      FirestoreFilterOp.isEqualTo => value == f.value,
      FirestoreFilterOp.arrayContains => value is List && value.contains(f.value),
      _ => throw UnsupportedError('Unsupported filter ${f.op}'),
    };
  }

  @override
  Future<List<T>> query<T>(FirestoreQuerySpec spec, T Function(Map<String, dynamic> data, String docId) map) async {
    specs.add(spec);
    final List<_Row> rows = <_Row>[
      for (final _Row row in _rows(spec.collection))
        if (spec.filters.every((f) => _matches(f, row))) row,
    ];
    if (spec.orderBy.isNotEmpty) {
      rows.sort((a, b) => ((a.data['rank'] ?? 0) as num).compareTo((b.data['rank'] ?? 0) as num));
    }
    final Iterable<_Row> limited = spec.limit == null ? rows : rows.take(spec.limit!);
    return <T>[for (final _Row row in limited) map(row.data, row.id)];
  }

  @override
  Future<T?> getById<T>(
    String collection,
    String id,
    T Function(Map<String, dynamic> data, String docId) map, {
    required String sourceTag,
    bool preferCacheFirst = false,
  }) async {
    for (final _Row row in _rows(collection)) {
      if (row.id == id) return map(row.data, row.id);
    }
    return null;
  }
}

class _FakeBlocks extends Fake implements UserBlockRepository {
  @override
  Future<BlockedCreators> loadBlockedCreators() async => KnownBlockedCreators(<String>{'blocked'});
}

Future<Object?> _noCall(String name, Map<String, Object?> data) async => null;

_Row _dir(String uid, int rank, {List<String> walls = const <String>[], List<String> similar = const <String>[]}) => (
  id: uid,
  data: <String, dynamic>{
    'uid': uid,
    'name': 'Name $uid',
    'username': uid,
    'profilePhoto': '',
    'followerCount': 3,
    'walls': <Map<String, dynamic>>[
      for (final String id in walls) <String, dynamic>{'id': id},
    ],
    'categories': <String>['nature'],
    'similar': similar,
    'rank': rank,
  },
);

_Row _wall(String id) => (
  id: 'doc-$id',
  data: <String, dynamic>{
    'id': id,
    'wallpaper_url': 'https://example.com/full/$id.jpg',
    'wallpaper_thumb': 'https://example.com/thumb/$id.jpg',
    'wallpaper_provider': 'prism',
    'resolution': '1440x3200',
    'createdAt': DateTime.utc(2026).toIso8601String(),
    'by': 'Creator $id',
    'email': 'creator@example.com',
    'creatorUid': 'creator',
    'review': true,
  },
);

void main() {
  setUp(() => app_state.prismUser = profileUser(id: _viewer));
  tearDown(() => app_state.prismUser = app_constants.createGuestPrismUser());

  group('CreatorDirectoryRepositoryImpl', () {
    test('fetchPage hides a blocked creator and the viewer own uid', () async {
      final firestore = _FakeFirestore(
        directory: <_Row>[
          _dir(_viewer, 1, walls: const <String>['w-viewer']),
          _dir('blocked', 2, walls: const <String>['w-blocked']),
          _dir('ok', 3, walls: const <String>['w-ok']),
        ],
        walls: <_Row>[_wall('w-viewer'), _wall('w-blocked'), _wall('w-ok')],
      );
      final repo = CreatorDirectoryRepositoryImpl.withCaller(firestore, _FakeBlocks(), _noCall);

      final CreatorPage page = await repo.fetchPage();

      expect(page.creators.map((c) => c.uid).toList(), <String>['ok']);
    });

    test('fetchPage drops a creator whose walls no longer exist', () async {
      final firestore = _FakeFirestore(
        directory: <_Row>[
          _dir('gone', 1, walls: const <String>['w-missing']),
          _dir('ok', 2, walls: const <String>['w-ok']),
        ],
        walls: <_Row>[_wall('w-ok')],
      );
      final repo = CreatorDirectoryRepositoryImpl.withCaller(firestore, _FakeBlocks(), _noCall);

      final CreatorPage page = await repo.fetchPage();

      expect(page.creators.map((c) => c.uid).toList(), <String>['ok']);
    });

    test('nextRank is null when fewer than limit entries come back', () async {
      final firestore = _FakeFirestore(
        directory: <_Row>[
          _dir('a', 1, walls: const <String>['w-a']),
          _dir('b', 2, walls: const <String>['w-b']),
          _dir('c', 3, walls: const <String>['w-c']),
        ],
        walls: <_Row>[_wall('w-a'), _wall('w-b'), _wall('w-c')],
      );
      final repo = CreatorDirectoryRepositoryImpl.withCaller(firestore, _FakeBlocks(), _noCall);

      final CreatorPage page = await repo.fetchPage(limit: 5);
      expect(page.nextRank, isNull);

      final CreatorPage full = await repo.fetchPage(limit: 2);
      expect(full.nextRank, 2);
    });

    test('similarTo skips followed and blocked creators, keeps server order, and caps at the limit', () async {
      final firestore = _FakeFirestore(
        directory: <_Row>[
          _dir('src', 1, similar: const <String>['b', 'follow', 'a', 'blocked', 'c', 'src']),
          _dir('a', 2, walls: const <String>['w-a']),
          _dir('b', 3, walls: const <String>['w-b']),
          _dir('c', 4, walls: const <String>['w-c']),
          _dir('follow', 5, walls: const <String>['w-follow']),
          _dir('blocked', 6, walls: const <String>['w-blocked']),
        ],
        walls: <_Row>[_wall('w-a'), _wall('w-b'), _wall('w-c'), _wall('w-follow'), _wall('w-blocked')],
        following: const <String>['follow'],
      );
      final repo = CreatorDirectoryRepositoryImpl.withCaller(firestore, _FakeBlocks(), _noCall);

      final List<DirectoryCreator> similar = await repo.similarTo('src', limit: 2);

      expect(similar.map((c) => c.uid).toList(), <String>['b', 'a']);
    });

    test('followedBy maps people, drops empty names, and caches per creator', () async {
      final List<String> calledNames = <String>[];
      int calls = 0;
      Future<Object?> call(String name, Map<String, Object?> data) async {
        calls++;
        calledNames.add(name);
        return <String, Object?>{
          'count': 2,
          'people': <Object?>[
            <String, Object?>{'name': 'Ann', 'photo': 'u'},
            <String, Object?>{'name': '', 'photo': ''},
          ],
        };
      }

      final repo = CreatorDirectoryRepositoryImpl.withCaller(
        _FakeFirestore(directory: const <_Row>[]),
        _FakeBlocks(),
        call,
      );

      final FollowedBy first = await repo.followedBy('c1');
      final FollowedBy second = await repo.followedBy('c1');

      expect(first.count, 2);
      expect(first.people.length, 1);
      expect(first.people.single.name, 'Ann');
      expect(first.people.single.photoUrl, 'u');
      expect(second.count, 2);
      expect(calls, 1);
      expect(calledNames, <String>['getFollowedBy']);
    });

    test('a failed followedBy call is not cached', () async {
      int calls = 0;
      bool fail = true;
      Future<Object?> call(String name, Map<String, Object?> data) async {
        calls++;
        if (fail) throw StateError('offline');
        return <String, Object?>{'count': 1, 'people': <Object?>[]};
      }

      final repo = CreatorDirectoryRepositoryImpl.withCaller(
        _FakeFirestore(directory: const <_Row>[]),
        _FakeBlocks(),
        call,
      );

      await expectLater(repo.followedBy('c1'), throwsStateError);
      fail = false;
      final FollowedBy result = await repo.followedBy('c1');

      expect(calls, 2);
      expect(result.count, 1);
    });
  });
}
