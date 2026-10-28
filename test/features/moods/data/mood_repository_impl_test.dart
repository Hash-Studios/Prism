import 'dart:math';

import 'package:Prism/core/firestore/firestore_query_specs.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/personalization/taste_profile.dart';
import 'package:Prism/features/moods/data/mood_repository_impl.dart';
import 'package:Prism/features/moods/domain/entities/wall_mood.dart';
import 'package:Prism/features/personalized_feed/domain/repositories/personalized_feed_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_firestore_client.dart';
import '../../../support/fake_user_block_repository.dart';
import '../../../support/in_memory_local_store.dart';

Map<String, dynamic> _wall(String id, {String creatorUid = 'creator-id', String? category}) => <String, dynamic>{
  'id': id,
  'wallpaper_url': 'https://example.com/$id.jpg',
  'wallpaper_thumb': 'https://example.com/$id-thumb.jpg',
  'wallpaper_provider': 'Prism',
  'by': 'Ana',
  'creatorUid': creatorUid,
  'review': true,
  'category': ?category,
};

List<String> _idsOf(FirestoreQuerySpec spec) =>
    (spec.filters.singleWhere((filter) => filter.op == FirestoreFilterOp.whereIn).value! as List).cast<String>();

class _FakeFeedRepository extends Fake implements PersonalizedFeedRepository {
  _FakeFeedRepository(this.profile);

  final TasteProfile profile;

  @override
  TasteProfile currentTasteProfile() => profile;
}

void main() {
  late FakeFirestoreClient client;
  late Map<String, Map<String, dynamic>> walls;
  late FakeUserBlockRepository blocks;
  late _FakeFeedRepository feed;
  late MoodRepositoryImpl repository;

  setUp(() {
    walls = <String, Map<String, dynamic>>{};
    client = FakeFirestoreClient(
      onQuery: (spec) => <FakeDocRow>[
        for (final String id in _idsOf(spec))
          if (walls.containsKey(id)) (id: 'doc-$id', data: walls[id]!),
      ],
    );
    blocks = FakeUserBlockRepository.pending()..completeInitial(<String>{});
    feed = _FakeFeedRepository(TasteProfile.empty);
    repository = MoodRepositoryImpl(
      client,
      blocks,
      SettingsLocalDataSource(InMemoryLocalStore()),
      feed,
      random: Random(1),
      now: () => DateTime.utc(2026, 10, 28),
    );
  });

  group('fetchMoods', () {
    test('keeps the stored order and skips unknown moods and entries without ids', () async {
      client.docs['moods'] = <String, Map<String, dynamic>>{
        'current': <String, dynamic>{
          'moods': <Object?>[
            <String, Object?>{
              'id': 'minimal',
              'wallIds': <Object?>['A', 'B'],
            },
            <String, Object?>{
              'id': 'future_mood',
              'wallIds': <Object?>['C'],
            },
            <String, Object?>{'id': 'dreamy', 'wallIds': <Object?>[]},
            <String, Object?>{
              'id': 'dreamy',
              'wallIds': <Object?>[' 0CFI ', '0CFI', 'ab12', 3, ''],
            },
          ],
        },
      };

      final moods = await repository.fetchMoods();

      expect(moods.map((list) => list.mood), <WallMood>[WallMood.minimal, WallMood.dreamy]);
      expect(moods.first.wallIds, <String>['A', 'B']);
      expect(moods.last.wallIds, <String>['0CFI', 'ab12']);
    });

    test('returns an empty list when the doc is missing', () async {
      expect(await repository.fetchMoods(), isEmpty);
    });
  });

  group('fetchMoodWalls', () {
    test('makes no query for an empty id list', () async {
      expect(await repository.fetchMoodWalls(const <String>[]), isEmpty);

      expect(client.querySpecs, isEmpty);
    });

    test('drops ids whose walls are missing', () async {
      walls = <String, Map<String, dynamic>>{'A': _wall('A'), 'B': _wall('B')};

      final List<String> ids = (await repository.fetchMoodWalls(<String>[
        'A',
        'MISSING',
        'B',
      ])).map((wall) => wall.id).toList();

      expect(ids, unorderedEquals(<String>['A', 'B']));
    });

    test('drops walls from blocked creators', () async {
      walls = <String, Map<String, dynamic>>{
        'A': _wall('A', creatorUid: 'blocked-uid'),
        'B': _wall('B', creatorUid: 'ok-uid'),
      };
      blocks.completeInitial(<String>{'blocked-uid'});

      final List<String> ids = (await repository.fetchMoodWalls(<String>['A', 'B'])).map((wall) => wall.id).toList();

      expect(ids, <String>['B']);
    });

    test('ranks the walls that match the taste profile first', () async {
      feed = _FakeFeedRepository(
        const TasteProfile(terms: <String, double>{'nature': 10}, creators: <String, double>{}),
      );
      repository = MoodRepositoryImpl(
        client,
        blocks,
        SettingsLocalDataSource(InMemoryLocalStore()),
        feed,
        random: Random(1),
        now: () => DateTime.utc(2026, 10, 28),
      );
      walls = <String, Map<String, dynamic>>{
        'A': _wall('A', creatorUid: 'creator-a', category: 'abstract'),
        'B': _wall('B', creatorUid: 'creator-b', category: 'nature'),
      };

      final List<String> ids = (await repository.fetchMoodWalls(<String>['A', 'B'])).map((wall) => wall.id).toList();

      expect(ids.first, 'B');
    });
  });
}
