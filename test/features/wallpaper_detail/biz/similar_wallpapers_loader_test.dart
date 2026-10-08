import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/firestore/firestore_client.dart';
import 'package:Prism/core/firestore/firestore_query_specs.dart';
import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/user_blocks/domain/repositories/user_block_repository.dart';
import 'package:Prism/features/user_search/data/wallpaper_search_service.dart';
import 'package:Prism/features/wallpaper_detail/biz/similar_wallpapers_loader.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockFirestore extends Mock implements FirestoreClient {}

class _MockBlocks extends Mock implements UserBlockRepository {}

class _MockSearch extends Mock implements WallpaperSearchService {}

FeedItemEntity _prism(String id, {String? category = 'Nature', String? email}) => FeedItemEntity.prism(
  id: id,
  wallpaper: PrismWallpaper(
    core: WallpaperCore(
      id: id,
      source: WallpaperSource.prism,
      fullUrl: 'https://img/$id.jpg',
      thumbnailUrl: 'https://img/$id-t.jpg',
      category: category,
      authorEmail: email,
    ),
  ),
);

FeedItemEntity _wallhaven(String id, {List<String>? tags}) => FeedItemEntity.wallhaven(
  id: id,
  wallpaper: WallhavenWallpaper(
    core: WallpaperCore(id: id, source: WallpaperSource.wallhaven, fullUrl: 'f$id', thumbnailUrl: 't$id'),
    tags: tags,
  ),
);

void main() {
  late _MockFirestore firestore;
  late _MockBlocks blocks;
  late _MockSearch search;
  late SimilarWallpapersLoader loader;

  setUpAll(() {
    registerFallbackValue(const FirestoreQuerySpec(collection: 'walls', sourceTag: 'x'));
  });

  setUp(() {
    firestore = _MockFirestore();
    blocks = _MockBlocks();
    search = _MockSearch();
    when(
      () => blocks.getBlockedCreatorEmails(waitForInitialLoad: any(named: 'waitForInitialLoad')),
    ).thenAnswer((_) async => <String>{'blocked@x.com'});
    loader = SimilarWallpapersLoader(firestore: () => firestore, blocks: () => blocks, search: () => search);
  });

  void stubRows(List<FeedItemEntity> rows) {
    when(() => firestore.query<FeedItemEntity>(any(), any())).thenAnswer((_) async => rows);
  }

  test('Prism walls query the same category with the similar source tag', () async {
    stubRows(<FeedItemEntity>[]);

    await loader.load(_prism('current'));

    final spec =
        verify(() => firestore.query<FeedItemEntity>(captureAny(), any())).captured.single as FirestoreQuerySpec;
    expect(spec.sourceTag, 'wallpaper_detail.similar');
    expect(spec.filters.map((f) => (f.field, f.value)), contains(('category', 'Nature')));
  });

  test('the current wall and blocked creators are left out', () async {
    stubRows(<FeedItemEntity>[_prism('current'), _prism('a'), _prism('b', email: 'Blocked@x.com')]);
    final result = await loader.load(_prism('current'));

    expect(result.map((e) => e.id), <String>['a']);
  });

  test('a Prism wall without a category has no similar walls and makes no query', () async {
    final result = await loader.load(_prism('current', category: ' '));

    expect(result, isEmpty);
    verifyNever(() => firestore.query<FeedItemEntity>(any(), any()));
  });

  test('a failed query gives an empty list instead of throwing', () async {
    when(() => firestore.query<FeedItemEntity>(any(), any())).thenThrow(Exception('failed-precondition'));

    expect(await loader.load(_prism('current')), isEmpty);
  });

  test('Wallhaven walls search by their first tag and drop the current wall', () async {
    when(() => search.search('space')).thenAnswer(
      (_) async => (
        provider: SearchProviderValue.wallhaven,
        results: <FeedItemEntity>[_wallhaven('me'), _wallhaven('x')],
        prismResults: const <FeedItemEntity>[],
      ),
    );

    final result = await loader.load(_wallhaven('me', tags: <String>['space', 'stars']));

    expect(result.map((e) => e.id), <String>['x']);
  });

  test('a Wallhaven wall without tags and a Pexels wall have no strip', () async {
    expect(await loader.load(_wallhaven('me')), isEmpty);
    verifyNever(() => search.search(any()));
  });
}
