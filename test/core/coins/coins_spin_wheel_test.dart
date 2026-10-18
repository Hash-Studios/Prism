import 'dart:async';

import 'package:Prism/auth/user_model.dart';
import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/analytics/events/analytics_event.dart';
import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/coins/economy_config.dart';
import 'package:Prism/core/coins/spin_wheel.dart';
import 'package:Prism/core/constants/app_constants.dart' as app_constants;
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/firestore/firestore_client.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/features/session/domain/entities/session_entity.dart';
import 'package:Prism/features/session/domain/repositories/session_repository.dart';
import 'package:cloud_functions/cloud_functions.dart' show FirebaseFunctionsException;
import 'package:flutter_test/flutter_test.dart';

import '../../support/coins_test_backend.dart';
import '../../support/fake_app_analytics.dart';
import 'spin_wheel_test_helpers.dart';

const Map<String, Object> _afterPaidSpin = <String, Object>{
  'freeSpinAvailable': false,
  'paidSpinsLeft': 4,
  'price': 10,
};

/// A landed spin the way the server replies, for a Pro member with 100 coins before the spin.
Map<String, Object?> _spun({
  int segment = 0,
  String kind = 'coins',
  int coins = 0,
  int xp = 0,
  String? itemId,
  bool free = false,
  Map<String, Object> status = _afterPaidSpin,
  Object? segments = defaultWheelJson,
  bool omitSegments = false,
}) {
  final int cost = free ? 0 : 10;
  return <String, Object?>{
    'success': true,
    'changed': true,
    'previousBalance': 100,
    'currentBalance': 100 - cost + coins,
    'delta': coins - cost,
    'reason': 'ok',
    'transactionId': 'ctx_spinWheel_test',
    'cost': cost,
    'free': free,
    'segment': segment,
    'prize': <String, Object?>{'kind': kind, 'coins': coins, 'xp': xp, 'itemId': itemId},
    if (!omitSegments) 'segments': segments,
    'status': status,
  };
}

Map<String, Object?> _refused(String reason, Map<String, Object> status, {bool insufficient = false}) =>
    <String, Object?>{
      'success': false,
      'changed': false,
      'previousBalance': 100,
      'currentBalance': 100,
      'delta': 0,
      'reason': reason,
      if (insufficient) 'insufficientBalance': true,
      'status': status,
    };

Map<String, Object?> _bonusQuests({required String dayKey, required bool claimed}) => <String, Object?>{
  'dayKey': dayKey,
  'items': <Object>[],
  'bonus': <String, Object?>{
    'id': 'pro_spin',
    'event': 'pro_spin',
    'target': 1,
    'progress': claimed ? 1 : 0,
    'claimed': claimed,
  },
  'weekKey': '2026-W42',
};

(bool, int, int) _fields(SpinWheelStatus s) => (s.freeSpinAvailable, s.paidSpinsLeft, s.price);

class _FakeSession extends Fake implements SessionRepository {
  _FakeSession(this.currentUser);

  @override
  PrismUsersV2 currentUser;
  final StreamController<PrismUsersV2> _users = StreamController<PrismUsersV2>.broadcast();

  @override
  Stream<PrismUsersV2> watchCurrentUser() async* {
    yield currentUser;
    yield* _users.stream;
  }

