import 'package:Prism/core/firestore/firestore_query_specs.dart';
import 'package:Prism/features/prism_feed/data/prism_wall_search.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_firestore_client.dart';
import '../../../support/fake_user_block_repository.dart';

void main() {
  late FakeFirestoreClient firestore;
  late PrismWallSearch search;

  setUp(() {
    firestore = FakeFirestoreClient();
    search = PrismWallSearch(firestore, FakeUserBlockRepository.pending()..completeInitial(<String>{}));
  });

  List<Object?> valuesOf(String sourceTag) =>
      firestore.querySpecs.firstWhere((spec) => spec.sourceTag == sourceTag).filters.last.value! as List<Object?>;

  test('a one word query keeps the three spellings it always had', () async {
    await search.search('forest');

    expect(valuesOf('PrismWallSearch.tags'), <String>['forest', 'Forest']);
    expect(
      firestore.querySpecs.firstWhere((spec) => spec.sourceTag == 'PrismWallSearch.tags').filters.last.op,
      FirestoreFilterOp.arrayContainsAny,
    );
  });

  test('each word of a longer query is a tag, so "dark blue forest" can match a wall tagged "forest"', () async {
    await search.search('dark blue forest');

    final List<Object?> tags = valuesOf('PrismWallSearch.tags');
    expect(tags, containsAll(<String>['dark', 'Dark', 'blue', 'Blue', 'forest', 'Forest']));
    expect(tags, contains('dark blue forest'));
  });

  test('the tag filter never passes more than 30 values, and uses at most 10 words', () async {
    await search.search(List<String>.generate(14, (i) => 'word$i').join(' '));

    final List<Object?> tags = valuesOf('PrismWallSearch.tags');
    expect(tags.length, lessThanOrEqualTo(30));
    expect(tags, contains('word9'));
    expect(tags, isNot(contains('word10')));
  });

  test('a category name inside a longer query matches the category field', () async {
    await search.search('dark forest');

    expect(valuesOf('PrismWallSearch.category'), containsAll(<String>['Dark', 'Forest']));
  });

  test('repeated and extra spaces never make an empty tag', () async {
    await search.search('  neon   neon  city ');

    final List<Object?> tags = valuesOf('PrismWallSearch.tags');
    expect(tags, isNot(contains('')));
    expect(tags.where((tag) => tag == 'neon'), hasLength(1));
  });

  group('colour', () {
    test('a colour with an empty query lists that colour newest first, without text filters', () async {
      await search.search('', colorId: 'blue');

      final spec = firestore.querySpecs.single;
      expect(spec.sourceTag, 'PrismWallSearch.color');
      expect(spec.filters.map((f) => (f.field, f.op, f.value)), <(String, FirestoreFilterOp, Object?)>[
        ('review', FirestoreFilterOp.isEqualTo, true),
        ('colors', FirestoreFilterOp.arrayContains, 'blue'),
      ]);
      expect(spec.orderBy.single.field, 'createdAt');
      expect(spec.orderBy.single.descending, isTrue);
    });

    test('an empty query without a colour asks nothing', () async {
      expect(await search.search(''), isEmpty);
      expect(firestore.querySpecs, isEmpty);
    });

    test('with a query the colour is never a Firestore filter, because two array filters cannot be combined', () async {
      await search.search('forest', colorId: 'blue');

      expect(firestore.querySpecs, hasLength(2));
      expect(firestore.querySpecs.expand((spec) => spec.filters).map((f) => f.field), isNot(contains('colors')));
      expect(firestore.querySpecs.every((spec) => spec.limit == 48), isTrue);
    });
  });

  group('depth', () {
    Map<String, dynamic> doc(String id, {String? tier, List<String> colors = const <String>[]}) => <String, dynamic>{
      'id': id,
      'wallpaper_url': 'https://prism/$id.jpg',
      'wallpaper_provider': 'prism',
      'review': true,
      'colors': colors,
      'depth': ?(tier == null ? null : <String, dynamic>{'tier': tier}),
    };

    test('with an empty query lists the auto and menu walls newest first, without text filters', () async {
      await search.search('', depthOnly: true);

      final spec = firestore.querySpecs.single;
      expect(spec.sourceTag, 'PrismWallSearch.depth');
      expect(spec.collection, 'walls');
      expect(spec.filters.map((f) => (f.field, f.op)), <(String, FirestoreFilterOp)>[
        ('review', FirestoreFilterOp.isEqualTo),
        ('depth.tier', FirestoreFilterOp.whereIn),
      ]);
      expect(spec.filters.first.value, true);
      expect(spec.filters.last.value, <String>['auto', 'menu']);
      expect(spec.orderBy.single.field, 'createdAt');
      expect(spec.orderBy.single.descending, isTrue);
      expect(spec.limit, 12);
    });

    test('with a query the depth tier is checked on the matches, so the text indexes stay in use', () async {
      firestore.onQuery = (spec) => spec.sourceTag == 'PrismWallSearch.tags'
          ? <FakeDocRow>[
              (id: 'a', data: doc('a', tier: 'auto')),
              (id: 'b', data: doc('b', tier: 'none')),
              (id: 'c', data: doc('c')),
              (id: 'd', data: doc('d', tier: 'menu')),
            ]
          : const <FakeDocRow>[];

      final walls = await search.search('forest', depthOnly: true);

      expect(walls.map((wall) => wall.id), <String>['a', 'd']);
      expect(firestore.querySpecs.expand((spec) => spec.filters).map((f) => f.field), isNot(contains('depth.tier')));
      expect(firestore.querySpecs.every((spec) => spec.limit == 48), isTrue);
    });

    test('with a colour too, the depth query runs and the colour is matched locally', () async {
      firestore.onQuery = (spec) => <FakeDocRow>[
        (id: 'a', data: doc('a', tier: 'auto', colors: <String>['blue'])),
        (id: 'b', data: doc('b', tier: 'menu', colors: <String>['red'])),
        (id: 'c', data: doc('c', tier: 'menu', colors: <String>['red', 'blue'])),
      ];

      final walls = await search.search('', colorId: 'blue', depthOnly: true);

      expect(walls.map((wall) => wall.id), <String>['a', 'c']);
      final spec = firestore.querySpecs.single;
      expect(spec.sourceTag, 'PrismWallSearch.depth');
      expect(spec.filters.map((f) => f.field), isNot(contains('colors')));
      expect(spec.limit, 48);
    });

    test('a wall without a depth tier never passes, even if the query returned it', () async {
      firestore.onQuery = (spec) => <FakeDocRow>[(id: 'a', data: doc('a')), (id: 'b', data: doc('b', tier: 'none'))];

      expect(await search.search('', depthOnly: true), isEmpty);
    });

    test('without the depth filter the depth tier is ignored', () async {
      firestore.onQuery = (spec) => spec.sourceTag == 'PrismWallSearch.tags'
          ? <FakeDocRow>[(id: 'a', data: doc('a', tier: 'none')), (id: 'c', data: doc('c'))]
          : const <FakeDocRow>[];

      expect((await search.search('forest')).map((wall) => wall.id), <String>['a', 'c']);
    });
  });
}
