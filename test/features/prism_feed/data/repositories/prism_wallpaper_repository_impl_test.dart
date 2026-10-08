import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/firestore/firestore_collections.dart';
import 'package:Prism/core/firestore/firestore_query_specs.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/features/prism_feed/data/repositories/prism_wallpaper_repository_impl.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/fake_feed_cache_local_data_source.dart';
import '../../../../support/fake_firestore_client.dart';
import '../../../../support/fake_user_block_repository.dart';

void main() {
  group('PrismWallpaperRepositoryImpl', () {
    test('waits for blocked creators and refills filtered pages without skipping visible rows', () async {
      final firestore = _walls(_buildWallDocs(count: 30));
      final cache = FakeFeedCacheLocalDataSource();
      final blocks = FakeUserBlockRepository.pending();
      final repo = PrismWallpaperRepositoryImpl(firestore, cache, blocks);

      final Future<Result<List<PrismWallpaper>>> pending = repo.fetchFeed(refresh: true);
      await Future<void>.delayed(Duration.zero);

      expect(firestore.querySpecs, isEmpty);

      blocks.completeInitial(<String>{'creator1@example.com', 'creator2@example.com', 'creator3@example.com'});

      final firstPage = await pending;
      expect(firstPage.isSuccess, isTrue);
      expect(firstPage.data, hasLength(24));
      expect(firstPage.data!.first.core.id, 'wall-4');
      expect(firstPage.data!.last.core.id, 'wall-27');
      expect(repo.hasMore, isTrue);
      expect(firestore.querySpecs, hasLength(2));

      final secondPage = await repo.fetchFeed(refresh: false);
      expect(secondPage.isSuccess, isTrue);
      expect(secondPage.data!.map((wall) => wall.core.id).toList(growable: false), <String>[
        'wall-28',
        'wall-29',
        'wall-30',
      ]);
      expect(repo.hasMore, isFalse);
    });

    test('only a refresh writes the cache, and a failed fetch-more is an error, not the cached page', () async {
      final firestore = _walls(_buildWallDocs(count: 60));
      final cache = FakeFeedCacheLocalDataSource();
      final repo = PrismWallpaperRepositoryImpl(
        firestore,
        cache,
        FakeUserBlockRepository.pending()..completeInitial(<String>{}),
      );

      expect((await repo.fetchFeed(refresh: true)).isSuccess, isTrue);
      final firstSnapshot = cache.snapshots['prism/main'];
      expect(firstSnapshot, isNotNull);

      expect((await repo.fetchFeed(refresh: false)).isSuccess, isTrue);
      expect(cache.snapshots['prism/main'], same(firstSnapshot), reason: 'page 2 must not overwrite page 1');

      firestore.queryError = StateError('offline');
      expect((await repo.fetchFeed(refresh: false)).isFailure, isTrue);
      expect((await repo.fetchFeed(refresh: true)).data, hasLength(24), reason: 'a failed refresh still has the cache');
    });

    test('streak shop queries the same field the wall docs are read from', () async {
      final firestore = _walls(<({String docId, Map<String, dynamic> data})>[
        (
          docId: 'doc-1',
          data: <String, dynamic>{
            ..._buildWallDocs(count: 1).single.data,
            'is_streak_exclusive': true,
            'required_streak_days': 3,
          },
        ),
      ]);
      final blocks = FakeUserBlockRepository.pending()..completeInitial(<String>{});
      final repo = PrismWallpaperRepositoryImpl(firestore, FakeFeedCacheLocalDataSource(), blocks);

      final result = await repo.fetchStreakShopWallpapers();

      expect(firestore.querySpecs.last.filters.map((f) => f.field), contains('is_streak_exclusive'));
      expect(result.data!.single.isStreakExclusive, isTrue);
      expect(result.data!.single.requiredStreakDays, 3);
    });

    test('fetchById falls back to the doc id that Wall of the Day links carry', () async {
      final docs = _buildWallDocs(count: 2);
      docs[1].data['review'] = false;
      final repo = PrismWallpaperRepositoryImpl(
        _walls(docs, matchIdField: true),
        FakeFeedCacheLocalDataSource(),
        FakeUserBlockRepository.pending()..completeInitial(<String>{}),
      );

      expect((await repo.fetchById('doc-1')).data?.core.id, 'wall-1');
      expect((await repo.fetchById('doc-2')).data, isNull, reason: 'unreviewed walls stay hidden');
      expect((await repo.fetchById('doc-404')).data, isNull);
    });

    group('failures', () {
      const String offline = '[cloud_firestore/unavailable] The service is currently unavailable.';

      PrismWallpaperRepositoryImpl repoWith(FakeFirestoreClient firestore) => PrismWallpaperRepositoryImpl(
        firestore,
        FakeFeedCacheLocalDataSource(),
        FakeUserBlockRepository.pending()..completeInitial(<String>{}),
      );

      test('fetchById tells the user to check the connection and never shows the raw error', () async {
        final firestore = _walls(_buildWallDocs(count: 1))..queryError = StateError(offline);

        final result = await repoWith(firestore).fetchById('wall-1');

        expect(result.failure, isA<ServerFailure>());
        expect(result.failure!.message, wallpaperLoadFailureMessage);
        expect(result.failure!.message, isNot(contains('cloud_firestore')));
      });

      test('fetchByDocumentId reports the same user-facing message', () async {
        final firestore = _FailingGetFirestore();

        final result = await repoWith(firestore).fetchByDocumentId('doc-1');

        expect(result.failure!.message, wallpaperLoadFailureMessage);
      });

      test('a wall that does not exist is a success with no wall, not a failure', () async {
        final result = await repoWith(
          _walls(<({String docId, Map<String, dynamic> data})>[], matchIdField: true),
        ).fetchById('missing');

        expect(result.isSuccess, isTrue);
        expect(result.data, isNull);
      });

      test('fetchById keeps a failed doc id lookup a failure instead of calling the wall missing', () async {
        final firestore = _FailingGetFirestore(
          docs: _walls(<({String docId, Map<String, dynamic> data})>[], matchIdField: true),
        );

        final result = await repoWith(firestore).fetchById('doc-1');

        expect(result.isFailure, isTrue);
        expect(result.failure!.message, wallpaperLoadFailureMessage);
      });
    });

    group('fetchByCategory', () {
      test('asks for reviewed walls of that category, newest first, with the Prism-first source tag', () async {
        final docs = _buildWallDocs(count: 3);
        final firestore = _walls(docs);
        final repo = PrismWallpaperRepositoryImpl(
          firestore,
          FakeFeedCacheLocalDataSource(),
          FakeUserBlockRepository.pending()..completeInitial(<String>{}),
        );

        final result = await repo.fetchByCategory('Nature', startAfterDocId: 'doc-1', limit: 10);

        final FirestoreQuerySpec spec = firestore.querySpecs.single;
        expect(spec.sourceTag, 'category_feed.prism_first');
        expect(spec.collection, FirebaseCollections.walls);
        expect(spec.filters.map((f) => (f.field, f.op, f.value)), <(String, FirestoreFilterOp, Object?)>[
          ('category', FirestoreFilterOp.isEqualTo, 'Nature'),
          ('review', FirestoreFilterOp.isEqualTo, true),
        ]);
        expect(spec.orderBy.single.field, 'createdAt');
        expect(spec.orderBy.single.descending, isTrue);
        expect(spec.startAfterDocId, 'doc-1');
        expect(spec.limit, 10);
        expect(result.data!.map((wall) => wall.id), <String>['wall-2', 'wall-3']);
      });

      test('hides walls from blocked creators', () async {
        final repo = PrismWallpaperRepositoryImpl(
          _walls(_buildWallDocs(count: 3)),
          FakeFeedCacheLocalDataSource(),
          FakeUserBlockRepository.pending()..completeInitial(<String>{'creator2@example.com'}),
        );

        final result = await repo.fetchByCategory('Nature');

        expect(result.data!.map((wall) => wall.id), <String>['wall-1', 'wall-3']);
      });

      test('a failed query is a user-facing failure', () async {
        final firestore = _walls(_buildWallDocs(count: 1))..queryError = StateError('boom');
        final repo = PrismWallpaperRepositoryImpl(
          firestore,
          FakeFeedCacheLocalDataSource(),
          FakeUserBlockRepository.pending()..completeInitial(<String>{}),
        );

        final result = await repo.fetchByCategory('Nature');

        expect(result.failure!.message, wallpaperLoadFailureMessage);
      });
    });
  });
}