  @override
  Future<Result<SessionEntity>> replaceCurrentUser(PrismUsersV2 user) async {
    currentUser = user;
    _users.add(user);
    return Result.success(SessionEntity.guest);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final CoinsTestBackend backend = CoinsTestBackend();
  final CoinsService service = CoinsService.instance;
  final RegExp idPattern = RegExp(r'^[A-Za-z0-9_-]{8,64}$');
  late List<(String, Map<String, dynamic>)> calls;
  late FakeAppAnalytics analytics;

  void reply(Object? Function(String name, Map<String, dynamic> params) answer) {
    backend.onCall = (String name, Map<String, dynamic> params) async {
      calls.add((name, params));
      return answer(name, params);
    };
  }

  Future<SpinWon> spinWon({int maxCost = 10}) async {
    final SpinWheelResult result = await service.spinWheel(maxCost: maxCost);
    expect(result, isA<SpinWon>());
    return result as SpinWon;
  }

  setUp(() async {
    calls = <(String, Map<String, dynamic>)>[];
    analytics = FakeAppAnalytics();
    AnalyticsRuntime.instance = analytics;
    await backend.install();
    app_state.prismUser.premium = true;
    service.balanceNotifier.value = 100;
    service.refreshSpinWheelStatus();
    reply((_, _) => _spun());
  });

  tearDown(() async {
    AnalyticsRuntime.reset();
    app_state.prismUser = app_constants.createGuestPrismUser();
    await service.refreshStreakStatus();
    EconomyConfig.resetForTest();
    await getIt.reset();
  });

  group('a landed spin', () {
    test('a coin win pays the prize and the XP, and names the slice to land on', () async {
      reply((_, _) => _spun(segment: 3, coins: 100));
      final SpinWon won = await spinWon();
      expect((won.win.segment, won.win.coins, won.win.xp, won.win.itemId, won.cost), (3, 100, 0, null, 10));
      expect(describeWheel(won.segments), defaultWheelLines);
      expect(won.balance, 190, reason: 'The reply carries the balance after the spin');
      expect(service.balanceNotifier.value, 190);
      expect(service.xpNotifier.value.xp, 100);
      final (String name, Map<String, dynamic> params) = calls.single;
      expect((name, params['maxCost'], params['sourceTag']), ('spinWheel', 10, 'coins.spin_wheel'));
      expect(params['requestId'], matches(idPattern));
    });

    test('an XP win pays the XP and only charges the price', () async {
      reply((_, _) => _spun(segment: 5, kind: 'xp', xp: 50));
      final SpinWon won = await spinWon();
      expect((won.win.segment, won.win.coins, won.win.xp, won.win.itemId), (5, 0, 50, null));
      expect(won.balance, 90);
      expect(service.balanceNotifier.value, 90);
      expect(service.xpNotifier.value.xp, 50);
    });

    test('a cosmetic win adds the item to the inventory', () async {
      reply((_, _) => _spun(segment: 7, kind: 'cosmetic', itemId: 'frame_ring'));
      final SpinWon won = await spinWon();
      expect((won.win.segment, won.win.coins, won.win.xp, won.win.itemId), (7, 0, 0, 'frame_ring'));
      expect(service.inventoryNotifier.value.owned, <String>{'frame_ring'});
      expect(service.balanceNotifier.value, 90);
      expect(service.xpNotifier.value.xp, 0);
    });

    test('a cosmetic fallback pays its coins and adds no item', () async {
      reply((_, _) => _spun(segment: 7, kind: 'cosmetic', coins: 50));
      final SpinWon won = await spinWon();
      expect((won.win.segment, won.win.coins, won.win.xp, won.win.itemId), (7, 50, 0, null));
      expect(service.inventoryNotifier.value.owned, isEmpty);
      expect(service.balanceNotifier.value, 140);
      expect(service.xpNotifier.value.xp, 50);
    });

    test('a free spin costs nothing and ticks the pro_spin bonus quest', () async {
      final String today = economyDayKey(DateTime.now());
      reply(
        (_, _) => <String, Object?>{'success': true, 'rev': 1, 'quests': _bonusQuests(dayKey: today, claimed: false)},
      );
      await service.progressQuest(null);
      expect(service.questsNotifier.value?.bonus?.claimed, isFalse);
      reply(
        (_, _) => _spun(
          free: true,
          segment: 2,
          coins: 5,
          status: <String, Object>{'freeSpinAvailable': false, 'paidSpinsLeft': 5, 'price': 10},
        ),
      );
      final SpinWon won = await spinWon(maxCost: 0);
      expect((won.cost, won.win.coins), (0, 5));
      expect(service.balanceNotifier.value, 105);
      expect(service.questsNotifier.value?.bonus?.claimed, isTrue);
      expect(calls.last.$2['maxCost'], 0);
    });

    test('a paid spin leaves the pro_spin bonus quest alone', () async {
      final String today = economyDayKey(DateTime.now());
      reply(
        (_, _) => <String, Object?>{'success': true, 'rev': 1, 'quests': _bonusQuests(dayKey: today, claimed: false)},
      );
      await service.progressQuest(null);
      reply((_, _) => _spun(coins: 10));
      await spinWon();
      expect(service.questsNotifier.value?.bonus?.claimed, isFalse);
    });

    test("the reply's table beats the cached config, and a reply without one falls back to the config", () async {
      EconomyConfig.current = EconomyConfig.fromMap(<String, dynamic>{
        'award': <String, dynamic>{
          'spinWheel': <Map<String, Object>>[
            <String, Object>{'kind': 'coins', 'coins': 9, 'weight': 1},
            <String, Object>{'kind': 'xp', 'xp': 9, 'weight': 1},
          ],
        },
      });
      reply(
        (_, _) => _spun(
          segment: 2,
          coins: 5,
          segments: <Map<String, Object>>[
            <String, Object>{'kind': 'xp', 'xp': 1, 'weight': 1},
            <String, Object>{'kind': 'coins', 'coins': 2, 'weight': 1},
            <String, Object>{'kind': 'coins', 'coins': 5, 'weight': 1},
          ],
        ),
      );
      final SpinWon fromReply = await spinWon();
      expect(describeWheel(fromReply.segments), <String>['xp 1 x1', 'coins 2 x1', 'coins 5 x1']);
      expect(fromReply.win.segment, 2);

      reply((_, _) => _spun(segment: 1, kind: 'xp', xp: 9, omitSegments: true));
      final SpinWon fromConfig = await spinWon();
      expect(describeWheel(fromConfig.segments), <String>['coins 9 x1', 'xp 9 x1']);
      reply((_, _) => _spun(segment: 1, kind: 'xp', xp: 9, segments: <Object>['junk']));
      expect(describeWheel((await spinWon()).segments), <String>['coins 9 x1', 'xp 9 x1']);
    });

    test('a slice index outside the table lands on the nearest slice instead of past the end', () async {
      reply((_, _) => _spun(segment: 99, coins: 5));
      expect((await spinWon()).win.segment, 7);
      reply((_, _) => _spun(segment: -4, coins: 5));
      expect((await spinWon()).win.segment, 0);
    });
  });

  group('analytics', () {
    List<Map<String, Object?>> logged() => <Map<String, Object?>>[
      for (final AnalyticsEvent e in analytics.events) <String, Object?>{'event': e.eventName, ...e.toWireParameters()},
    ];
    List<Object?> names() => <Object?>[for (final Map<String, Object?> e in logged()) e['event']];

    test('a paid coin win logs the spin, the price and the prize', () async {
      reply((_, _) => _spun(segment: 3, coins: 100));
      await spinWon();
      expect(logged(), <Map<String, Object?>>[
        <String, Object?>{
          'event': 'spin_wheel_spun',
          'free': 0,
          'cost': 10,
          'segment': 3,
          'prize': 'coins',
          'coins': 100,
          'xp': 0,
        },
        <String, Object?>{
          'event': 'coin_spent',
          'action': 'spin_wheel',
          'amount': 10,
          'balance': 190,
          'source_tag': 'coins.spin_wheel',
        },
        <String, Object?>{
          'event': 'coin_earned',
          'action': 'spin_wheel',
          'amount': 100,
          'balance': 190,
          'source_tag': 'coins.spin_wheel',
        },
      ]);
    });

    test('an XP win logs no coin earned, a free spin logs no coin spent', () async {
      reply((_, _) => _spun(segment: 5, kind: 'xp', xp: 50));
      await spinWon();
      expect(names(), <String>['spin_wheel_spun', 'coin_spent']);
      expect(logged().first, <String, Object?>{
        'event': 'spin_wheel_spun',
        'free': 0,
        'cost': 10,
        'segment': 5,
        'prize': 'xp',
        'coins': 0,
        'xp': 50,
      });

      analytics.events.clear();
      reply((_, _) => _spun(segment: 2, coins: 5, free: true));
      await spinWon(maxCost: 0);
      expect(names(), <String>['spin_wheel_spun', 'coin_earned']);
      expect(logged().first['free'], 1);
    });

    test('a cosmetic and its coin fallback both log the prize as a cosmetic', () async {
      reply((_, _) => _spun(segment: 7, kind: 'cosmetic', itemId: 'frame_ring'));
      await spinWon();
      reply((_, _) => _spun(segment: 7, kind: 'cosmetic', coins: 50));
      await spinWon();
      final List<List<Object?>> spins = <List<Object?>>[
        for (final Map<String, Object?> e in logged())
          if (e['event'] == 'spin_wheel_spun') <Object?>[e['prize'], e['coins'], e['xp']],
      ];
      expect(spins, <List<Object?>>[
        <Object?>['cosmetic', 0, 0],
        <Object?>['cosmetic', 50, 0],
      ]);
    });

    test('a refusal logs nothing', () async {
      reply((_, _) => _refused('spin_wheel_daily_limit', _afterPaidSpin));
      await service.spinWheel(maxCost: 10);
      expect(analytics.events, isEmpty);
    });
  });

  group('refusals', () {
    test('each refusal reason maps to its refusal and carries the status of the reply', () async {
      const Map<String, (SpinRefusal, Map<String, Object>)> cases = <String, (SpinRefusal, Map<String, Object>)>{
        'spin_wheel_insufficient_balance': (
          SpinRefusal.insufficientBalance,
          <String, Object>{'freeSpinAvailable': false, 'paidSpinsLeft': 3, 'price': 10},
        ),
        'spin_wheel_daily_limit': (
          SpinRefusal.dailyLimit,
          <String, Object>{'freeSpinAvailable': false, 'paidSpinsLeft': 0, 'price': 10},
        ),
        'spin_wheel_price_changed': (
          SpinRefusal.priceChanged,
          <String, Object>{'freeSpinAvailable': false, 'paidSpinsLeft': 5, 'price': 12},
        ),
      };
      for (final MapEntry<String, (SpinRefusal, Map<String, Object>)> c in cases.entries) {
        reply((_, _) => _refused(c.key, c.value.$2, insufficient: c.key == 'spin_wheel_insufficient_balance'));
        final SpinWheelResult result = await service.spinWheel(maxCost: 10);
        expect(result, isA<SpinRefused>(), reason: c.key);
        final SpinRefused refused = result as SpinRefused;
        expect(refused.refusal, c.value.$1, reason: c.key);
        final Map<String, Object> wire = c.value.$2;
        expect(_fields(refused.status), (wire['freeSpinAvailable'], wire['paidSpinsLeft'], wire['price']));
        expect(_fields(service.spinWheelNotifier.value), _fields(refused.status), reason: c.key);
        expect(service.balanceNotifier.value, 100, reason: c.key);
        expect(service.xpNotifier.value.xp, 0, reason: c.key);
      }
    });

    test('the insufficient flag alone is enough for an insufficient refusal', () async {
      reply((_, _) => _refused('something_new', _afterPaidSpin, insufficient: true));
      expect((await service.spinWheel(maxCost: 10) as SpinRefused).refusal, SpinRefusal.insufficientBalance);
    });

    test('a refusal the app does not know is a failure with the reason', () async {
      reply((_, _) => _refused('spin_wheel_closed', _afterPaidSpin));
      final SpinWheelResult result = await service.spinWheel(maxCost: 10);
      expect(result, isA<SpinFailed>());
      expect((result as SpinFailed).reason, 'spin_wheel_closed');
    });

    test('a refusal without a status keeps the status the app already shows', () async {
      service.refreshSpinWheelStatus();
      final SpinWheelStatus before = service.spinWheelNotifier.value;
      reply((_, _) => <String, Object?>{'success': false, 'changed': false, 'reason': 'spin_wheel_daily_limit'});
      final SpinRefused refused = await service.spinWheel(maxCost: 10) as SpinRefused;
      expect(refused.status, before);
      expect(_fields(before), (true, 5, 10));
    });
  });

  group('request ids', () {
    test('a lost reply keeps the request id for the next tap, a definite reply clears it', () async {
      backend.onCall = (String name, Map<String, dynamic> params) async {
        calls.add((name, params));
        if (calls.length == 1) throw FirebaseFunctionsException(code: 'unavailable', message: 'lost');
        if (calls.length == 3) return _refused('spin_wheel_daily_limit', _afterPaidSpin);
        return _spun(coins: 10);
      };
      final SpinWheelResult lost = await service.spinWheel(maxCost: 10);
      expect(lost, isA<SpinFailed>());
      expect((lost as SpinFailed).reason, 'unavailable');
      expect(service.balanceNotifier.value, 100);
      expect(await service.spinWheel(maxCost: 10), isA<SpinWon>());
      expect(await service.spinWheel(maxCost: 10), isA<SpinRefused>());
      await service.spinWheel(maxCost: 10);
      final List<String> ids = <String>[
        for (final (_, Map<String, dynamic> params) in calls) params['requestId'] as String,
      ];
      expect(ids, hasLength(4));
      expect(ids[1], ids[0]);
      expect(ids[2], isNot(ids[1]));
      expect(ids[3], isNot(ids[2]));
    });

    test('an error the server meant clears the request id too', () async {
      backend.onCall = (String name, Map<String, dynamic> params) async {
        calls.add((name, params));
        if (calls.length == 1) throw FirebaseFunctionsException(code: 'permission-denied', message: 'no');
        return _spun(coins: 10);
      };
      final SpinWheelResult denied = await service.spinWheel(maxCost: 10);
      expect((denied as SpinFailed).reason, 'permission-denied');
      await service.spinWheel(maxCost: 10);
      expect(calls[1].$2['requestId'], isNot(calls[0].$2['requestId']));
    });

    test('a failed call moves no coins and leaves the status alone', () async {
      service.refreshSpinWheelStatus();
      final SpinWheelStatus before = service.spinWheelNotifier.value;
      backend.onCall = (_, _) async => throw FirebaseFunctionsException(code: 'deadline-exceeded', message: 'slow');
      await service.spinWheel(maxCost: 10);
      expect(service.spinWheelNotifier.value, before);
      expect(service.balanceNotifier.value, 100);
      expect(analytics.events, isEmpty);
    });
  });

  group('session', () {
    test('a guest gets a failure and no call', () async {
      app_state.prismUser = app_constants.createGuestPrismUser();
      final SpinWheelResult result = await service.spinWheel(maxCost: 10);
      expect((result as SpinFailed).reason, 'not_logged_in');
      expect(calls, isEmpty);
    });

    test('a reply that lands after the account went away changes nothing', () async {
      final Completer<dynamic> response = Completer<dynamic>();
      final Completer<void> started = Completer<void>();
      backend.callStarted = started;
      backend.onCall = (_, _) => response.future;
      final Future<SpinWheelResult> spin = service.spinWheel(maxCost: 10);
      await started.future.timeout(const Duration(seconds: 2));
      backend.callStarted = null;
      await service.clearForUser(backend.userId);
      response.complete(_spun(segment: 3, coins: 100));
      final SpinWheelResult result = await spin;
      expect((result as SpinFailed).reason, 'session_changed');
      expect(service.balanceNotifier.value, 100);
      expect(service.xpNotifier.value.xp, 0);
      expect(analytics.events, isEmpty);
    });
  });

  group('spinWheelNotifier', () {
    String today() => economyDayKey(DateTime.now());

    Future<void> bootstrapWith(Map<String, dynamic> privateDoc) async {
      final CoinsTestFirestore firestore = CoinsTestFirestore()
        ..userData = <String, dynamic>{'coins': 100}
        ..docs['usersv2/${backend.userId}/private/economy'] = <String, dynamic>{'rev': 3, ...privateDoc};
      if (getIt.isRegistered<FirestoreClient>()) getIt.unregister<FirestoreClient>();
      getIt.registerSingleton<FirestoreClient>(firestore);
      backend.onCall = (_, _) async => <String, Object>{};
      await service.bootstrapForCurrentUser();
    }

    test('takes the counters of today from the private economy doc', () async {
      await bootstrapWith(<String, dynamic>{
        'spinWheel': <String, Object>{'dayKey': today(), 'paid': 2, 'freeUsed': true},
      });
      expect(_fields(service.spinWheelNotifier.value), (false, 3, 10));
    });

    test("ignores the counters of another day, and a doc that has none", () async {
      await bootstrapWith(<String, dynamic>{
        'spinWheel': <String, Object>{'dayKey': '2020-01-01', 'paid': 5, 'freeUsed': true},
      });
      expect(_fields(service.spinWheelNotifier.value), (true, 5, 10));
      service.resetSession();
      await bootstrapWith(<String, dynamic>{});
      expect(_fields(service.spinWheelNotifier.value), (true, 5, 10));
    });

    test('a member without Pro never sees the free spin', () async {
      app_state.prismUser.premium = false;
      await bootstrapWith(<String, dynamic>{});
      expect(_fields(service.spinWheelNotifier.value), (false, 5, 10));
    });

    test('a legacy Pro spin from an old client takes the free spin', () async {
      await bootstrapWith(<String, dynamic>{'quests': _bonusQuests(dayKey: today(), claimed: true)});
      expect(_fields(service.spinWheelNotifier.value), (false, 5, 10));
    });

    test('follows the price and the cap of the loaded config', () async {
      await bootstrapWith(<String, dynamic>{
        'spinWheel': <String, Object>{'dayKey': today(), 'paid': 1, 'freeUsed': false},
      });
      EconomyConfig.current = EconomyConfig.fromMap(<String, dynamic>{
        'spend': <String, dynamic>{'spinWheel': 15},
        'award': <String, dynamic>{'spinWheelMaxPerDay': 3},
      });
      expect(_fields(service.spinWheelNotifier.value), (true, 2, 15));
    });

    test('follows Pro when the session user changes', () async {
      app_state.prismUser.premium = false;
      final _FakeSession session = _FakeSession(app_state.prismUser);
      getIt.registerSingleton<SessionRepository>(session);
      await bootstrapWith(<String, dynamic>{});
      expect(service.spinWheelNotifier.value.freeSpinAvailable, isFalse);

      final PrismUsersV2 member = app_state.prismUser..premium = true;
      await session.replaceCurrentUser(member);
      await pumpEventQueue();
      expect(service.spinWheelNotifier.value.freeSpinAvailable, isTrue);

      member.premium = false;
      await session.replaceCurrentUser(member);
      await pumpEventQueue();
      expect(service.spinWheelNotifier.value.freeSpinAvailable, isFalse);
    });

    test('drops the counters of the last user when another one signs in', () async {
      await bootstrapWith(<String, dynamic>{
        'spinWheel': <String, Object>{'dayKey': today(), 'paid': 5, 'freeUsed': true},
      });
      expect(_fields(service.spinWheelNotifier.value), (false, 0, 10));
      app_state.prismUser.id = 'someone-else';
      service.refreshSpinWheelStatus();
      expect(_fields(service.spinWheelNotifier.value), (true, 5, 10));
    });

    test('signing out gives the guest status', () async {
      await bootstrapWith(<String, dynamic>{
        'spinWheel': <String, Object>{'dayKey': today(), 'paid': 2, 'freeUsed': true},
      });
      app_state.prismUser = app_constants.createGuestPrismUser();
      service.resetSession();
      expect(_fields(service.spinWheelNotifier.value), (false, 5, 10));
    });

    test('takes the status of a spin reply, whatever the cached counters say', () async {
      await bootstrapWith(<String, dynamic>{});
      reply(
        (_, _) =>
            _spun(coins: 20, status: <String, Object>{'freeSpinAvailable': false, 'paidSpinsLeft': 1, 'price': 12}),
      );
      final SpinWon won = await spinWon();
      expect(_fields(won.status), (false, 1, 12));
      expect(_fields(service.spinWheelNotifier.value), (false, 1, 12));
    });

    test('keeps the status of a spin reply when the config refreshes afterwards', () async {
      await bootstrapWith(<String, dynamic>{});
      reply((_, _) => _spun(coins: 20));
      await spinWon();
      expect(_fields(service.spinWheelNotifier.value), (false, 4, 10));
      EconomyConfig.current = EconomyConfig.fromMap(<String, dynamic>{
        'spend': <String, dynamic>{'spinWheel': 8},
      });
      expect(_fields(service.spinWheelNotifier.value), (false, 4, 8));
    });

    test('keeps a refusal, for example the daily cap another device reached', () async {
      await bootstrapWith(<String, dynamic>{});
      reply(
        (_, _) => _refused('spin_wheel_daily_limit', <String, Object>{
          'freeSpinAvailable': false,
          'paidSpinsLeft': 0,
          'price': 10,
        }),
      );
      await service.spinWheel(maxCost: 10);
      service.refreshSpinWheelStatus();
      expect(_fields(service.spinWheelNotifier.value), (false, 0, 10));
    });

    test('restores the counters and a won cosmetic after a restart', () async {
      await bootstrapWith(<String, dynamic>{});
      reply((_, _) => _spun(segment: 7, kind: 'cosmetic', itemId: 'frame_ring'));
      await spinWon();
      await pumpEventQueue();

      service.resetSession();
      expect(service.inventoryNotifier.value.owned, isEmpty);
      await service.restoreLocalEconomyForCurrentUser();

      expect(_fields(service.spinWheelNotifier.value), (false, 4, 10));
      expect(service.inventoryNotifier.value.owned, <String>{'frame_ring'});
    });
  });
}
