import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/firestore/firestore_collections.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/features/prism_feed/domain/repositories/prism_wallpaper_repository.dart';
import 'package:Prism/features/wall_of_the_day/data/repositories/wall_of_the_day_repository_impl.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../support/fake_firestore_client.dart';
import '../../../../support/fake_user_block_repository.dart';

class _MockPrismWallpaperRepository extends Mock implements PrismWallpaperRepository {}

/// Serves a stale pointer from the "cache" when a caller asks for cache-first.
class _StaleCacheFirestoreClient extends FakeFirestoreClient {
  _StaleCacheFirestoreClient({super.docs});

  @override
  Future<T?> getById<T>(
    String collection,
    String id,
    T Function(Map<String, dynamic> data, String docId) map, {
    required String sourceTag,
    bool preferCacheFirst = false,
  }) async {
    if (preferCacheFirst) {
      return map(<String, dynamic>{'wallId': 'wall-doc-1', 'date': DateTime.utc(2026)}, id);
    }
    return super.getById(collection, id, map, sourceTag: sourceTag);
  }
}

PrismWallpaper _wall(String id, {String? url}) => PrismWallpaper(
  core: WallpaperCore(
    id: id,
    source: WallpaperSource.prism,
    fullUrl: url ?? 'https://example.com/$id.jpg',
    thumbnailUrl: 'https://example.com/$id-thumb.jpg',
  ),
);

