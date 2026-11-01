import 'package:Prism/core/firestore/firestore_client.dart';
import 'package:Prism/core/firestore/firestore_query_specs.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/features/user_blocks/domain/repositories/user_block_repository.dart';
import 'package:Prism/features/wall_remix/data/wall_remix_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockFirestoreClient extends Mock implements FirestoreClient {}

class _MockUserBlockRepository extends Mock implements UserBlockRepository {}

void main() {
  late _MockFirestoreClient firestore;
  late WallRemixRepository repository;
  final List<FirestoreQuerySpec> queries = <FirestoreQuerySpec>[];

  setUpAll(() {
    registerFallbackValue(const FirestoreQuerySpec(collection: 'walls', sourceTag: 'test'));
  });

  setUp(() {
    firestore = _MockFirestoreClient();
    repository = WallRemixRepository(firestore, _MockUserBlockRepository());
    queries.clear();
    when(() => firestore.query<PrismWallpaper>(any(), any())).thenAnswer((invocation) async {
      queries.add(invocation.positionalArguments.first as FirestoreQuerySpec);
      return <PrismWallpaper>[];
    });
  });

  test('remix and original eligibility queries bypass both Firestore caches', () async {
    await repository.fetchRemixes('original-doc');
    await repository.fetchApprovedWall('original-doc');

    expect(queries, hasLength(2));
    expect(queries.map((query) => query.cachePolicy), everyElement(FirestoreCachePolicy.serverOnly));
    expect(queries.map((query) => query.sourceTag), <String>[
      'WallRemixRepository.fetchRemixes',
      'WallRemixRepository.fetchApprovedWall',
    ]);
  });
}
