import 'package:Prism/auth/badge_model.dart';
import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/constants/app_constants.dart' as app_constants;
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/features/badges/data/repositories/badge_repository_impl.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/coins_test_backend.dart';

Map<String, Object> _badge(String id) => <String, Object>{
  'id': id,
  'name': 'Name $id',
  'description': 'Desc $id',
  'awardedAt': '2026-10-01T00:00:00.000Z',
  'imageUrl': '',
  'color': '',
  'url': '',
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final backend = CoinsTestBackend();
  late BadgeRepositoryImpl repo;
  late int calls;

  setUp(() async {
    await backend.install();
    calls = 0;
    repo = BadgeRepositoryImpl();
  });

  tearDown(() async {
    app_state.prismUser = app_constants.createGuestPrismUser();
    await getIt.reset();
  });

  test('success updates session badges and balance and queues new badges', () async {
    backend.onCall = (name, _) async {
      calls++;
      expect(name, 'checkBadges');
      return <String, Object>{
        'newBadges': <Object>[
          <String, Object>{'id': 'week_warrior', 'coins': 25},
        ],
        'badges': <Object>[_badge('week_warrior')],
        'currentBalance': 125,
      };
    };

    final result = await repo.check();

    expect(result.isSuccess, isTrue);
    expect(app_state.prismUser.badges.map((b) => b.id), <String>['week_warrior']);
    expect(app_state.prismUser.coins, 125);
    expect(CoinsService.instance.balanceNotifier.value, 125);
    expect(repo.unseen.value.map((b) => (b.id, b.coins)), <(String, int)>[('week_warrior', 25)]);
  });

  test('a repeated award is queued once, and markSeen removes it', () async {
    backend.onCall = (_, _) async => <String, Object>{
      'newBadges': <Object>[
        <String, Object>{'id': 'creator', 'coins': 50},
      ],
      'badges': <Object>[_badge('creator')],
      'currentBalance': 150,
    };

    await repo.check();
    await repo.check();
    expect(repo.unseen.value, hasLength(1));

    repo.markSeen('creator');
    expect(repo.unseen.value, isEmpty);
  });

  test('concurrent checks share one request', () async {
    backend.onCall = (_, _) async {
      calls++;
      await Future<void>.delayed(const Duration(milliseconds: 20));
      return <String, Object>{'newBadges': <Object>[], 'badges': <Object>[], 'currentBalance': 100};
    };

    final results = await Future.wait(<Future<Object>>[repo.check(), repo.check(), repo.check()]);

    expect(calls, 1);
    expect(results, hasLength(3));
    await repo.check();
    expect(calls, 2);
  });

  test('a failed check keeps the session badges and queues nothing', () async {
    app_state.prismUser.badges = <Badge>[
      Badge(name: 'n', description: 'd', id: 'collector', awardedAt: '', imageUrl: '', color: '', url: ''),
    ];
    backend.onCall = (_, _) async => throw FirebaseFunctionsException(message: 'boom', code: 'internal');

    final result = await repo.check();

    expect(result.isFailure, isTrue);
    expect(app_state.prismUser.badges.map((b) => b.id), <String>['collector']);
    expect(repo.unseen.value, isEmpty);
  });

  test('signed-out users never call the server', () async {
    app_state.prismUser.loggedIn = false;
    backend.onCall = (_, _) async {
      calls++;
      return <String, Object>{};
    };

    final result = await repo.check();

    expect(result.isFailure, isTrue);
    expect(calls, 0);
  });

  test('a response that lands after the account changed is dropped', () async {
    backend.onCall = (_, _) async {
      app_state.prismUser.id = 'someone-else';
      return <String, Object>{
        'newBadges': <Object>[
          <String, Object>{'id': 'creator', 'coins': 50},
        ],
        'badges': <Object>[_badge('creator')],
        'currentBalance': 999,
      };
    };

    final result = await repo.check();

    expect(result.isFailure, isTrue);
    expect(app_state.prismUser.badges, isEmpty);
    expect(repo.unseen.value, isEmpty);
  });
}
