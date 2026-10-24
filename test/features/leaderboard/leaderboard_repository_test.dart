import 'dart:async';
import 'dart:io';

import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/coins/economy_config.dart';
import 'package:Prism/core/constants/app_constants.dart' as app_constants;
import 'package:Prism/core/firestore/firestore_error.dart';
import 'package:Prism/core/firestore/firestore_query_specs.dart';
import 'package:Prism/core/offline/durable_json_store.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/features/leaderboard/data/repositories/leaderboard_repository_impl.dart';
import 'package:Prism/features/leaderboard/domain/entities/leaderboard_entry.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_firestore_client.dart';

class _NeverQueryClient extends FakeFirestoreClient {
  @override
  Stream<({List<T> items, bool isFromCache})> watchQueryWithMetadata<T>(
    FirestoreQuerySpec spec,
    T Function(Map<String, dynamic> data, String docId) map,
  ) => Stream<({List<T> items, bool isFromCache})>.empty();
}

class _MetadataFirestoreClient extends FakeFirestoreClient {
  @override
  Stream<({List<T> items, bool isFromCache})> watchQueryWithMetadata<T>(
    FirestoreQuerySpec spec,
    T Function(Map<String, dynamic> data, String docId) map,
  ) async* {
    yield (items: <T>[], isFromCache: true);
    yield (items: await query<T>(spec, map), isFromCache: false);
  }

  @override
  Future<List<T>> query<T>(FirestoreQuerySpec spec, T Function(Map<String, dynamic> data, String docId) map) async {
    querySpecs.add(spec);
    if (queryError case final Object error) throw error;
    final FirestoreFilter? idFilter = spec.filters
        .where((FirestoreFilter filter) => filter.field == firestoreDocumentIdField)
        .firstOrNull;
    if (idFilter != null) {
      final String id = idFilter.value! as String;
      final Map<String, dynamic>? data = docs[spec.collection]?[id];
      return data == null ? <T>[] : <T>[map(data, id)];
    }
    return (onQuery?.call(spec) ?? const <FakeDocRow>[])
        .map((FakeDocRow row) => map(row.data, row.id))
        .toList(growable: false);
  }
}

const String _week = '2026-W42';

FakeDocRow _follow(String uid) => (id: uid, data: <String, dynamic>{'targetUid': uid});

Map<String, dynamic> _boardRow(String uid, int xp) => <String, dynamic>{
  'uid': uid,
  'name': 'Name $uid',
  'username': 'user_$uid',
  'xp': xp,
  'rank': 'silver',
};

class _BlockingFriendStore extends DurableJsonStore {
  _BlockingFriendStore(Directory directory) : super('leaderboard', directory: directory);

  final Completer<void> writeStarted = Completer<void>();
  final Completer<void> allowWrite = Completer<void>();
  bool _blocked = false;

  @override
  Future<void> write(String key, Map<String, Object?> value) async {
    if (key.startsWith('friends-public-v2:') && !_blocked) {
      _blocked = true;
      writeStarted.complete();
      await allowWrite.future;
    }
    await super.write(key, value);
  }
}

