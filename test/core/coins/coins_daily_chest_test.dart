import 'dart:async';

import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/analytics/events/analytics_event.dart';
import 'package:Prism/core/coins/coin_policy.dart';
import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/coins/daily_chest.dart';
import 'package:Prism/core/coins/economy_config.dart';
import 'package:Prism/core/constants/app_constants.dart' as app_constants;
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/firestore/firestore_client.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:cloud_functions/cloud_functions.dart' show FirebaseFunctionsException;
import 'package:flutter_test/flutter_test.dart';

import '../../support/coins_test_backend.dart';
import '../../support/fake_app_analytics.dart';
import 'spin_wheel_test_helpers.dart';

Map<String, Object?> _quests({required bool chestOpened, bool doubled = false}) => <String, Object?>{
  'dayKey': economyDayKey(DateTime.now()),
  'items': <Map<String, Object?>>[
    <String, Object?>{'id': 'wotd_view', 'event': 'view_wotd', 'target': 1, 'progress': 1, 'claimed': true},
    <String, Object?>{'id': 'fav_3', 'event': 'favourite', 'target': 3, 'progress': 3, 'claimed': true},
    <String, Object?>{'id': 'share_1', 'event': 'share', 'target': 1, 'progress': 1, 'claimed': true},
  ],
  'chestOpened': chestOpened,
  'chestDoubled': doubled,
  'weekKey': '2026-W42',
};

/// An opened chest the way the server replies, for a user with 100 coins before the open.
Map<String, Object?> _opened({
  int slot = 0,
  String kind = 'coins',
  int coins = 0,
  int xp = 0,
  String? itemId,
  bool free = false,
  bool doubled = false,
  Object? slots = defaultChestJson,
  bool omitSlots = false,
  bool replay = false,
}) {
  final int cost = free ? 0 : 8;
  final int after = 100 - cost + coins;
  return <String, Object?>{
    'success': true,
    'changed': true,
    'previousBalance': replay ? after : 100,
    'currentBalance': after,
    'delta': replay ? 0 : coins - cost,
    'reason': 'ok',
    'transactionId': 'ctx_questChest_test',
    'rev': 5,
    'cost': cost,
    'free': free,
    'doubled': doubled,
    'slot': slot,
    'prize': <String, Object?>{'kind': kind, 'coins': coins, 'xp': xp, 'itemId': itemId},
    if (!omitSlots) 'slots': slots,
    'status': <String, Object>{'opened': true, 'free': free, 'price': 8},
    'quests': _quests(chestOpened: true, doubled: doubled),
  };
}

