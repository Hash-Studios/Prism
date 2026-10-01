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
}