/// Answers wall queries from [docs]: pages by `startAfterDocId` and `limit`, or matches the `id` field.
FakeFirestoreClient _walls(List<({String docId, Map<String, dynamic> data})> docs, {bool matchIdField = false}) {
  return FakeFirestoreClient(
    docs: <String, Map<String, Map<String, dynamic>>>{
      FirebaseCollections.walls: <String, Map<String, dynamic>>{for (final doc in docs) doc.docId: doc.data},
    },
    onQuery: (spec) {
      final Iterable<({String docId, Map<String, dynamic> data})> rows;
      if (matchIdField) {
        final Object? id = spec.filters.where((f) => f.field == 'id').firstOrNull?.value;
        rows = docs.where((doc) => doc.data['id'] == id);
      } else {
        final int lastIndex = docs.indexWhere((doc) => doc.docId == spec.startAfterDocId);
        rows = docs.skip(lastIndex + 1).take(spec.limit ?? docs.length);
      }
      return rows.map((doc) => (id: doc.docId, data: doc.data)).toList(growable: false);
    },
  );
}

List<({String docId, Map<String, dynamic> data})> _buildWallDocs({required int count}) {
  return List<({String docId, Map<String, dynamic> data})>.generate(count, (index) {
    final int n = index + 1;
    return (
      docId: 'doc-$n',
      data: <String, dynamic>{
        'id': 'wall-$n',
        'wallpaper_url': 'https://example.com/full/$n.jpg',
        'wallpaper_thumb': 'https://example.com/thumb/$n.jpg',
        'wallpaper_provider': 'prism',
        'resolution': '1440x3200',
        'createdAt': DateTime.utc(2026).subtract(Duration(minutes: index)).toIso8601String(),
        'by': 'Creator $n',
        'email': 'creator$n@example.com',
        'review': true,
      },
    );
  });
}

/// A client whose `getById` always fails, as when the device is offline and the document is not cached.
class _FailingGetFirestore extends FakeFirestoreClient {
  _FailingGetFirestore({FakeFirestoreClient? docs}) : super(onQuery: docs?.onQuery);

  @override
  Future<T?> getById<T>(
    String collection,
    String id,
    T Function(Map<String, dynamic> data, String docId) map, {
    required String sourceTag,
    bool preferCacheFirst = false,
  }) => Future<T?>.error(StateError('[cloud_firestore/unavailable] The service is currently unavailable.'));
}