Map<String, Object?> _refused(String reason, {Map<String, Object>? status, bool insufficient = false}) =>
    <String, Object?>{
      'success': false,
      'changed': false,
      'previousBalance': 100,
      'currentBalance': 100,
      'delta': 0,
      'reason': reason,
      if (insufficient) 'insufficientBalance': true,
      if (status != null) 'status': status,
    };

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

  Future<ChestWon> openWon({int maxCost = 8}) async {
    final DailyChestResult result = await service.openDailyChest(maxCost: maxCost);
    expect(result, isA<ChestWon>());
    return result as ChestWon;
  }

  setUp(() async {
    calls = <(String, Map<String, dynamic>)>[];
    analytics = FakeAppAnalytics();
    AnalyticsRuntime.instance = analytics;
    await backend.install();
    service.balanceNotifier.value = 100;
    reply((_, _) => _opened());
  });

  tearDown(() async {
    AnalyticsRuntime.reset();
    app_state.prismUser = app_constants.createGuestPrismUser();
    await service.refreshStreakStatus();
    EconomyConfig.resetForTest();
    await getIt.reset();
  });

  group('an opened chest', () {
    test('a coin win pays the prize and the XP, and names the slot with its tier', () async {
      reply((_, _) => _opened(slot: 3, coins: 20));
      final ChestWon won = await openWon();
      expect((won.win.slot, won.win.coins, won.win.xp, won.win.itemId), (3, 20, 0, null));
      expect((won.cost, won.doubled, won.tier), (8, false, ChestTier.rare));
      expect(describeWheel(won.slots), defaultChestLines);
      expect(service.balanceNotifier.value, 112);
      expect(service.xpNotifier.value.xp, 20);
      final (String name, Map<String, dynamic> params) = calls.single;
      expect((name, params['maxCost'], params['sourceTag']), ('openDailyChest', 8, 'coins.daily_chest'));
      expect(params['requestId'], matches(idPattern));
    });

    test('an XP win pays the XP and only charges the price', () async {
      reply((_, _) => _opened(slot: 2, kind: 'xp', xp: 25));
      final ChestWon won = await openWon();
      expect((won.win.slot, won.win.coins, won.win.xp, won.win.itemId, won.tier), (2, 0, 25, null, ChestTier.rare));
      expect(service.balanceNotifier.value, 92);
      expect(service.xpNotifier.value.xp, 25);
    });

    test('a cosmetic win adds the item to the inventory', () async {
      reply((_, _) => _opened(slot: 4, kind: 'cosmetic', itemId: 'frame_ring'));
      final ChestWon won = await openWon();
      expect(
        (won.win.slot, won.win.coins, won.win.xp, won.win.itemId, won.tier),
        (4, 0, 0, 'frame_ring', ChestTier.epic),
      );
      expect(service.inventoryNotifier.value.owned, <String>{'frame_ring'});
      expect(service.balanceNotifier.value, 92);
      expect(service.xpNotifier.value.xp, 0);
    });

    test('a cosmetic fallback pays its coins and adds no item', () async {
      reply((_, _) => _opened(slot: 4, kind: 'cosmetic', coins: 25));
      final ChestWon won = await openWon();
      expect((won.win.slot, won.win.coins, won.win.itemId), (4, 25, null));
      expect(service.inventoryNotifier.value.owned, isEmpty);
      expect(service.balanceNotifier.value, 117);
      expect(service.xpNotifier.value.xp, 25);
    });

    test('a free doubled chest costs nothing and pays the doubled prize', () async {
      reply((_, _) => _opened(slot: 6, coins: 200, free: true, doubled: true));
      final ChestWon won = await openWon(maxCost: 0);
      expect((won.cost, won.doubled, won.win.coins, won.tier), (0, true, 200, ChestTier.legendary));
      expect(service.balanceNotifier.value, 300);
      expect(service.xpNotifier.value.xp, 200);
      expect(service.questsNotifier.value?.chestDoubled, isTrue);
      expect(calls.single.$2['maxCost'], 0);
    });

    test('maxCost goes out as given, whatever the cached price is', () async {
      await openWon(maxCost: 5);
      await openWon(maxCost: 0);
      expect(calls.map((c) => c.$2['maxCost']), <Object?>[5, 0]);
      expect(CoinPolicy.dailyChestPrice, 8);
    });

    test('the quests of the reply close the chest', () async {
      expect(service.questsNotifier.value, isNull);
      await openWon();
      final QuestState quests = service.questsNotifier.value!;
      expect((quests.chestOpened, quests.chestDoubled, quests.items.length), (true, false, 3));
      expect(quests.chestReady, isFalse);
    });

    test("the reply's table beats the cached config, and a reply without one falls back to the config", () async {
      EconomyConfig.current = EconomyConfig.fromMap(<String, dynamic>{
        'award': <String, dynamic>{
          'dailyChest': <Map<String, Object>>[
            <String, Object>{'kind': 'coins', 'coins': 9, 'weight': 1},
            <String, Object>{'kind': 'xp', 'xp': 9, 'weight': 1},
          ],
        },
      });
      reply(
        (_, _) => _opened(
          slot: 2,
          coins: 5,
          slots: <Map<String, Object>>[
            <String, Object>{'kind': 'xp', 'xp': 1, 'weight': 1},
            <String, Object>{'kind': 'coins', 'coins': 2, 'weight': 1},
            <String, Object>{'kind': 'coins', 'coins': 5, 'weight': 98},
          ],
        ),
      );
      final ChestWon fromReply = await openWon();
      expect(describeWheel(fromReply.slots), <String>['xp 1 x1', 'coins 2 x1', 'coins 5 x98']);
      expect((fromReply.win.slot, fromReply.tier), (2, ChestTier.common));

      reply((_, _) => _opened(slot: 1, kind: 'xp', xp: 9, omitSlots: true));
      final ChestWon fromConfig = await openWon();
      expect(describeWheel(fromConfig.slots), <String>['coins 9 x1', 'xp 9 x1']);
      expect(fromConfig.tier, ChestTier.common);
      reply((_, _) => _opened(slot: 1, kind: 'xp', xp: 9, slots: <Object>['junk']));
      expect(describeWheel((await openWon()).slots), <String>['coins 9 x1', 'xp 9 x1']);
    });

    test('a slot outside the table lands on the nearest slot instead of past the end', () async {
      reply((_, _) => _opened(slot: 99, coins: 100));
      expect((await openWon()).win.slot, 6);
      reply((_, _) => _opened(slot: -4, coins: 5));
      expect((await openWon()).win.slot, 0);
    });

    test('a retry after a lost reply shows the stored prize and moves no coins', () async {
      reply((_, _) => _opened(slot: 3, coins: 20, replay: true));
      final ChestWon won = await openWon();
      await pumpEventQueue();
      expect((won.win.slot, won.win.coins), (3, 20));
      expect(service.balanceNotifier.value, 112);
      expect(calls.map((c) => c.$1), <String>['openDailyChest']);
      expect(service.questsNotifier.value?.chestOpened, isTrue);
    });

    test('restores the quests and a won cosmetic after a restart', () async {
      reply((_, _) => _opened(slot: 4, kind: 'cosmetic', itemId: 'frame_ring'));
      await openWon();
      await pumpEventQueue();

      service.resetSession();
      expect(service.inventoryNotifier.value.owned, isEmpty);
      expect(service.questsNotifier.value, isNull);
      await service.restoreLocalEconomyForCurrentUser();

      expect(service.questsNotifier.value?.chestOpened, isTrue);
      expect(service.inventoryNotifier.value.owned, <String>{'frame_ring'});
    });
  });

  group('analytics', () {
    List<Map<String, Object?>> logged() => <Map<String, Object?>>[
      for (final AnalyticsEvent e in analytics.events) <String, Object?>{'event': e.eventName, ...e.toWireParameters()},
    ];
    List<Object?> names() => <Object?>[for (final Map<String, Object?> e in logged()) e['event']];

    test('a paid coin win logs the open, the price and the prize', () async {
      reply((_, _) => _opened(slot: 6, coins: 100));
      await openWon();
      expect(logged(), <Map<String, Object?>>[
        <String, Object?>{
          'event': 'daily_chest_opened',
          'free': 0,
          'cost': 8,
          'slot': 6,
          'prize': 'coins',
          'tier': 'legendary',
          'coins': 100,
          'xp': 0,
          'doubled': 0,
        },
        <String, Object?>{
          'event': 'coin_spent',
          'action': 'quest_chest',
          'amount': 8,
          'balance': 192,
          'source_tag': 'coins.daily_chest',
        },
        <String, Object?>{
          'event': 'coin_earned',
          'action': 'quest_chest',
          'amount': 100,
          'balance': 192,
          'source_tag': 'coins.daily_chest',
        },
      ]);
    });

    test('an XP win logs no coin earned, a free chest logs no coin spent', () async {
      reply((_, _) => _opened(slot: 2, kind: 'xp', xp: 50, doubled: true));
      await openWon();
      expect(names(), <String>['daily_chest_opened', 'coin_spent']);
      expect(logged().first, <String, Object?>{
        'event': 'daily_chest_opened',
        'free': 0,
        'cost': 8,
        'slot': 2,
        'prize': 'xp',
        'tier': 'rare',
        'coins': 0,
        'xp': 50,
        'doubled': 1,
      });

      analytics.events.clear();
      reply((_, _) => _opened(coins: 5, free: true));
      await openWon(maxCost: 0);
      expect(names(), <String>['daily_chest_opened', 'coin_earned']);
      expect((logged().first['free'], logged().first['cost'], logged().first['tier']), (1, 0, 'common'));
    });

    test('a cosmetic and its coin fallback both log the prize as a cosmetic', () async {
      reply((_, _) => _opened(slot: 4, kind: 'cosmetic', itemId: 'frame_ring'));
      await openWon();
      reply((_, _) => _opened(slot: 4, kind: 'cosmetic', coins: 25));
      await openWon();
      final List<List<Object?>> opens = <List<Object?>>[
        for (final Map<String, Object?> e in logged())
          if (e['event'] == 'daily_chest_opened') <Object?>[e['prize'], e['tier'], e['coins'], e['xp']],
      ];
      expect(opens, <List<Object?>>[
        <Object?>['cosmetic', 'epic', 0, 0],
        <Object?>['cosmetic', 'epic', 25, 0],
      ]);
    });

    test('a refusal logs nothing', () async {
      reply((_, _) => _refused('daily_chest_already_opened'));
      await service.openDailyChest(maxCost: 8);
      expect(analytics.events, isEmpty);
    });
  });

  group('refusals', () {
    test('each refusal reason maps to its refusal and moves nothing', () async {
      const Map<String, (ChestRefusal, int?)> cases = <String, (ChestRefusal, int?)>{
        'daily_chest_insufficient_balance': (ChestRefusal.insufficientBalance, null),
        'daily_chest_price_changed': (ChestRefusal.priceChanged, 12),
        'daily_chest_already_opened': (ChestRefusal.alreadyOpened, null),
      };
      for (final MapEntry<String, (ChestRefusal, int?)> c in cases.entries) {
        reply(
          (name, _) => name == 'progressQuest'
              ? <String, Object?>{'success': true}
              : _refused(
                  c.key,
                  status: <String, Object>{'opened': false, 'free': false, 'price': 12},
                  insufficient: c.key == 'daily_chest_insufficient_balance',
                ),
        );
        final DailyChestResult result = await service.openDailyChest(maxCost: 8);
        expect(result, isA<ChestRefused>(), reason: c.key);
        final ChestRefused refused = result as ChestRefused;
        expect((refused.refusal, refused.price), (c.value.$1, c.value.$2), reason: c.key);
        expect(service.balanceNotifier.value, 100, reason: c.key);
        expect(service.xpNotifier.value.xp, 0, reason: c.key);
      }
    });

    test('a price change without a status carries no price', () async {
      reply((_, _) => _refused('daily_chest_price_changed'));
      final ChestRefused refused = await service.openDailyChest(maxCost: 8) as ChestRefused;
      expect((refused.refusal, refused.price), (ChestRefusal.priceChanged, null));
    });

    test('a price change loads the config again, so the price shown follows the server', () async {
      final CoinsTestFirestore firestore = CoinsTestFirestore()
        ..docs['economyConfig/current'] = <String, dynamic>{
          'spend': <String, dynamic>{'dailyChest': 12},
        };
      getIt.registerSingleton<FirestoreClient>(firestore);
      expect(CoinPolicy.dailyChestPrice, 8);
      reply(
        (_, _) => _refused(
          'daily_chest_price_changed',
          status: <String, Object>{'opened': false, 'free': false, 'price': 12},
        ),
      );
      await service.openDailyChest(maxCost: 8);
      await pumpEventQueue();
      expect(CoinPolicy.dailyChestPrice, 12);
    });

    test('a chest another device already opened syncs the quests', () async {
      expect(service.questsNotifier.value, isNull);
      reply(
        (name, _) => name == 'progressQuest'
            ? <String, Object?>{'success': true, 'rev': 6, 'quests': _quests(chestOpened: true)}
            : _refused(
                'daily_chest_already_opened',
                status: <String, Object>{'opened': true, 'free': true, 'price': 8},
              ),
      );
      final DailyChestResult result = await service.openDailyChest(maxCost: 0);
      await pumpEventQueue();
      expect((result as ChestRefused).refusal, ChestRefusal.alreadyOpened);
      expect(calls.map((c) => c.$1), <String>['openDailyChest', 'progressQuest']);
      expect(calls.last.$2.containsKey('event'), isFalse);
      expect(service.questsNotifier.value?.chestOpened, isTrue);
    });

    test('the insufficient flag alone is enough for an insufficient refusal', () async {
      reply((_, _) => _refused('something_new', insufficient: true));
      expect((await service.openDailyChest(maxCost: 8) as ChestRefused).refusal, ChestRefusal.insufficientBalance);
    });

    test('a refusal the app does not know is a failure with the reason', () async {
      reply((_, _) => _refused('daily_chest_closed'));
      final DailyChestResult result = await service.openDailyChest(maxCost: 8);
      expect(result, isA<ChestFailed>());
      expect((result as ChestFailed).reason, 'daily_chest_closed');
    });
  });

  group('request ids', () {
    test('a lost reply keeps the request id for the next tap, a definite reply clears it', () async {
      backend.onCall = (String name, Map<String, dynamic> params) async {
        calls.add((name, params));
        if (calls.length == 1) throw FirebaseFunctionsException(code: 'unavailable', message: 'lost');
        if (calls.length == 3) return _refused('daily_chest_already_opened');
        if (name == 'progressQuest') return <String, Object?>{'success': true};
        return _opened(coins: 10);
      };
      final DailyChestResult lost = await service.openDailyChest(maxCost: 8);
      expect(lost, isA<ChestFailed>());
      expect((lost as ChestFailed).reason, 'unavailable');
      expect(service.balanceNotifier.value, 100);
      expect(await service.openDailyChest(maxCost: 8), isA<ChestWon>());
      expect(await service.openDailyChest(maxCost: 8), isA<ChestRefused>());
      await pumpEventQueue();
      await service.openDailyChest(maxCost: 8);
      final List<String> ids = <String>[
        for (final (String name, Map<String, dynamic> params) in calls)
          if (name == 'openDailyChest') params['requestId'] as String,
      ];
      expect(ids, hasLength(4));
      expect(ids[1], ids[0]);
      expect(ids[2], isNot(ids[1]));
      expect(ids[3], isNot(ids[2]));
    });

    test('a failed call moves no coins and logs nothing', () async {
      backend.onCall = (_, _) async => throw FirebaseFunctionsException(code: 'deadline-exceeded', message: 'slow');
      final DailyChestResult result = await service.openDailyChest(maxCost: 8);
      expect((result as ChestFailed).reason, 'deadline-exceeded');
      expect(service.balanceNotifier.value, 100);
      expect(service.questsNotifier.value, isNull);
      expect(analytics.events, isEmpty);
    });

    test('an error the server meant is a failure and clears the request id too', () async {
      backend.onCall = (String name, Map<String, dynamic> params) async {
        calls.add((name, params));
        if (calls.length == 1) throw FirebaseFunctionsException(code: 'permission-denied', message: 'no');
        return _opened(coins: 10);
      };
      final DailyChestResult denied = await service.openDailyChest(maxCost: 8);
      expect((denied as ChestFailed).reason, 'permission-denied');
      await service.openDailyChest(maxCost: 8);
      expect(calls[1].$2['requestId'], isNot(calls[0].$2['requestId']));
    });
  });

  group('session', () {
    test('a guest gets a failure and no call', () async {
      app_state.prismUser = app_constants.createGuestPrismUser();
      final DailyChestResult result = await service.openDailyChest(maxCost: 8);
      expect((result as ChestFailed).reason, 'not_logged_in');
      expect(calls, isEmpty);
    });

    test('a reply that lands after the account went away changes nothing', () async {
      final Completer<dynamic> response = Completer<dynamic>();
      final Completer<void> started = Completer<void>();
      backend.callStarted = started;
      backend.onCall = (_, _) => response.future;
      final Future<DailyChestResult> open = service.openDailyChest(maxCost: 8);
      await started.future.timeout(const Duration(seconds: 2));
      backend.callStarted = null;
      await service.clearForUser(backend.userId);
      response.complete(_opened(slot: 3, coins: 20));
      final DailyChestResult result = await open;
      expect((result as ChestFailed).reason, 'session_changed');
      expect(service.balanceNotifier.value, 100);
      expect(service.xpNotifier.value.xp, 0);
      expect(service.questsNotifier.value, isNull);
      expect(analytics.events, isEmpty);
    });
  });
}
