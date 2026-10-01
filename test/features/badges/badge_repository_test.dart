import 'dart:async';

import 'package:Prism/auth/badge_model.dart';
import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/constants/app_constants.dart' as app_constants;
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/firestore/firestore_client.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/utils/result.dart' as result_types;
import 'package:Prism/features/badges/data/repositories/badge_repository_impl.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/coins_test_backend.dart';
import '../../support/fake_app_analytics.dart';

class _FailingRefreshFirestore extends CoinsTestFirestore {
  final Completer<void> readStarted = Completer<void>();
  final Completer<Map<String, dynamic>> response = Completer<Map<String, dynamic>>();

  @override
  Future<T?> getById<T>(
    String collection,
    String id,
    T Function(Map<String, dynamic>, String) map, {
    required String sourceTag,
    bool preferCacheFirst = false,
  }) async {
    getByIdCalls++;
    readStarted.complete();
    return map(await response.future, id);
  }
}

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

  test('concurrent checks for different accounts do not share a request', () async {
    final Completer<void> firstStarted = Completer<void>();
    final Completer<void> secondStarted = Completer<void>();
    final Completer<dynamic> firstResponse = Completer<dynamic>();
    final Completer<dynamic> secondResponse = Completer<dynamic>();
    backend.onCall = (_, _) {
      calls++;
      if (calls == 1) {
        firstStarted.complete();
        return firstResponse.future;
      }
      secondStarted.complete();
      return secondResponse.future;
    };

    final Future<result_types.Result<List<Badge>>> firstCheck = repo.check();
    await firstStarted.future;
    app_state.prismUser.id = 'another-user';
    final Future<result_types.Result<List<Badge>>> secondCheck = repo.check();
    await secondStarted.future;
    secondResponse.complete(<String, Object>{'newBadges': <Object>[], 'badges': <Object>[], 'currentBalance': 100});
    expect((await secondCheck).isSuccess, isTrue);
    firstResponse.complete(<String, Object>{'newBadges': <Object>[], 'badges': <Object>[], 'currentBalance': 100});
    expect((await firstCheck).isFailure, isTrue);
    expect(calls, 2);
  });

  test('a stale badge response refreshes balance after a concurrent coin mutation', () async {
    final Completer<void> started = Completer<void>();
    final Completer<dynamic> response = Completer<dynamic>();
    final CoinsTestFirestore firestore = CoinsTestFirestore()..userData = <String, dynamic>{'coins': 175};
    getIt.registerSingleton<FirestoreClient>(firestore);
    backend.onCall = (_, _) {
      started.complete();
      return response.future;
    };

    final Future<result_types.Result<List<Badge>>> check = repo.check();
    await started.future;
    CoinsService.instance.applyServerBalance(125);
    response.complete(<String, Object>{'newBadges': <Object>[], 'badges': <Object>[], 'currentBalance': 110});

    expect((await check).isSuccess, isTrue);
    expect(firestore.getByIdCalls, 1);
    expect(app_state.prismUser.coins, 175);
    expect(CoinsService.instance.balanceNotifier.value, 175);
  });

  test('an ABA balance change still refreshes after a stale badge response', () async {
    final Completer<void> started = Completer<void>();
    final Completer<dynamic> response = Completer<dynamic>();
    final CoinsTestFirestore firestore = CoinsTestFirestore()..userData = <String, dynamic>{'coins': 100};
    getIt.registerSingleton<FirestoreClient>(firestore);
    backend.onCall = (_, _) {
      started.complete();
      return response.future;
    };

    final Future<result_types.Result<List<Badge>>> check = repo.check();
    await started.future;
    CoinsService.instance.applyServerBalance(125);
    CoinsService.instance.applyServerBalance(100);
    response.complete(<String, Object>{'newBadges': <Object>[], 'badges': <Object>[], 'currentBalance': 110});

    expect((await check).isSuccess, isTrue);
    expect(firestore.getByIdCalls, 1);
    expect(app_state.prismUser.coins, 100);
    expect(CoinsService.instance.balanceNotifier.value, 100);
  });

  test('a failed stale-balance refresh still processes awarded badge metadata', () async {
    final Completer<void> started = Completer<void>();
    final Completer<dynamic> response = Completer<dynamic>();
    final FakeAppAnalytics recorder = FakeAppAnalytics();
    AnalyticsRuntime.instance = recorder;
    addTearDown(AnalyticsRuntime.reset);
    final _FailingRefreshFirestore firestore = _FailingRefreshFirestore();
    getIt.registerSingleton<FirestoreClient>(firestore);
    backend.onCall = (_, _) {
      started.complete();
      return response.future;
    };

    final Future<result_types.Result<List<Badge>>> check = repo.check();
    await started.future;
    CoinsService.instance.applyServerBalance(125);
    response.complete(<String, Object>{
      'newBadges': <Object>[
        <String, Object>{'id': 'creator', 'coins': 50},
      ],
      'badges': <Object>[_badge('creator')],
      'currentBalance': 110,
    });
    await firestore.readStarted.future;
    firestore.response.completeError(StateError('offline'));

    expect((await check).isSuccess, isTrue);
    expect(app_state.prismUser.coins, 125);
    expect(repo.unseen.value.map((badge) => badge.id), <String>['creator']);
    expect(recorder.events.whereType<BadgeEarnedEvent>(), hasLength(1));
  });

  test('duplicate badge ids in one response queue and track only once', () async {
    final FakeAppAnalytics recorder = FakeAppAnalytics();
    AnalyticsRuntime.instance = recorder;
    addTearDown(AnalyticsRuntime.reset);
    backend.onCall = (_, _) async => <String, Object>{
      'newBadges': <Object>[
        <String, Object>{'id': 'creator', 'coins': 50},
        <String, Object>{'id': 'creator', 'coins': 50},
      ],
      'badges': <Object>[_badge('creator')],
      'currentBalance': 150,
    };

    await repo.check();

    expect(repo.unseen.value, hasLength(1));
    expect(recorder.events.whereType<BadgeEarnedEvent>(), hasLength(1));
    repo.markSeen('creator');
    await repo.check();
    expect(repo.unseen.value, isEmpty);
    expect(recorder.events.whereType<BadgeEarnedEvent>(), hasLength(1));
  });

  test('a malformed response preserves session badges and balance', () async {
    app_state.prismUser.badges = <Badge>[
      Badge(name: 'n', description: 'd', id: 'collector', awardedAt: '', imageUrl: '', color: '', url: ''),
    ];
    backend.onCall = (_, _) async => <String, Object>{'newBadges': <Object>[], 'currentBalance': 1};

    final result = await repo.check();

    expect(result.isFailure, isTrue);
    expect(app_state.prismUser.badges.map((b) => b.id), <String>['collector']);
    expect(app_state.prismUser.coins, 100);
    expect(repo.unseen.value, isEmpty);
  });

  test('switching accounts clears the previous account unseen queue', () async {
    backend.onCall = (_, _) async => <String, Object>{
      'newBadges': <Object>[
        <String, Object>{'id': 'creator', 'coins': 50},
      ],
      'badges': <Object>[_badge('creator')],
      'currentBalance': 150,
    };
    await repo.check();
    expect(repo.unseen.value, hasLength(1));

    app_state.prismUser.id = 'another-user';

    expect(repo.unseen.value, isEmpty);
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

  test('a response after sign-out is dropped even if the user id is unchanged', () async {
    backend.onCall = (_, _) async {
      app_state.prismUser.loggedIn = false;
      return <String, Object>{
        'newBadges': <Object>[
          <String, Object>{'id': 'creator', 'coins': 50},
        ],
        'badges': <Object>[_badge('creator')],
        'currentBalance': 150,
      };
    };

    final result = await repo.check();

    expect(result.isFailure, isTrue);
    expect(app_state.prismUser.badges, isEmpty);
    expect(app_state.prismUser.coins, 100);
    expect(repo.unseen.value, isEmpty);
  });
}
