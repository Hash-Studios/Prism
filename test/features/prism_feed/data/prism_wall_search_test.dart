import 'dart:convert';
import 'dart:io';

import 'package:Prism/core/firestore/firestore_query_specs.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/features/prism_feed/data/prism_wall_search.dart';
import 'package:Prism/features/user_search/data/search_filters.dart';
import 'package:collection/collection.dart';
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

  Map<String, dynamic> doc(
    String id, {
    String? tier,
    String? spatial,
    List<String> colors = const <String>[],
    Object? searchTerms,
  }) => <String, dynamic>{
    'id': id,
    'wallpaper_url': 'https://prism/$id.jpg',
    'wallpaper_provider': 'prism',
    'review': true,
    'colors': colors,
    'depth': ?(tier == null ? null : <String, dynamic>{'tier': tier}),
    'spatial': ?(spatial == null ? null : <String, dynamic>{'tier': spatial}),
    'searchTerms': ?searchTerms,
  };

  group('text', () {
    test('Duo search uses the existing tags and retains color and depth filtering', () async {
      firestore.onQuery = (_) => <FakeDocRow>[
        (id: 'duo', data: doc('duo', colors: <String>['blue'], tier: 'auto')),
        (id: 'wrong-color', data: doc('wrong-color', colors: <String>['red'], tier: 'auto')),
      ];
      final walls = await search.search('Duo-Reveal', colorId: 'blue', depthOnly: true);
      expect(walls.map((wall) => wall.id), <String>['duo']);
      expect(firestore.querySpecs.single.filters.last.field, 'tags');
      expect(firestore.querySpecs.single.filters.last.value, <String>['duo', 'duo-reveal']);
    });
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
    });

    test(
      'a one word query asks for 12 walls, a longer one for 48 so older walls that match more words get ranked',
      () async {
        await search.search('boat');
        await search.search('Boats at Sunset');
        await search.search('boat sunset', colorId: 'blue');

        expect(firestore.querySpecs.map((spec) => spec.limit), <int?>[12, 48, 48]);
      },
    );

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

    test('with an unknown block list, a search keeps only the wall without a creator', () async {
      firestore.onQuery = (spec) => <FakeDocRow>[
        (id: 'by-creator', data: doc('by-creator', searchTerms: <String>['boat'])..['creatorUid'] = 'creator1'),
        (id: 'no-creator', data: doc('no-creator', searchTerms: <String>['boat'])..['creatorUid'] = ''),
      ];
      search = PrismWallSearch(firestore, FakeUserBlockRepository.pending()..timeOutInitialLoad());

      final walls = await search.search('boat');

      expect(walls.map((wall) => wall.id), <String>['no-creator']);
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

  group('spatial', () {
    test('with an empty query lists the great walls before the ok walls, newest first within a tier', () async {
      await search.search('', spatialOnly: true);

      final spec = firestore.querySpecs.single;
      expect(spec.sourceTag, 'PrismWallSearch.spatial');
      expect(spec.collection, 'walls');
      expect(spec.filters.map((f) => (f.field, f.op)), <(String, FirestoreFilterOp)>[
        ('review', FirestoreFilterOp.isEqualTo),
        ('spatial.tier', FirestoreFilterOp.whereIn),
      ]);
      expect(spec.filters.first.value, true);
      expect(spec.filters.last.value, <String>['great', 'ok']);
      expect(spec.orderBy.map((order) => (order.field, order.descending)), <(String, bool)>[
        ('spatial.tier', false),
        ('createdAt', true),
      ]);
      expect(spec.limit, 12);
    });

    test('with a query the spatial tier is checked on the matches, so only great and ok walls stay', () async {
      firestore.onQuery = (spec) => spec.sourceTag == 'PrismWallSearch.terms'
          ? <FakeDocRow>[
              (id: 'a', data: doc('a', spatial: 'great')),
              (id: 'b', data: doc('b', spatial: 'none')),
              (id: 'c', data: doc('c')),
              (id: 'd', data: doc('d', spatial: 'ok')),
            ]
          : const <FakeDocRow>[];

      final walls = await search.search('forest', spatialOnly: true);

      expect(walls.map((wall) => wall.id), <String>['a', 'd']);
      expect(firestore.querySpecs.expand((spec) => spec.filters).map((f) => f.field), isNot(contains('spatial.tier')));
      expect(firestore.querySpecs.every((spec) => spec.limit == 48), isTrue);
    });
  });

  group('kinds', () {
    Map<String, dynamic> kindDoc(
      String id, {
      bool live = false,
      bool desktop = false,
      bool pair = false,
      String? uid,
      List<String> colors = const <String>[],
    }) => <String, dynamic>{
      ...doc(id, colors: colors),
      if (uid != null) 'creatorUid': uid,
      if (live) 'kind': 'live',
      if (live) 'live': <String, dynamic>{'video': 'https://prism/$id.mp4', 'verified': true},
      if (desktop)
        'desktopVariant': <String, dynamic>{
          'v': 'abcdef0123456789',
          'width': 2560,
          'height': 1600,
          'wideHeight': 1600,
          'thumb': 'https://prism/d-$id.jpg',
        },
      if (pair) 'variantGroupId': 'g1',
      if (pair) 'variantIndex': 0,
    };

    Map<String, dynamic> gateDoc(String id, String uid) => <String, dynamic>{
      ...kindDoc(id, live: true, desktop: true, pair: true, uid: uid, colors: <String>['blue']),
      'depth': <String, dynamic>{'tier': 'auto'},
      'spatial': <String, dynamic>{'tier': 'great'},
      'searchTerms': <String>['sky'],
    };

    test('a live browse lists live walls newest first, 12 at a time', () async {
      await search.search('', kinds: <PrismWallKind>{PrismWallKind.live});

      final spec = firestore.querySpecs.single;
      expect(spec.sourceTag, 'PrismWallSearch.kind.live');
      expect(spec.filters.map((f) => (f.field, f.op, f.value)), <(String, FirestoreFilterOp, Object?)>[
        ('review', FirestoreFilterOp.isEqualTo, true),
        ('kind', FirestoreFilterOp.isEqualTo, 'live'),
      ]);
      expect(spec.orderBy.map((order) => (order.field, order.descending)), <(String, bool)>[('createdAt', true)]);
      expect(spec.limit, 12);
    });

    test('a desktop browse lists the widest desktop walls first, then the newest', () async {
      await search.search('', kinds: <PrismWallKind>{PrismWallKind.desktop});

      final spec = firestore.querySpecs.single;
      expect(spec.sourceTag, 'PrismWallSearch.kind.desktop');
      expect(spec.filters.last.field, 'desktopVariant.width');
      expect(spec.filters.last.op, FirestoreFilterOp.isGreaterThan);
      expect(spec.filters.last.value, 0);
      expect(spec.orderBy.map((order) => (order.field, order.descending)), <(String, bool)>[
        ('desktopVariant.width', true),
        ('createdAt', true),
      ]);
    });

    test('a light and dark browse lists the first wall of each colour set, newest first', () async {
      await search.search('', kinds: <PrismWallKind>{PrismWallKind.lightDark});

      final spec = firestore.querySpecs.single;
      expect(spec.sourceTag, 'PrismWallSearch.kind.lightDark');
      expect(spec.filters.last.field, 'variantIndex');
      expect(spec.filters.last.op, FirestoreFilterOp.isEqualTo);
      expect(spec.filters.last.value, 0);
      expect(spec.orderBy.map((order) => (order.field, order.descending)), <(String, bool)>[('createdAt', true)]);
    });

    test('live and desktop browse runs the live query and keeps only walls that are both', () async {
      firestore.onQuery = (_) => <FakeDocRow>[
        (id: 'live-only', data: kindDoc('live-only', live: true)),
        (id: 'desktop-only', data: kindDoc('desktop-only', desktop: true)),
        (id: 'both', data: kindDoc('both', live: true, desktop: true)),
      ];

      final walls = await search.search('', kinds: <PrismWallKind>{PrismWallKind.live, PrismWallKind.desktop});

      expect(walls.map((wall) => wall.id), <String>['both']);
      expect(firestore.querySpecs.single.sourceTag, 'PrismWallSearch.kind.live');
      expect(firestore.querySpecs.single.limit, 48);
    });

    test('a live browse with a colour checks the colour on the matches', () async {
      firestore.onQuery = (_) => <FakeDocRow>[
        (id: 'blue', data: kindDoc('blue', live: true, colors: <String>['blue'])),
        (id: 'red', data: kindDoc('red', live: true, colors: <String>['red'])),
      ];

      final walls = await search.search('', colorId: 'blue', kinds: <PrismWallKind>{PrismWallKind.live});

      expect(walls.map((wall) => wall.id), <String>['blue']);
      expect(firestore.querySpecs.single.sourceTag, 'PrismWallSearch.kind.live');
    });

    test('a depth browse with a kind keeps the depth query and checks the kind on the matches', () async {
      firestore.onQuery = (_) => <FakeDocRow>[
        (
          id: 'live-auto',
          data: <String, dynamic>{
            ...kindDoc('live-auto', live: true),
            'depth': <String, dynamic>{'tier': 'auto'},
          },
        ),
        (
          id: 'still-auto',
          data: <String, dynamic>{
            ...kindDoc('still-auto'),
            'depth': <String, dynamic>{'tier': 'auto'},
          },
        ),
      ];

      final walls = await search.search('', depthOnly: true, kinds: <PrismWallKind>{PrismWallKind.live});

      expect(walls.map((wall) => wall.id), <String>['live-auto']);
      expect(firestore.querySpecs.single.sourceTag, 'PrismWallSearch.depth');
    });

    test('a text query with a kind uses the terms query and drops a wall that is not live', () async {
      firestore.onQuery = (_) => <FakeDocRow>[
        (
          id: 'live-sky',
          data: <String, dynamic>{
            ...kindDoc('live-sky', live: true),
            'searchTerms': <String>['sky'],
          },
        ),
        (
          id: 'still-sky',
          data: <String, dynamic>{
            ...kindDoc('still-sky'),
            'searchTerms': <String>['sky'],
          },
        ),
      ];

      final walls = await search.search('sky', kinds: <PrismWallKind>{PrismWallKind.live});

      expect(walls.map((wall) => wall.id), <String>['live-sky']);
      final spec = firestore.querySpecs.single;
      expect(spec.sourceTag, 'PrismWallSearch.terms');
      expect(spec.filters.map((f) => f.field), <String>['review', 'searchTerms']);
      expect(spec.limit, 48);
    });

    test('a kind browse retries after a failed query rather than retaining its empty failure', () async {
      for (final PrismWallKind kind in PrismWallKind.values) {
        firestore.querySpecs.clear();
        firestore.queryError = StateError('failed-precondition');
        expect(await search.search('', kinds: <PrismWallKind>{kind}), isEmpty);
        firestore.queryError = null;
        firestore.onQuery = (_) => <FakeDocRow>[
          (id: 'wall', data: kindDoc('wall', live: true, desktop: true, pair: true)),
        ];

        expect((await search.search('', kinds: <PrismWallKind>{kind})).map((wall) => wall.id), <String>['wall']);
        expect(firestore.querySpecs, hasLength(2));
      }
    });

    test('the discovery one-wall check stays empty when its first live wall is blocked', () async {
      search = PrismWallSearch(firestore, FakeUserBlockRepository.pending()..completeInitial(<String>{'blocked'}));
      final List<FakeDocRow> rows = <FakeDocRow>[
        (id: 'newest', data: kindDoc('newest', live: true, uid: 'blocked')),
        (id: 'older', data: kindDoc('older', live: true, uid: 'visible')),
      ];
      firestore.onQuery = (spec) => rows.take(spec.limit!).toList();

      expect(await search.search('', limit: 1, kinds: <PrismWallKind>{PrismWallKind.live}), isEmpty);
      expect(firestore.querySpecs.single.limit, 1);
      expect(firestore.querySpecs.single.sourceTag, 'PrismWallSearch.kind.live');
    });

    test('device checks can exhaust the fetched window before an older matching wall', () async {
      final List<FakeDocRow> rows = <FakeDocRow>[
        for (var i = 0; i < 48; i++) (id: 'still-$i', data: kindDoc('still-$i')),
        (id: 'older-live', data: kindDoc('older-live', live: true)),
      ];
      firestore.onQuery = (spec) => rows.take(spec.limit!).toList();

      final walls = await search.search('sky', kinds: <PrismWallKind>{PrismWallKind.live});

      expect(walls, isEmpty);
      expect(firestore.querySpecs.single.limit, 48);
      expect(firestore.querySpecs.single.startAfterDocId, isNull);
      expect(firestore.querySpecs, hasLength(1));
    });

    test('every kind browse and filtered text query has its protected-wall composite index', () async {
      for (final PrismWallKind kind in PrismWallKind.values) {
        await search.search('', kinds: <PrismWallKind>{kind});
        await search.search('sky', kinds: <PrismWallKind>{kind});
        await search.search('duo', kinds: <PrismWallKind>{kind});
      }
      final Map<String, Object?> config =
          jsonDecode(File('firestore.indexes.json').readAsStringSync()) as Map<String, Object?>;
      final List<Object?> indexes = config['indexes']! as List<Object?>;
      final List<(String, String)> protectedPrefix = <(String, String)>[
        for (final String field in <String>[
          'originalProtected',
          'wallpaper_url',
          'wallpaper_path',
          'wallpaper_sha',
          'thumb_path',
          'thumb_sha',
        ])
          (field, 'ASCENDING'),
      ];
      for (final FirestoreQuerySpec spec in firestore.querySpecs) {
        final Set<String> orderedFields = spec.orderBy.map((order) => order.field).toSet();
        final List<(String, String)> expected = <(String, String)>[
          ...protectedPrefix,
          for (final FirestoreFilter filter in spec.filters)
            if (filter.op == FirestoreFilterOp.arrayContainsAny || filter.op == FirestoreFilterOp.arrayContains)
              (filter.field, 'CONTAINS'),
          for (final FirestoreFilter filter in spec.filters)
            if (filter.op == FirestoreFilterOp.isEqualTo && !orderedFields.contains(filter.field))
              (filter.field, 'ASCENDING'),
          for (final FirestoreOrderBy order in spec.orderBy)
            (order.field, order.descending ? 'DESCENDING' : 'ASCENDING'),
          ('__name__', spec.orderBy.last.descending ? 'DESCENDING' : 'ASCENDING'),
        ];
        final bool hasIndex = indexes.whereType<Map<String, Object?>>().any((index) {
          if (index['collectionGroup'] != spec.collection || index['queryScope'] != 'COLLECTION') return false;
          final List<(String, String)> fields = (index['fields']! as List<Object?>)
              .cast<Map<String, Object?>>()
              .map((field) => (field['fieldPath'] as String, (field['order'] ?? field['arrayConfig']) as String))
              .toList();
          if (fields.last.$1 != '__name__') fields.add(('__name__', fields.last.$2));
          return const ListEquality<(String, String)>().equals(fields, expected);
        });
        expect(hasIndex, isTrue, reason: '${spec.sourceTag} requires $expected');
      }
    });

    test('every filter combination keeps the review gate and hides blocked creators', () async {
      search = PrismWallSearch(firestore, FakeUserBlockRepository.pending()..completeInitial(<String>{'blocked'}));
      firestore.onQuery = (_) => <FakeDocRow>[
        (id: 'blocked', data: gateDoc('blocked', 'blocked')),
        (id: 'ok', data: gateDoc('ok', 'ok')),
      ];
      final List<Future<List<PrismWallpaper>> Function()> combinations = <Future<List<PrismWallpaper>> Function()>[
        () => search.search('', kinds: <PrismWallKind>{PrismWallKind.live}),
        () => search.search('', kinds: <PrismWallKind>{PrismWallKind.desktop}),
        () => search.search('', kinds: <PrismWallKind>{PrismWallKind.lightDark}),
        () => search.search('', kinds: PrismWallKind.values.toSet()),
        () => search.search('sky', kinds: <PrismWallKind>{PrismWallKind.live}),
        () => search.search('', colorId: 'blue', kinds: <PrismWallKind>{PrismWallKind.desktop}),
        () => search.search('', depthOnly: true, kinds: <PrismWallKind>{PrismWallKind.lightDark}),
        () => search.search('', spatialOnly: true),
        () => search.search('', colorId: 'blue'),
      ];

      for (var index = 0; index < combinations.length; index++) {
        firestore.querySpecs.clear();
        final List<PrismWallpaper> walls = await combinations[index]();

        expect(walls.map((wall) => wall.id), <String>['ok'], reason: 'combination $index');
        expect(firestore.querySpecs, isNotEmpty, reason: 'combination $index');
        for (final FirestoreQuerySpec spec in firestore.querySpecs) {
          expect(
            spec.filters.any((f) => f.field == 'review' && f.op == FirestoreFilterOp.isEqualTo && f.value == true),
            isTrue,
            reason: 'combination $index, ${spec.sourceTag}',
          );
        }
      }
    });
  });
}
