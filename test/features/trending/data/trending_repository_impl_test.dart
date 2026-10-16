import 'dart:math';

import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/firestore/firestore_query_specs.dart';
import 'package:Prism/features/trending/data/repositories/trending_repository_impl.dart';
import 'package:Prism/features/trending/domain/entities/trending_range.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_feed_cache_local_data_source.dart';
import '../../../support/fake_firestore_client.dart';
import '../../../support/fake_user_block_repository.dart';

Map<String, dynamic> _wall(String id, {String email = 'creator@example.com'}) => <String, dynamic>{
  'id': id,
  'wallpaper_url': 'https://example.com/$id.jpg',
  'wallpaper_thumb': 'https://example.com/$id-thumb.jpg',
  'wallpaper_provider': 'Prism',
  'by': 'Ana',
  'email': email,
  'review': true,
};

List<String> _idsOf(FirestoreQuerySpec spec) =>
    (spec.filters.singleWhere((filter) => filter.op == FirestoreFilterOp.whereIn).value! as List).cast<String>();

void main() {
  late FakeFirestoreClient client;
  late FakeFeedCacheLocalDataSource cache;
  late FakeUserBlockRepository blocks;
  late TrendingRepositoryImpl repository;
  late Map<String, Map<String, dynamic>> walls;

  void setList(String collection, List<Object?> ids) {
    client.docs[collection] = <String, Map<String, dynamic>>{
      'current': <String, dynamic>{'wallIds': ids},
    };
  }

  setUp(() {
    walls = <String, Map<String, dynamic>>{};
    client = FakeFirestoreClient(
      onQuery: (spec) => <FakeDocRow>[
        for (final String id in _idsOf(spec).toList()..shuffle(Random(7)))
          if (walls.containsKey(id)) (id: 'doc-$id', data: walls[id]!),
      ],
    );
    cache = FakeFeedCacheLocalDataSource();
    blocks = FakeUserBlockRepository.pending()..completeInitial(<String>{});
    repository = TrendingRepositoryImpl(client, cache, blocks);
  });

  test('keeps the order of the id list, not the order Firestore answers in', () async {
    walls = <String, Map<String, dynamic>>{'A': _wall('A'), 'B': _wall('B'), 'C': _wall('C')};
    setList('trending', <Object?>['C', 'A', 'B']);

    final result = await repository.fetch(TrendingRange.week);

    expect(result.data!.map((wall) => wall.id), <String>['C', 'A', 'B']);
  });

  test('loads the walls in batches of at most 30 ids and keeps the order across batches', () async {
    final List<String> ids = List<String>.generate(65, (i) => 'W${i.toString().padLeft(2, '0')}');
    walls = <String, Map<String, dynamic>>{for (final String id in ids) id: _wall(id)};
    setList('popular', ids);

    final result = await repository.fetch(TrendingRange.allTime);

    final List<FirestoreQuerySpec> wallQueries = client.querySpecs;
    expect(wallQueries.map((spec) => _idsOf(spec).length), <int>[30, 30, 5]);
    expect(wallQueries.every((spec) => spec.collection == 'walls'), isTrue);
    expect(result.data!.map((wall) => wall.id), ids);
  });

  test('reads trending/current for the week and popular/current for all time', () async {
    walls = <String, Map<String, dynamic>>{'A': _wall('A'), 'B': _wall('B')};
    setList('trending', <Object?>['A']);
    setList('popular', <Object?>['B']);

    expect((await repository.fetch(TrendingRange.week)).data!.map((wall) => wall.id), <String>['A']);
    expect((await repository.fetch(TrendingRange.allTime)).data!.map((wall) => wall.id), <String>['B']);
  });

  test('only asks for reviewed walls', () async {
    walls = <String, Map<String, dynamic>>{'A': _wall('A')};
    setList('trending', <Object?>['A']);

    await repository.fetch(TrendingRange.week);

    final FirestoreFilter review = client.querySpecs.single.filters.firstWhere((filter) => filter.field == 'review');
    expect(review.value, true);
  });

  test('drops walls that are missing, from blocked creators, or without an image', () async {
    walls = <String, Map<String, dynamic>>{
      'A': _wall('A'),
      'B': _wall('B', email: 'blocked@example.com'),
      'D': <String, dynamic>{..._wall('D'), 'wallpaper_url': ''},
      'E': _wall('E'),
    };
    blocks.completeInitial(<String>{'blocked@example.com'});
    setList('trending', <Object?>['A', 'B', 'MISSING', 'D', 'E']);

    final result = await repository.fetch(TrendingRange.week);

    expect(result.data!.map((wall) => wall.id), <String>['A', 'E']);
  });

  test('upper-cases and de-duplicates the ids, and ignores blank ones', () async {
    walls = <String, Map<String, dynamic>>{'A': _wall('A'), 'B': _wall('B')};
    setList('trending', <Object?>['a', 'A', ' ', null, 'b']);

    final result = await repository.fetch(TrendingRange.week);

    expect(_idsOf(client.querySpecs.single), <String>['A', 'B']);
    expect(result.data!.map((wall) => wall.id), <String>['A', 'B']);
  });

  test('a missing or empty list gives an empty success without a wall query', () async {
    final missing = await repository.fetch(TrendingRange.week);
    setList('trending', <Object?>[]);
    final empty = await repository.fetch(TrendingRange.week);

    expect(missing.isSuccess, isTrue);
    expect(missing.data, isEmpty);
    expect(empty.data, isEmpty);
    expect(client.querySpecs, isEmpty);
  });

  test('a good empty list replaces the saved one, so a later failure does not bring old walls back', () async {
    walls = <String, Map<String, dynamic>>{'A': _wall('A')};
    setList('trending', <Object?>['A']);
    expect((await repository.fetch(TrendingRange.week)).data, hasLength(1));

    setList('trending', <Object?>[]);
    expect((await repository.fetch(TrendingRange.week)).data, isEmpty);
    setList('trending', <Object?>['A']);
    client.queryError = Exception('offline');
    final offline = await repository.fetch(TrendingRange.week);

    expect(offline.isSuccess, isTrue);
    expect(offline.data, isEmpty);
  });

  test('a saved empty list is a success, and a missing one is a failure', () async {
    setList('trending', <Object?>[]);
    await repository.fetch(TrendingRange.week);
    setList('trending', <Object?>['A']);
    setList('popular', <Object?>['A']);
    client.queryError = Exception('offline');

    expect((await repository.fetch(TrendingRange.week)).isSuccess, isTrue);
    expect((await repository.fetch(TrendingRange.allTime)).isFailure, isTrue);
  });

  test('returns the saved list when the network fails, and hides creators blocked since', () async {
    walls = <String, Map<String, dynamic>>{'A': _wall('A'), 'B': _wall('B', email: 'later@example.com')};
    setList('trending', <Object?>['A', 'B']);
    expect((await repository.fetch(TrendingRange.week)).data, hasLength(2));
    expect(cache.scopes, <String>['trending/week']);

    client.queryError = Exception('offline');
    blocks.completeInitial(<String>{'later@example.com'});
    final offline = await repository.fetch(TrendingRange.week);

    expect(offline.isSuccess, isTrue);
    expect(offline.data!.map((wall) => wall.id), <String>['A']);
  });

  test('saves the walls unfiltered, so a creator unblocked since gets their walls back offline', () async {
    walls = <String, Map<String, dynamic>>{'A': _wall('A'), 'B': _wall('B', email: 'later@example.com')};
    setList('trending', <Object?>['A', 'B']);
    blocks.completeInitial(<String>{'later@example.com'});
    expect((await repository.fetch(TrendingRange.week)).data!.map((wall) => wall.id), <String>['A']);

    client.queryError = Exception('offline');
    blocks.completeInitial(<String>{});
    final offline = await repository.fetch(TrendingRange.week);

    expect(offline.data!.map((wall) => wall.id), <String>['A', 'B']);
  });

  test('keeps a separate saved list for each range', () async {
    walls = <String, Map<String, dynamic>>{'A': _wall('A'), 'B': _wall('B')};
    setList('trending', <Object?>['A']);
    setList('popular', <Object?>['B']);
    await repository.fetch(TrendingRange.week);
    await repository.fetch(TrendingRange.allTime);

    client.queryError = Exception('offline');

    expect((await repository.fetch(TrendingRange.week)).data!.single.id, 'A');
    expect((await repository.fetch(TrendingRange.allTime)).data!.single.id, 'B');
  });

  test('fails when the network fails and nothing is saved', () async {
    setList('trending', <Object?>['A']);
    client.queryError = Exception('offline');

    final result = await repository.fetch(TrendingRange.week);

    expect(result.isFailure, isTrue);
    expect(result.failure, isA<ServerFailure>());
  });
}
