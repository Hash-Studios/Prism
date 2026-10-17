import 'dart:async';
import 'dart:io';

import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/coins/economy_config.dart';
import 'package:Prism/core/constants/app_constants.dart' as app_constants;
import 'package:Prism/core/firestore/firestore_query_specs.dart';
import 'package:Prism/core/firestore/firestore_error.dart';
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

FakeDocRow _user(
  String uid, {
  int? weekXp,
  String week = _week,
  int xp = 0,
  bool deleted = false,
  String? frame,
  bool premium = false,
}) => (
  id: uid,
  data: <String, dynamic>{
    'name': 'Name $uid',
    'username': 'user_$uid',
    'profilePhoto': 'https://x/$uid.jpg',
    'xp': xp,
    if (weekXp != null) 'xpWeek': <String, dynamic>{'weekKey': week, 'xp': weekXp},
    if (deleted) 'deleted': true,
    if (frame != null) 'cosmetics': <String, dynamic>{'frame': frame},
    if (premium) 'premium': true,
  },
);

class _BlockingFriendStore extends DurableJsonStore {
  _BlockingFriendStore(Directory directory) : super('leaderboard', directory: directory);

  final Completer<void> writeStarted = Completer<void>();
  final Completer<void> allowWrite = Completer<void>();
  bool _blocked = false;

  @override
  Future<void> write(String key, Map<String, Object?> value) async {
    if (key.startsWith('friends:') && !_blocked) {
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
    test('sorts by weekly xp then uid, zeroes stale weeks, skips deleted and adds my row', () async {
      firestore.onQuery = (_) => <FakeDocRow>[
        _user('c', weekXp: 80),
        _user('b', weekXp: 80),
        _user('d', weekXp: 500, week: '2026-W41', xp: 600),
        _user('e', weekXp: 999, deleted: true),
        _user('a', weekXp: 10, frame: 'frame_ring', premium: true),
      ];

      final Result<List<LeaderboardEntry>> result = await repository.fetchFriends(<String>['x@x.com'], _week);
      final List<LeaderboardEntry> entries = result.data!;

      expect(entries.map((e) => (e.uid, e.xp)), <(String, int)>[('b', 80), ('c', 80), ('me', 50), ('a', 10), ('d', 0)]);
      expect(entries.firstWhere((e) => e.uid == 'me').isMe, isTrue);
      expect(entries.firstWhere((e) => e.uid == 'me').rank, 'silver');
      expect(entries.firstWhere((e) => e.uid == 'a').frameId, 'frame_ring');
      expect(entries.firstWhere((e) => e.uid == 'a').premium, isTrue);
      expect(entries.firstWhere((e) => e.uid == 'b').premium, isFalse);
      expect(entries.firstWhere((e) => e.uid == 'd').rank, 'silver');
    });

    test('reads at most 90 emails in chunks of 30', () async {
      firestore.onQuery = (_) => const <FakeDocRow>[];
      final List<String> emails = <String>[for (int i = 0; i < 120; i++) 'u$i@x.com'];

      await repository.fetchFriends(<String>[...emails, 'u0@x.com', ' '], _week);

      expect(firestore.querySpecs, hasLength(3));
      for (final FirestoreQuerySpec spec in firestore.querySpecs) {
        expect(spec.sourceTag, 'leaderboard.friends');
        expect(spec.collection, 'usersv2');
        expect(spec.filters.single.field, 'email');
        expect(spec.filters.single.op, FirestoreFilterOp.whereIn);
        expect(spec.filters.single.value! as List<Object?>, hasLength(30));
      }
      final List<Object?> sent = firestore.querySpecs.expand((s) => s.filters.single.value! as List<Object?>).toList();
      expect(sent, emails.take(90));
    });

    test('with nobody followed it still returns my own row and reads nothing', () async {
      final List<LeaderboardEntry> entries = (await repository.fetchFriends(const <String>[], _week)).data!;

      expect(entries.single.isMe, isTrue);
      expect(entries.single.xp, 50);
      expect(firestore.querySpecs, isEmpty);
    });

    test('a read error becomes a failure', () async {
      firestore.queryError = StateError('boom');

      final Result<List<LeaderboardEntry>> result = await repository.fetchFriends(<String>['a@x.com'], _week);

      expect(result.isFailure, isTrue);
    });

    test('friends snapshot survives restart only for the same owner, week and query, then clears', () async {
      firestore.onQuery = (_) => [_user('a', weekXp: 30)];
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

    test('clearForUser removes the owner-keyed friends snapshot', () async {
      firestore.onQuery = (_) => [_user('a', weekXp: 30)];
      await repository.fetchFriends(<String>['a@x.com'], _week);
      final DurableJsonStore store = DurableJsonStore('leaderboard', directory: directory);
      expect(await store.read('friends:me'), isNotNull);
      await LeaderboardRepositoryImpl.clearForUser('me', store: store);
      expect(await store.read('friends:me'), isNull);
    });

    test('clear is serialized with friend writes and preserves a newer same-owner read', () async {
      List<FakeDocRow> rows = <FakeDocRow>[_user('old', weekXp: 20)];
      firestore.onQuery = (_) => rows;
      final _BlockingFriendStore store = _BlockingFriendStore(directory);
      final LeaderboardRepositoryImpl racing = LeaderboardRepositoryImpl(firestore, store: store);

      final Future<Result<List<LeaderboardEntry>>> oldRead = racing.fetchFriends(<String>['a@x.com'], _week);
      await store.writeStarted.future;
      final Future<void> clearing = LeaderboardRepositoryImpl.clearForUser('me', store: store);
      rows = <FakeDocRow>[_user('new', weekXp: 80)];
      final Future<Result<List<LeaderboardEntry>>> newRead = racing.fetchFriends(<String>['a@x.com'], _week);
      store.allowWrite.complete();

      expect((await oldRead).isFailure, isTrue);
      await clearing;
      expect((await newRead).data!.any((entry) => entry.uid == 'new'), isTrue);
      final Map<String, Object?>? snapshot = await store.read('friends:me');
      expect((snapshot!['entries'] as List).whereType<Map>().any((entry) => entry['uid'] == 'new'), isTrue);
    });

    test('repository timeout falls back to the saved friends snapshot', () async {
      firestore.onQuery = (_) => [_user('a', weekXp: 30)];
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
