import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/coins/economy_config.dart';
import 'package:Prism/core/constants/app_constants.dart' as app_constants;
import 'package:Prism/core/firestore/firestore_query_specs.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/features/leaderboard/data/repositories/leaderboard_repository_impl.dart';
import 'package:Prism/features/leaderboard/domain/entities/leaderboard_entry.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_firestore_client.dart';

const String _week = '2026-W42';

FakeDocRow _user(String uid, {int? weekXp, String week = _week, int xp = 0, bool deleted = false, String? frame}) => (
  id: uid,
  data: <String, dynamic>{
    'name': 'Name $uid',
    'username': 'user_$uid',
    'profilePhoto': 'https://x/$uid.jpg',
    'xp': xp,
    if (weekXp != null) 'xpWeek': <String, dynamic>{'weekKey': week, 'xp': weekXp},
    if (deleted) 'deleted': true,
    if (frame != null) 'cosmetics': <String, dynamic>{'frame': frame},
  },
);

void main() {
  late FakeFirestoreClient firestore;
  late LeaderboardRepositoryImpl repository;

  setUp(() {
    firestore = FakeFirestoreClient();
    repository = LeaderboardRepositoryImpl(firestore);
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
        _user('a', weekXp: 10, frame: 'frame_ring'),
      ];

      final Result<List<LeaderboardEntry>> result = await repository.fetchFriends(<String>['x@x.com'], _week);
      final List<LeaderboardEntry> entries = result.data!;

      expect(entries.map((e) => (e.uid, e.xp)), <(String, int)>[('b', 80), ('c', 80), ('me', 50), ('a', 10), ('d', 0)]);
      expect(entries.firstWhere((e) => e.uid == 'me').isMe, isTrue);
      expect(entries.firstWhere((e) => e.uid == 'me').rank, 'silver');
      expect(entries.firstWhere((e) => e.uid == 'a').frameId, 'frame_ring');
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
  });
}
