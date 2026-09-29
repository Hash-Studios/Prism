import 'package:Prism/core/firestore/firestore_client.dart';
import 'package:Prism/core/firestore/firestore_query_specs.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/features/prism_feed/domain/repositories/prism_wallpaper_repository.dart';
import 'package:Prism/features/wall_of_the_day/data/repositories/wall_of_the_day_repository_impl.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../support/fake_user_block_repository.dart';

class _MockPrismWallpaperRepository extends Mock implements PrismWallpaperRepository {}

/// Serves a fixed `wall_of_the_day/current` pointer for any [getById] call;
/// the repo under test never touches [query]/writes.
class _FakePointerFirestoreClient implements FirestoreClient {
  _FakePointerFirestoreClient({required this.wallDocumentId, required this.featuredAt});

  final String wallDocumentId;
  final DateTime featuredAt;

  @override
  Future<T?> getById<T>(
    String collection,
    String id,
    T Function(Map<String, dynamic> data, String docId) map, {
    required String sourceTag,
    bool preferCacheFirst = false,
  }) async => map(<String, dynamic>{'wallId': wallDocumentId, 'date': featuredAt}, id);

  @override
  Future<List<T>> query<T>(FirestoreQuerySpec spec, T Function(Map<String, dynamic> data, String docId) map) =>
      throw UnimplementedError();

  @override
  Stream<List<T>> watchQuery<T>(FirestoreQuerySpec spec, T Function(Map<String, dynamic> data, String docId) map) =>
      throw UnimplementedError();

  @override
  Future<void> setDoc(
    String collection,
    String id,
    Map<String, dynamic> data, {
    bool merge = false,
    required String sourceTag,
  }) => throw UnimplementedError();

  @override
  Future<void> updateDoc(String collection, String id, Map<String, dynamic> data, {required String sourceTag}) =>
      throw UnimplementedError();

  @override
  Future<void> deleteDoc(String collection, String id, {required String sourceTag}) => throw UnimplementedError();

  @override
  Future<String> addDoc(String collection, Map<String, dynamic> data, {required String sourceTag}) =>
      throw UnimplementedError();

  @override
  Future<T> runTransaction<T>(
    Future<T> Function(FirestoreTransaction transaction) action, {
    required String sourceTag,
    required String collection,
    String? docId,
  }) => throw UnimplementedError();

  @override
  Future<void> runBatch(Future<void> Function(FirestoreBatch batch) action, {required String sourceTag}) =>
      throw UnimplementedError();
}

void main() {
  late _FakePointerFirestoreClient firestoreClient;
  late _MockPrismWallpaperRepository prismRepository;

  setUpAll(() {
    firestoreClient = _FakePointerFirestoreClient(wallDocumentId: 'wall-doc-1', featuredAt: DateTime.utc(2026));
  });

  setUp(() {
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
}