void main() {
  late FakeFirestoreClient firestoreClient;
  late _MockPrismWallpaperRepository prismRepository;

  setUp(() {
    firestoreClient = FakeFirestoreClient(
      docs: <String, Map<String, Map<String, dynamic>>>{
        FirebaseCollections.wallOfTheDay: <String, Map<String, dynamic>>{
          'current': <String, dynamic>{'wallId': 'wall-doc-1', 'date': DateTime.utc(2026)},
        },
      },
    );
    prismRepository = _MockPrismWallpaperRepository();
  });

  test('hides a cached pick once its creator becomes blocked, without a refetch', () async {
    when(() => prismRepository.fetchByDocumentId('wall-doc-1')).thenAnswer(
      (_) async => Result.success(
        const PrismWallpaper(
          core: WallpaperCore(
            id: 'wall-1',
            source: WallpaperSource.prism,
            fullUrl: 'https://example.com/wall-1.jpg',
            thumbnailUrl: 'https://example.com/wall-1-thumb.jpg',
            authorEmail: 'creator@example.com',
          ),
        ),
      ),
    );
    final blockRepo = FakeUserBlockRepository.pending()..completeInitial(<String>{});
    final repo = WallOfTheDayRepositoryImpl(firestoreClient, prismRepository, blockRepo);

    final firstFetch = await repo.fetchToday();
    expect(firstFetch.data?.wallId, 'wall-1', reason: 'not blocked yet, so the pick shows');

    // The caller blocks the creator; a later screen visit re-fetches WOTD, hitting the
    // repo's own day-scoped cache (no further prismRepository.fetchByDocumentId call).
    blockRepo.completeInitial(<String>{'creator@example.com'});
    final secondFetch = await repo.fetchToday();

    expect(secondFetch.data, isNull, reason: 'the cached pick must disappear once its creator is blocked');
    verify(() => prismRepository.fetchByDocumentId('wall-doc-1')).called(1);
  });

  test('reads the pointer without cache-first so a new daily pick shows', () async {
    final client = _StaleCacheFirestoreClient(docs: firestoreClient.docs);
    when(
      () => prismRepository.fetchByDocumentId('wall-doc-1'),
    ).thenAnswer((_) async => Result.success(_wall('wall-1')));
    when(
      () => prismRepository.fetchByDocumentId('wall-doc-2'),
    ).thenAnswer((_) async => Result.success(_wall('wall-2')));
    final blockRepo = FakeUserBlockRepository.pending()..completeInitial(<String>{});
    final repo = WallOfTheDayRepositoryImpl(client, prismRepository, blockRepo);

    expect((await repo.fetchToday()).data?.wallId, 'wall-1');

    client.docs[FirebaseCollections.wallOfTheDay]!['current'] = <String, dynamic>{
      'wallId': 'wall-doc-2',
      'date': DateTime.utc(2026),
    };
    expect((await repo.fetchToday()).data?.wallId, 'wall-2');
  });

  test('same pointer reuses the day cache, then changed featured day refreshes the wall', () async {
    var fetchCount = 0;
    when(() => prismRepository.fetchByDocumentId('wall-doc-1')).thenAnswer((_) async {
      fetchCount++;
      return Result.success(_wall('wall-1', url: 'https://example.com/version-$fetchCount.jpg'));
    });
    final blockRepo = FakeUserBlockRepository.pending()..completeInitial(<String>{});
    final repo = WallOfTheDayRepositoryImpl(firestoreClient, prismRepository, blockRepo);

    expect((await repo.fetchToday()).data?.url, 'https://example.com/version-1.jpg');
    expect((await repo.fetchToday()).data?.url, 'https://example.com/version-1.jpg');
    firestoreClient.docs[FirebaseCollections.wallOfTheDay]!['current'] = <String, dynamic>{
      'wallId': 'wall-doc-1',
      'date': DateTime.utc(2026, 1, 2),
    };
    expect((await repo.fetchToday()).data?.url, 'https://example.com/version-2.jpg');

    verify(() => prismRepository.fetchByDocumentId('wall-doc-1')).called(2);
  });

  test('missing and empty pointers return an empty result', () async {
    when(
      () => prismRepository.fetchByDocumentId('wall-doc-1'),
    ).thenAnswer((_) async => Result.success(_wall('wall-1')));
    when(
      () => prismRepository.fetchByDocumentId('wall-doc-2'),
    ).thenAnswer((_) async => Result.success(_wall('wall-2')));
    final blockRepo = FakeUserBlockRepository.pending()..completeInitial(<String>{});
    final repo = WallOfTheDayRepositoryImpl(firestoreClient, prismRepository, blockRepo);

    expect((await repo.fetchToday()).data?.wallId, 'wall-1');
    firestoreClient.docs[FirebaseCollections.wallOfTheDay]!.remove('current');
    expect((await repo.fetchToday()).data, isNull);

    firestoreClient.docs[FirebaseCollections.wallOfTheDay]!['current'] = <String, dynamic>{
      'wallId': '',
      'date': DateTime.utc(2026),
    };
    expect((await repo.fetchToday()).data, isNull);

    firestoreClient.docs[FirebaseCollections.wallOfTheDay]!['current'] = <String, dynamic>{
      'wallId': 'wall-doc-2',
      'date': DateTime.utc(2026),
    };
    expect((await repo.fetchToday()).data?.wallId, 'wall-2');
    verify(() => prismRepository.fetchByDocumentId('wall-doc-1')).called(1);
    verify(() => prismRepository.fetchByDocumentId('wall-doc-2')).called(1);
  });

  for (final ({String name, Result<PrismWallpaper?> firstAttempt}) retryCase
      in <({String name, Result<PrismWallpaper?> firstAttempt})>[
        (name: 'missing wall', firstAttempt: Result.success<PrismWallpaper?>(null)),
        (name: 'wall fetch failure', firstAttempt: Result.error<PrismWallpaper?>(const NetworkFailure('offline'))),
      ]) {
    test('${retryCase.name} can be retried and return the new wall', () async {
      var fetchCount = 0;
      when(() => prismRepository.fetchByDocumentId('wall-doc-1')).thenAnswer((_) async {
        fetchCount++;
        return fetchCount == 1 ? retryCase.firstAttempt : Result.success(_wall('wall-new'));
      });
      final blockRepo = FakeUserBlockRepository.pending()..completeInitial(<String>{});
      final repo = WallOfTheDayRepositoryImpl(firestoreClient, prismRepository, blockRepo);

      final firstAttempt = await repo.fetchToday();
      final retry = await repo.fetchToday();

      if (retryCase.name == 'wall fetch failure') {
        expect(firstAttempt.isFailure, isTrue);
      } else {
        expect(firstAttempt.data, isNull);
      }
      expect(retry.data?.wallId, 'wall-new');
      verify(() => prismRepository.fetchByDocumentId('wall-doc-1')).called(2);
    });
  }

  group('fetchRecent', () {
    PrismWallpaper reviewed(String id, {bool review = true, String url = ''}) => PrismWallpaper(
      core: WallpaperCore(
        id: id,
        source: WallpaperSource.prism,
        fullUrl: url.isEmpty ? 'https://example.com/$id.jpg' : url,
        thumbnailUrl: 'https://example.com/$id-thumb.jpg',
      ),
      review: review,
    );

    WallOfTheDayRepositoryImpl repoWith(List<FakeDocRow> rows) {
      firestoreClient.onQuery = (_) => rows;
      return WallOfTheDayRepositoryImpl(
        firestoreClient,
        prismRepository,
        FakeUserBlockRepository.pending()..completeInitial(<String>{}),
      );
    }

    test('reads past_picks newest first, 30 at a time, with the wotd source tag', () async {
      final repo = repoWith(const <FakeDocRow>[]);

      final result = await repo.fetchRecent();

      expect(result.data, isEmpty);
      final spec = firestoreClient.querySpecs.single;
      expect(spec.collection, 'past_picks');
      expect(spec.sourceTag, 'wotd.past_picks');
      expect(spec.limit, 30);
      expect(spec.orderBy.single.field, 'date');
      expect(spec.orderBy.single.descending, isTrue);
    });

    test('resolves each pick to its wall, keeps the order, and skips walls that are gone or not reviewed', () async {
      when(() => prismRepository.fetchByDocumentId('doc-a')).thenAnswer((_) async => Result.success(reviewed('a')));
      when(() => prismRepository.fetchByDocumentId('doc-gone')).thenAnswer((_) async => Result.success(null));
      when(
        () => prismRepository.fetchByDocumentId('doc-hidden'),
      ).thenAnswer((_) async => Result.success(reviewed('hidden', review: false)));
      when(() => prismRepository.fetchByDocumentId('doc-b')).thenAnswer((_) async => Result.success(reviewed('b')));
      final repo = repoWith(<FakeDocRow>[
        (id: '2026-01-04', data: <String, dynamic>{'wallId': 'doc-a', 'date': DateTime.utc(2026, 1, 4)}),
        (id: '2026-01-03', data: <String, dynamic>{'wallId': 'doc-gone', 'date': DateTime.utc(2026, 1, 3)}),
        (id: '2026-01-02', data: <String, dynamic>{'wallId': 'doc-hidden', 'date': DateTime.utc(2026, 1, 2)}),
        (id: '2026-01-01', data: <String, dynamic>{'wallId': 'doc-b'}),
      ]);

      final picks = (await repo.fetchRecent()).data!;

      expect(picks.map((pick) => pick.wallpaper.id), <String>['a', 'b']);
      expect(picks.first.date, DateTime.utc(2026, 1, 4));
      expect(picks.last.date, DateTime.parse('2026-01-01'), reason: 'a pick with no date field uses its doc id');
    });

    test('a pointer with no wall id or no usable date is skipped without a lookup', () async {
      final repo = repoWith(<FakeDocRow>[
        (id: '2026-01-04', data: <String, dynamic>{'wallId': '', 'date': DateTime.utc(2026, 1, 4)}),
        (id: 'not-a-date', data: <String, dynamic>{'wallId': 'doc-a'}),
      ]);

      expect((await repo.fetchRecent()).data, isEmpty);
      verifyNever(() => prismRepository.fetchByDocumentId(any()));
    });

    test('a failed query is an error with a message the user can read', () async {
      firestoreClient.queryError = StateError('[cloud_firestore/unavailable] offline');
      final repo = WallOfTheDayRepositoryImpl(
        firestoreClient,
        prismRepository,
        FakeUserBlockRepository.pending()..completeInitial(<String>{}),
      );

      final result = await repo.fetchRecent();

      expect(result.failure!.message, "Couldn't load past picks. Check your connection and try again.");
    });

    test('when every wall lookup fails the archive reports the failure instead of an empty list', () async {
      when(
        () => prismRepository.fetchByDocumentId(any()),
      ).thenAnswer((_) async => Result.error(const ServerFailure('offline')));
      final repo = repoWith(<FakeDocRow>[
        (id: '2026-01-04', data: <String, dynamic>{'wallId': 'doc-a', 'date': DateTime.utc(2026, 1, 4)}),
      ]);

      expect((await repo.fetchRecent()).isFailure, isTrue);
    });

    test('one failed lookup among good ones only drops that pick', () async {
      when(() => prismRepository.fetchByDocumentId('doc-a')).thenAnswer((_) async => Result.success(reviewed('a')));
      when(
        () => prismRepository.fetchByDocumentId('doc-b'),
      ).thenAnswer((_) async => Result.error(const ServerFailure('offline')));
      final repo = repoWith(<FakeDocRow>[
        (id: '2026-01-04', data: <String, dynamic>{'wallId': 'doc-a', 'date': DateTime.utc(2026, 1, 4)}),
        (id: '2026-01-03', data: <String, dynamic>{'wallId': 'doc-b', 'date': DateTime.utc(2026, 1, 3)}),
      ]);

      expect((await repo.fetchRecent()).data!.map((pick) => pick.wallpaper.id), <String>['a']);
    });
  });

  test("today's pick carries the loaded wall, so the detail screen needs no second fetch", () async {
    final wall = _wall('wall-1');
    when(() => prismRepository.fetchByDocumentId('wall-doc-1')).thenAnswer((_) async => Result.success(wall));
    final repo = WallOfTheDayRepositoryImpl(
      firestoreClient,
      prismRepository,
      FakeUserBlockRepository.pending()..completeInitial(<String>{}),
    );

    expect((await repo.fetchToday()).data?.wallpaper, same(wall));
  });
}
