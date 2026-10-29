import 'dart:async';
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

Map<String, dynamic> _wall(
  String id, {
  String creatorUid = 'creator-id',
  String? category,
  List<String> collections = const <String>[],
  bool streakExclusive = false,
  bool dropReserved = false,
  Object? dropWeek,
  bool review = true,
}) => <String, dynamic>{
  'id': id,
  'wallpaper_url': 'https://example.com/$id.jpg',
  'wallpaper_thumb': 'https://example.com/$id-thumb.jpg',
  'wallpaper_provider': 'Prism',
  'by': 'Ana',
  'creatorUid': creatorUid,
  'review': review,
  'originalProtected': true,
  'collections': collections,
  'is_streak_exclusive': streakExclusive,
  'dropReserved': dropReserved,
  'dropWeek': dropWeek,
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
            <String, Object?>{
              'id': 'dreamy',
              'wallIds': <Object?>['SHOULD_NOT_DUPLICATE'],
            },
          ],
        },
      };

      final moods = await repository.fetchMoods();

      expect(moods.map((list) => list.mood), <WallMood>[WallMood.minimal, WallMood.dreamy]);
      expect(moods.first.wallIds, <String>['A', 'B']);
      expect(moods.last.wallIds, <String>['0CFI', 'ab12']);
    });

    test('caps hand-edited mood ids at the server limit of 60', () async {
      client.docs['moods'] = <String, Map<String, dynamic>>{
        'current': <String, dynamic>{
          'moods': <Object?>[
            <String, Object?>{
              'id': 'dreamy',
              'wallIds': <String>[for (int i = 0; i < 75; i++) 'ID$i'],
            },
          ],
        },
      };

      final List<MoodList> moods = await repository.fetchMoods();

      expect(moods.single.wallIds, hasLength(60));
      expect(moods.single.wallIds.last, 'ID59');
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

    test('with an unknown block list, drops walls that have a creator and keeps one without', () async {
      walls = <String, Map<String, dynamic>>{'A': _wall('A'), 'B': _wall('B', creatorUid: '')};
      final MoodRepositoryImpl unloaded = MoodRepositoryImpl(
        client,
        FakeUserBlockRepository.pending()..timeOutInitialLoad(),
        SettingsLocalDataSource(InMemoryLocalStore()),
        feed,
        random: Random(1),
        now: () => DateTime.utc(2026, 10, 28),
      );

      final List<String> ids = (await unloaded.fetchMoodWalls(<String>['A', 'B'])).map((wall) => wall.id).toList();

      expect(ids, <String>['B']);
    });

    test('drops stale walls that are no longer eligible for free daily picks', () async {
      walls = <String, Map<String, dynamic>>{
        'A': _wall('A'),
        'STREAK': _wall('STREAK', streakExclusive: true),
        'RESERVED': _wall('RESERVED', dropReserved: true),
        'DROP': _wall('DROP', dropWeek: '2026-W44'),
        'PREMIUM': _wall('PREMIUM', collections: <String>['space']),
        'UNPROTECTED': <String, dynamic>{..._wall('UNPROTECTED'), 'originalProtected': false},
        'UNREVIEWED': _wall('UNREVIEWED', review: false),
      };

      final List<String> ids = (await repository.fetchMoodWalls(<String>[
        'A',
        'STREAK',
        'RESERVED',
        'DROP',
        'PREMIUM',
        'UNPROTECTED',
        'UNREVIEWED',
      ])).map((wall) => wall.id).toList();

      expect(ids, <String>['A']);
      expect(
        client.querySpecs.single.filters.any(
          (filter) => filter.field == 'review' && filter.op == FirestoreFilterOp.isEqualTo && filter.value == true,
        ),
        isTrue,
      );
    });

    test('preserves gallery order while hiding blocked and restricted walls', () async {
      walls = <String, Map<String, dynamic>>{
        'Z': _wall('Z'),
        'BLOCKED': _wall('BLOCKED', creatorUid: 'blocked-uid'),
        'PREMIUM': _wall('PREMIUM', collections: <String>['space']),
        'A': _wall('A'),
      };
      blocks.completeInitial(<String>{'blocked-uid'});

      final List<String> ids = (await repository.fetchMoodWalls(<String>[
        'Z',
        'BLOCKED',
        'PREMIUM',
        'A',
      ], keepOrder: true)).map((wall) => wall.id).toList();

      expect(ids, <String>['Z', 'A']);
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

  test('watchVisibilityChanges fires only when the blocked creators change', () async {
    int changes = 0;
    final StreamSubscription<void> sub = repository.watchVisibilityChanges().listen((_) => changes++);
    addTearDown(sub.cancel);

    blocks.completeInitial(<String>{});
    await pumpEventQueue();
    expect(changes, 0);

    blocks.completeInitial(<String>{'creator-a'});
    await pumpEventQueue();
    expect(changes, 1);

    blocks.completeInitial(<String>{'creator-a'});
    await pumpEventQueue();
    expect(changes, 1);

    blocks.completeInitial(<String>{});
    await pumpEventQueue();
    expect(changes, 2);
  });

  test('watchVisibilityChanges fires once when an unknown block list becomes known, not for a repeat', () async {
    final FakeUserBlockRepository pending = FakeUserBlockRepository.pending();
    final MoodRepositoryImpl unloaded = MoodRepositoryImpl(
      client,
      pending,
      SettingsLocalDataSource(InMemoryLocalStore()),
      feed,
      random: Random(1),
      now: () => DateTime.utc(2026, 10, 28),
    );
    int changes = 0;
    final StreamSubscription<void> sub = unloaded.watchVisibilityChanges().listen((_) => changes++);
    addTearDown(sub.cancel);

    pending.completeInitial(<String>{});
    await pumpEventQueue();
    expect(changes, 1);

    pending.completeInitial(<String>{});
    await pumpEventQueue();
    expect(changes, 1);
  });

  test('watchVisibilityChanges gives each listener an independent deduplication state', () async {
    final Stream<void> changes = repository.watchVisibilityChanges();
    int firstListenerChanges = 0;
    int secondListenerChanges = 0;
    final StreamSubscription<void> first = changes.listen((_) => firstListenerChanges++);
    final StreamSubscription<void> second = changes.listen((_) => secondListenerChanges++);
    addTearDown(first.cancel);
    addTearDown(second.cancel);

    blocks.completeInitial(<String>{});
    await pumpEventQueue();
    expect(firstListenerChanges, 0);
    expect(secondListenerChanges, 0);

    blocks.completeInitial(<String>{'creator-a'});
    await pumpEventQueue();
    expect(firstListenerChanges, 1);
    expect(secondListenerChanges, 1);

    blocks.completeInitial(<String>{'creator-a'});
    await pumpEventQueue();
    expect(firstListenerChanges, 1);
    expect(secondListenerChanges, 1);

    await first.cancel();
    blocks.completeInitial(<String>{});
    await pumpEventQueue();
    expect(firstListenerChanges, 1);
    expect(secondListenerChanges, 2);
  });

  test('separate visibility streams each emit blocked-creator changes', () async {
    int firstListenerChanges = 0;
    int secondListenerChanges = 0;
    final StreamSubscription<void> first = repository.watchVisibilityChanges().listen((_) => firstListenerChanges++);
    final StreamSubscription<void> second = repository.watchVisibilityChanges().listen((_) => secondListenerChanges++);
    addTearDown(first.cancel);
    addTearDown(second.cancel);

    blocks.completeInitial(<String>{});
    await pumpEventQueue();
    blocks.completeInitial(<String>{'creator-a'});
    await pumpEventQueue();

    expect(firstListenerChanges, 1);
    expect(secondListenerChanges, 1);
  });
}
