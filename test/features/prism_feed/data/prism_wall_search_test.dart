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

  Map<String, dynamic> doc(String id, {String? tier, List<String> colors = const <String>[], Object? searchTerms}) =>
      <String, dynamic>{
        'id': id,
        'wallpaper_url': 'https://prism/$id.jpg',
        'wallpaper_provider': 'prism',
        'review': true,
        'colors': colors,
        'depth': ?(tier == null ? null : <String, dynamic>{'tier': tier}),
        'searchTerms': ?searchTerms,
      };

  group('text', () {
    test('sends the singular lowercase words of the query as one array-contains-any filter on searchTerms', () async {
      await search.search('Boats at Sunset');

      final spec = firestore.querySpecs.single;
      expect(spec.sourceTag, 'PrismWallSearch.terms');
      expect(spec.collection, 'walls');
      expect(spec.filters.map((f) => (f.field, f.op)), <(String, FirestoreFilterOp)>[
        ('review', FirestoreFilterOp.isEqualTo),
        ('searchTerms', FirestoreFilterOp.arrayContainsAny),
      ]);
      expect(spec.filters.last.value, <String>['boat', 'sunset']);
      expect(spec.orderBy.single.field, 'createdAt');
      expect(spec.orderBy.single.descending, isTrue);
      expect(spec.limit, 12);
    });

    test('a query of only stopwords sends no query and returns nothing', () async {
      expect(await search.search('the'), isEmpty);
      expect(firestore.querySpecs, isEmpty);
    });

    test('a query of more than 10 words sends the first 10 terms', () async {
      await search.search('alpha bravo charlie delta echo foxtrot golf hotel india juliet kilo lima');

      expect(firestore.querySpecs.single.filters.last.value, <String>[
        'alpha',
        'bravo',
        'charlie',
        'delta',
        'echo',
        'foxtrot',
        'golf',
        'hotel',
        'india',
        'juliet',
      ]);
    });

    test('repeated words and extra spaces send each term once', () async {
      await search.search('  neon   Neon  city ');

      expect(firestore.querySpecs.single.filters.last.value, <String>['neon', 'city']);
    });

    test('a wall that matches more query terms comes before a newer wall that matches fewer', () async {
      firestore.onQuery = (spec) => <FakeDocRow>[
        (id: 'newest-one-term', data: doc('newest-one-term', searchTerms: <String>['boat', 'harbor'])),
        (id: 'older-one-term', data: doc('older-one-term', searchTerms: <String>['sunset'])),
        (id: 'oldest-two-terms', data: doc('oldest-two-terms', searchTerms: <String>['sunset', 'beach', 'boat'])),
      ];

      final walls = await search.search('boats at sunset');

      expect(walls.map((wall) => wall.id), <String>['oldest-two-terms', 'newest-one-term', 'older-one-term']);
    });

    test('walls with the same number of matched terms keep the order Firestore returned', () async {
      firestore.onQuery = (spec) => <FakeDocRow>[
        (id: 'a', data: doc('a', searchTerms: <String>['boat'])),
        (id: 'b', data: doc('b', searchTerms: <String>['sunset'])),
        (id: 'c', data: doc('c', searchTerms: <String>['boat', 'sunset'])),
        (id: 'd', data: doc('d', searchTerms: <String>['sunset', 'boat'])),
        (id: 'e', data: doc('e', searchTerms: <String>['boat'])),
      ];

      final walls = await search.search('boat sunset');

      expect(walls.map((wall) => wall.id), <String>['c', 'd', 'a', 'b', 'e']);
    });

    test('a missing, non-list or non-string searchTerms scores no match but the wall is kept', () async {
      firestore.onQuery = (spec) => <FakeDocRow>[
        (id: 'missing', data: doc('missing')),
        (id: 'text', data: doc('text', searchTerms: 'boat')),
        (id: 'mixed', data: doc('mixed', searchTerms: <Object?>[42, null, 'boat'])),
        (id: 'junk', data: doc('junk', searchTerms: <Object?>[42, null])),
      ];

      final walls = await search.search('boat');

      expect(walls.map((wall) => wall.id), <String>['mixed', 'missing', 'text', 'junk']);
    });

    test('the limit applies after ranking', () async {
      firestore.onQuery = (spec) => <FakeDocRow>[
        (id: 'one', data: doc('one', searchTerms: <String>['boat'])),
        (id: 'two', data: doc('two', searchTerms: <String>['boat', 'sunset'])),
      ];

      final walls = await search.search('boat sunset', limit: 1);

      expect(walls.map((wall) => wall.id), <String>['two']);
    });
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

      expect(firestore.querySpecs, hasLength(1));
      expect(firestore.querySpecs.expand((spec) => spec.filters).map((f) => f.field), isNot(contains('colors')));
      expect(firestore.querySpecs.every((spec) => spec.limit == 48), isTrue);
    });
  });

  group('depth', () {
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
      firestore.onQuery = (spec) => spec.sourceTag == 'PrismWallSearch.terms'
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
      firestore.onQuery = (spec) => spec.sourceTag == 'PrismWallSearch.terms'
          ? <FakeDocRow>[(id: 'a', data: doc('a', tier: 'none')), (id: 'c', data: doc('c'))]
          : const <FakeDocRow>[];

      expect((await search.search('forest')).map((wall) => wall.id), <String>['a', 'c']);
    });
  });
}