void main() {
  late FakeFirestoreClient firestore;
  late LeaderboardRepositoryImpl repository;
  late Directory directory;

  setUp(() {
    firestore = _MetadataFirestoreClient();
    directory = Directory.systemTemp.createTempSync('prism-leaderboard-test');
    repository = LeaderboardRepositoryImpl(firestore, store: DurableJsonStore('leaderboard', directory: directory));
    app_state.prismUser = app_constants.createGuestPrismUser()
      ..id = 'me'
      ..name = 'Me'
      ..username = 'me_user'
      ..loggedIn = true;
    CoinsService.instance.xpNotifier.value = XpStatus(xp: 700, weekXp: 50, rank: EconomyConfig.current.rankFor(700));
  });

  tearDown(() {
    app_state.prismUser = app_constants.createGuestPrismUser();
    CoinsService.instance.xpNotifier.value = XpStatus.empty();
    directory.deleteSync(recursive: true);
  });

  group('fetchGlobal', () {
    test('maps the entries of leaderboards/current and marks my row', () async {
      firestore.docs['leaderboards'] = <String, Map<String, dynamic>>{
        'current': <String, dynamic>{
          'weekKey': _week,
          'entries': <Map<String, dynamic>>[
            <String, dynamic>{
              'uid': 'a',
              'name': 'Ana',
              'username': 'ana',
              'photo': 'https://x/a.jpg',
              'xp': 120,
              'rank': 'silver',
              'frame': 'frame_ring',
              'premium': true,
            },
            <String, dynamic>{
              'uid': 'me',
              'name': 'Me',
              'username': 'me_user',
              'photo': '',
              'xp': 90,
              'rank': 'bronze',
            },
          ],
        },
      };

      final List<LeaderboardEntry> entries = (await repository.fetchGlobal()).data!;

      expect(entries.map((e) => (e.uid, e.xp, e.rank, e.frameId, e.isMe)), <(String, int, String, String?, bool)>[
        ('a', 120, 'silver', 'frame_ring', false),
        ('me', 90, 'bronze', null, true),
      ]);
      expect(entries.map((e) => e.premium), <bool>[true, false]);
    });

    test('a missing board is an empty list', () async {
      expect((await repository.fetchGlobal()).data, isEmpty);
    });
  });

  group('fetchFriends', () {
    test('uses UID follow edges and only matching public snapshot rows', () async {
      firestore.onQuery = (FirestoreQuerySpec spec) =>
          spec.collection == 'profiles/me/following' ? <FakeDocRow>[_follow('a'), _follow('b')] : const <FakeDocRow>[];
      firestore.docs['leaderboards'] = <String, Map<String, dynamic>>{
        'current': <String, dynamic>{
          'weekKey': _week,
          'entries': <Map<String, dynamic>>[_boardRow('a', 10), _boardRow('b', 80), _boardRow('stranger', 999)],
        },
      };

      final Result<List<LeaderboardEntry>> result = await repository.fetchFriends(<String>['x@x.com'], _week);
      final List<LeaderboardEntry> entries = result.data!;

      expect(entries.map((e) => (e.uid, e.xp)), <(String, int)>[('b', 80), ('me', 50), ('a', 10)]);
      expect(entries.firstWhere((e) => e.uid == 'me').isMe, isTrue);
      expect(entries.firstWhere((e) => e.uid == 'me').rank, 'silver');
      expect(firestore.querySpecs.map((spec) => spec.collection), contains('profiles/me/following'));
      expect(firestore.querySpecs.map((spec) => spec.collection), isNot(contains('usersv2')));
      expect(firestore.querySpecs.map((spec) => spec.collection), contains('leaderboards'));
    });

    test('with nobody followed it returns my own row after reading the follow graph', () async {
      final List<LeaderboardEntry> entries = (await repository.fetchFriends(const <String>[], _week)).data!;

      expect(entries.single.isMe, isTrue);
      expect(entries.single.xp, 50);
      expect(firestore.querySpecs.map((spec) => spec.collection), <String>['profiles/me/following']);
    });

    test('rejects a published snapshot from a different week', () async {
      firestore.onQuery = (spec) => spec.collection == 'profiles/me/following' ? [_follow('a')] : const [];
      firestore.docs['leaderboards'] = <String, Map<String, dynamic>>{
        'current': <String, dynamic>{
          'weekKey': '2026-W41',
          'entries': <Map<String, dynamic>>[_boardRow('a', 300)],
        },
      };

      final List<LeaderboardEntry> entries = (await repository.fetchFriends(const <String>[], _week)).data!;

      expect(entries.map((entry) => entry.uid), <String>['me']);
    });

    test('a read error becomes a failure', () async {
      firestore.queryError = StateError('boom');

      final Result<List<LeaderboardEntry>> result = await repository.fetchFriends(<String>['a@x.com'], _week);

      expect(result.isFailure, isTrue);
    });

    test('friends snapshot survives restart for the same owner and week, then clears', () async {
      firestore.onQuery = (spec) => spec.collection == 'profiles/me/following' ? [_follow('a')] : const [];
      firestore.docs['leaderboards'] = <String, Map<String, dynamic>>{
        'current': <String, dynamic>{
          'weekKey': _week,
          'entries': <Map<String, dynamic>>[_boardRow('a', 30)],
        },
      };
      expect((await repository.fetchFriends(<String>['a@x.com'], _week)).data!.any((e) => e.uid == 'a'), isTrue);

      final FakeFirestoreClient offline = _MetadataFirestoreClient()
        ..queryError = FirestoreError(code: 'unavailable', message: 'offline');
      final DurableJsonStore store = DurableJsonStore('leaderboard', directory: directory);
      final LeaderboardRepositoryImpl restarted = LeaderboardRepositoryImpl(offline, store: store);
      expect((await restarted.fetchFriends(<String>['a@x.com'], _week)).data!.any((e) => e.uid == 'a'), isTrue);

      final FakeFirestoreClient empty = _MetadataFirestoreClient();
      final LeaderboardRepositoryImpl authoritative = LeaderboardRepositoryImpl(empty, store: store);
      expect((await authoritative.fetchFriends(<String>['a@x.com'], _week)).data!.any((e) => e.uid == 'a'), isFalse);
      empty.queryError = FirestoreError(code: 'unavailable', message: 'offline');
      expect((await authoritative.fetchFriends(<String>['a@x.com'], _week)).data!.any((e) => e.uid == 'a'), isFalse);

      app_state.prismUser = app_constants.createGuestPrismUser()
        ..id = 'other'
        ..loggedIn = true;
      expect((await restarted.fetchFriends(<String>['a@x.com'], _week)).isFailure, isTrue);
    });

    test('does not accept the old email-keyed snapshot format', () async {
      final DurableJsonStore store = DurableJsonStore('leaderboard', directory: directory);
      await store.write('friends:me', <String, Object?>{
        'weekKey': _week,
        'uids': <String>['a@x.com'],
        'entries': <Map<String, Object?>>[
          <String, Object?>{'uid': 'private-old', 'xp': 999},
        ],
      });
      final LeaderboardRepositoryImpl offline = LeaderboardRepositoryImpl(
        _MetadataFirestoreClient()..queryError = FirestoreError(code: 'unavailable', message: 'offline'),
        store: store,
      );

      expect((await offline.fetchFriends(<String>['a@x.com'], _week)).isFailure, isTrue);
    });

    test('clearForUser removes the owner-keyed friends snapshot', () async {
      firestore.onQuery = (spec) => spec.collection == 'profiles/me/following' ? [_follow('a')] : const [];
      firestore.docs['leaderboards'] = <String, Map<String, dynamic>>{
        'current': <String, dynamic>{
          'weekKey': _week,
          'entries': <Map<String, dynamic>>[_boardRow('a', 30)],
        },
      };
      await repository.fetchFriends(<String>['a@x.com'], _week);
      final DurableJsonStore store = DurableJsonStore('leaderboard', directory: directory);
      expect(await store.read('friends-public-v2:me'), isNotNull);
      await LeaderboardRepositoryImpl.clearForUser('me', store: store);
      expect(await store.read('friends-public-v2:me'), isNull);
    });

    test('clear is serialized with friend writes and preserves a newer same-owner read', () async {
      List<Map<String, dynamic>> rows = <Map<String, dynamic>>[_boardRow('old', 20)];
      firestore.onQuery = (spec) =>
          spec.collection == 'profiles/me/following' ? [_follow('old'), _follow('new')] : const [];
      firestore.docs['leaderboards'] = <String, Map<String, dynamic>>{
        'current': <String, dynamic>{'weekKey': _week, 'entries': rows},
      };
      final _BlockingFriendStore store = _BlockingFriendStore(directory);
      final LeaderboardRepositoryImpl racing = LeaderboardRepositoryImpl(firestore, store: store);

      final Future<Result<List<LeaderboardEntry>>> oldRead = racing.fetchFriends(<String>['a@x.com'], _week);
      await store.writeStarted.future;
      final Future<void> clearing = LeaderboardRepositoryImpl.clearForUser('me', store: store);
      rows = <Map<String, dynamic>>[_boardRow('new', 80)];
      firestore.docs['leaderboards']!['current']!['entries'] = rows;
      final Future<Result<List<LeaderboardEntry>>> newRead = racing.fetchFriends(<String>['a@x.com'], _week);
      store.allowWrite.complete();

      expect((await oldRead).isFailure, isTrue);
      await clearing;
      expect((await newRead).data!.any((entry) => entry.uid == 'new'), isTrue);
      final Map<String, Object?>? snapshot = await store.read('friends-public-v2:me');
      expect((snapshot!['entries'] as List).whereType<Map>().any((entry) => entry['uid'] == 'new'), isTrue);
    });

    test('repository timeout falls back to the saved friends snapshot', () async {
      firestore.onQuery = (spec) => spec.collection == 'profiles/me/following' ? [_follow('a')] : const [];
      firestore.docs['leaderboards'] = <String, Map<String, dynamic>>{
        'current': <String, dynamic>{
          'weekKey': _week,
          'entries': <Map<String, dynamic>>[_boardRow('a', 30)],
        },
      };
      await repository.fetchFriends(<String>['a@x.com'], _week);
      final LeaderboardRepositoryImpl timedOut = LeaderboardRepositoryImpl(
        _NeverQueryClient(),
        store: DurableJsonStore('leaderboard', directory: directory),
        readTimeout: const Duration(milliseconds: 1),
      );
      expect((await timedOut.fetchFriends(<String>['a@x.com'], _week)).data!.any((e) => e.uid == 'a'), isTrue);
    });
  });
}
