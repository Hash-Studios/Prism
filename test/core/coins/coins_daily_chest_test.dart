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

Map<String, Object?> _quests({required bool chestOpened, bool doubled = false, bool allClaimed = true}) =>
    <String, Object?>{
      'dayKey': economyDayKey(DateTime.now()),
      'items': <Map<String, Object?>>[
        <String, Object?>{'id': 'wotd_view', 'event': 'view_wotd', 'target': 1, 'progress': 1, 'claimed': true},
        <String, Object?>{'id': 'fav_3', 'event': 'favourite', 'target': 3, 'progress': 3, 'claimed': true},
        <String, Object?>{
          'id': 'share_1',
          'event': 'share',
          'target': 1,
          'progress': allClaimed ? 1 : 0,
          'claimed': allClaimed,
        },
      ],
      'chestOpened': chestOpened,
      'chestDoubled': doubled,
      'weekKey': '2026-W42',
    };

/// The XP receipt every reply carries. `xp` is the user's absolute lifetime XP after the call.
Map<String, Object?> _receipt({required int xp, required int awarded}) => <String, Object?>{
  'xpPolicyVersion': 1,
  'xp': xp,
  'xpAwarded': awarded,
  'xpWeek': <String, Object?>{'weekKey': economyWeekKey(DateTime.now()), 'xp': xp},
};

/// An opened chest the way the server replies, for a user with 100 coins and [xpBefore] XP before the open. A fresh
/// open grants the chest's 10 XP whatever the prize; a replay grants none and reports the live total.
Map<String, Object?> _opened({
  int slot = 0,
  String kind = 'coins',
  int coins = 0,
  String? itemId,
  bool free = false,
  bool doubled = false,
  Object? slots = defaultChestJson,
  bool omitSlots = false,
  bool replay = false,
  int xpBefore = 0,
}) {
  final int cost = free ? 0 : 8;
  final int after = 100 - cost + coins;
  final int awarded = replay ? 0 : 10;
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
    'prize': <String, Object?>{'kind': kind, 'coins': coins, 'xp': 0, 'itemId': itemId},
    if (!omitSlots) 'slots': slots,
    'status': <String, Object>{'opened': true, 'free': free, 'price': 8},
    'quests': _quests(chestOpened: true, doubled: doubled),
    ..._receipt(xp: xpBefore + awarded, awarded: awarded),
  };
}

Map<String, Object?> _refused(
  String reason, {
  Map<String, Object>? status,
  bool insufficient = false,
  Map<String, Object?>? quests,
  int rev = 5,
}) => <String, Object?>{
  'success': false,
  'changed': false,
  'previousBalance': 100,
  'currentBalance': 100,
  'delta': 0,
  'reason': reason,
  if (insufficient) 'insufficientBalance': true,
  if (status != null) 'status': status,
  if (quests != null) ...<String, Object?>{'quests': quests, 'rev': rev},
  ..._receipt(xp: 0, awarded: 0),
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final CoinsTestBackend backend = CoinsTestBackend();
  final CoinsService service = CoinsService.instance;
  final RegExp idPattern = RegExp(r'^[A-Za-z0-9_-]{8,64}$');
  late List<(String, Map<String, dynamic>)> calls;
  late FakeAppAnalytics analytics;

  /// Every XP grant also asks the server for rank rewards. Answer that apart, so [calls] holds only the chest calls.
  void reply(Object? Function(String name, Map<String, dynamic> params) answer) {
    backend.onCall = (String name, Map<String, dynamic> params) async {
      if (name == 'reconcileRankRewards') return <String, Object?>{};
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
    test("a coin win pays the coins, reports the open's 10 XP, and names the slot with its tier", () async {
      reply((_, _) => _opened(slot: 3, coins: 20));
      final ChestWon won = await openWon();
      expect((won.win.slot, won.win.coins, won.win.xp, won.win.itemId), (3, 20, 10, null));
      expect((won.cost, won.doubled, won.tier), (8, false, ChestTier.rare));
      expect(describeWheel(won.slots), defaultChestLines);
      expect(service.balanceNotifier.value, 112);
      expect(service.xpNotifier.value.xp, 10, reason: 'the receipt says 10, not one XP per coin');
      final (String name, Map<String, dynamic> params) = calls.single;
      expect((name, params['maxCost'], params['sourceTag']), ('openDailyChest', 8, 'coins.daily_chest'));
      expect(params['requestId'], matches(idPattern));
    });

    test('a cosmetic win adds the item to the inventory and still reports the 10 XP', () async {
      reply((_, _) => _opened(slot: 4, kind: 'cosmetic', itemId: 'frame_ring'));
      final ChestWon won = await openWon();
      expect(
        (won.win.slot, won.win.coins, won.win.xp, won.win.itemId, won.tier),
        (4, 0, 10, 'frame_ring', ChestTier.epic),
      );
      expect(service.inventoryNotifier.value.owned, <String>{'frame_ring'});
      expect(service.balanceNotifier.value, 92);
      expect(service.xpNotifier.value.xp, 10);
    });

    test('a cosmetic fallback pays its coins and adds no item, with the same 10 XP', () async {
      reply((_, _) => _opened(slot: 4, kind: 'cosmetic', coins: 25));
      final ChestWon won = await openWon();
      expect((won.win.slot, won.win.coins, won.win.xp, won.win.itemId), (4, 25, 10, null));
      expect(service.inventoryNotifier.value.owned, isEmpty);
      expect(service.balanceNotifier.value, 117);
      expect(service.xpNotifier.value.xp, 10);
    });

    test('a free doubled chest costs nothing and doubles the coins but not the XP', () async {
      reply((_, _) => _opened(slot: 6, coins: 200, free: true, doubled: true));
      final ChestWon won = await openWon(maxCost: 0);
      expect((won.cost, won.doubled, won.win.coins, won.win.xp, won.tier), (0, true, 200, 10, ChestTier.legendary));
      expect(service.balanceNotifier.value, 300);
      expect(service.xpNotifier.value.xp, 10);
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
    });

    test("the reply's table beats the cached config, and a reply without one falls back to the config", () async {
      EconomyConfig.current = EconomyConfig.fromMap(<String, dynamic>{
        'award': <String, dynamic>{
          'dailyChest': <Map<String, Object>>[
            <String, Object>{'kind': 'coins', 'coins': 9, 'weight': 1},
            <String, Object>{'kind': 'coins', 'coins': 3, 'weight': 1},
          ],
        },
      });
      reply(
        (_, _) => _opened(
          slot: 2,
          coins: 5,
          slots: <Map<String, Object>>[
            <String, Object>{'kind': 'coins', 'coins': 1, 'weight': 1},
            <String, Object>{'kind': 'coins', 'coins': 2, 'weight': 1},
            <String, Object>{'kind': 'coins', 'coins': 5, 'weight': 98},
          ],
        ),
      );
      final ChestWon fromReply = await openWon();
      expect(describeWheel(fromReply.slots), <String>['coins 1 x1', 'coins 2 x1', 'coins 5 x98']);
      expect((fromReply.win.slot, fromReply.tier), (2, ChestTier.common));

      reply((_, _) => _opened(slot: 1, coins: 3, omitSlots: true));
      final ChestWon fromConfig = await openWon();
      expect(describeWheel(fromConfig.slots), <String>['coins 9 x1', 'coins 3 x1']);
      expect(fromConfig.tier, ChestTier.common);
      reply((_, _) => _opened(slot: 1, coins: 3, slots: <Object>['junk']));
      expect(describeWheel((await openWon()).slots), <String>['coins 9 x1', 'coins 3 x1']);
    });

    test('a reply table with an XP slot is refused, so the cached coin-only table is used', () async {
      reply(
        (_, _) => _opened(
          slot: 1,
          coins: 5,
          slots: <Map<String, Object>>[
            <String, Object>{'kind': 'coins', 'coins': 2, 'weight': 1},
            <String, Object>{'kind': 'xp', 'xp': 25, 'weight': 1},
          ],
        ),
      );
      final ChestWon won = await openWon();
      expect(describeWheel(won.slots), defaultChestLines);
      expect(won.win.xp, 10, reason: 'the XP comes from the receipt, never from a prize slot');
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

    test('a replay adds no XP: the card reports none and the total stays what the server says', () async {
      reply((_, _) => _opened(slot: 3, coins: 20));
      await openWon();
      expect(service.xpNotifier.value.xp, 10);

      reply((_, _) => _opened(slot: 3, coins: 20, replay: true, xpBefore: 10));
      final ChestWon replayed = await openWon();
      await pumpEventQueue();
      expect(replayed.win.xp, 0);
      expect(service.xpNotifier.value.xp, 10, reason: 'a second 10 would make it 20');
    });

    test("the XP total follows the receipt's absolute value, not the awarded amount added to the old total", () async {
      reply((_, _) => _opened(slot: 3, coins: 20, xpBefore: 450));
      await openWon();
      expect((service.xpNotifier.value.xp, service.xpNotifier.value.weekXp), (460, 460));

      reply((_, _) => _opened(slot: 3, coins: 20, xpBefore: 460 + 25));
      await openWon();
      expect(service.xpNotifier.value.xp, 495, reason: '25 more XP came in from another device');
    });

    test('a reply without the XP receipt asks the server for the total, never estimates it from the prize', () async {
      final Completer<Map<String, Object?>> serverTotal = Completer<Map<String, Object?>>();
      int reconciliations = 0;
      backend.onCall = (String name, Map<String, dynamic> params) async {
        if (name == 'reconcileRankRewards') {
          reconciliations++;
          return serverTotal.future;
        }
        calls.add((name, params));
        return _opened(slot: 6, coins: 100)
          ..remove('xpPolicyVersion')
          ..remove('xp')
          ..remove('xpAwarded')
          ..remove('xpWeek');
      };
      final ChestWon won = await openWon();
      await pumpEventQueue();
      expect(won.win.xp, 0);
      expect(reconciliations, 1);
      expect(service.xpNotifier.value.xp, 0, reason: 'nothing is granted locally while the server has not answered');

      serverTotal.complete(<String, Object?>{'success': true, ..._receipt(xp: 460, awarded: 0)});
      await pumpEventQueue();
      expect(service.xpNotifier.value.xp, 460);
    });

    test(
      'a reply older than private progress is not adopted, but a changed open still asks the server for XP',
      () async {
        final CoinsTestFirestore firestore = CoinsTestFirestore()
          ..userData = <String, dynamic>{'coins': 100}
          ..docs['usersv2/${backend.userId}/private/economy'] = <String, dynamic>{'rev': 9};
        if (getIt.isRegistered<FirestoreClient>()) getIt.unregister<FirestoreClient>();
        getIt.registerSingleton<FirestoreClient>(firestore);
        backend.onCall = (_, _) async => <String, Object>{};
        await service.bootstrapForCurrentUser();
        await pumpEventQueue();

        int reconciliations = 0;
        backend.onCall = (String name, Map<String, dynamic> params) async {
          if (name == 'reconcileRankRewards') {
            reconciliations++;
            return <String, Object?>{'success': true, ..._receipt(xp: 10, awarded: 0)};
          }
          calls.add((name, params));
          return _opened(slot: 3, coins: 20);
        };
        final ChestWon won = await openWon();
        await pumpEventQueue();
        expect(won.win.xp, 10);
        expect(service.balanceNotifier.value, 100, reason: 'the stale reply moved nothing');
        expect(reconciliations, 1);
        expect(service.xpNotifier.value.xp, 10);
      },
    );

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
      await pumpEventQueue();
      expect(logged(), <Map<String, Object?>>[
        <String, Object?>{
          'event': 'daily_chest_opened',
          'free': 0,
          'cost': 8,
          'slot': 6,
          'prize': 'coins',
          'tier': 'legendary',
          'coins': 100,
          'xp': 10,
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

    test(
      'a cosmetic win logs no coin earned and a doubled chest logs the same 10 XP, a free chest no coin spent',
      () async {
        reply((_, _) => _opened(slot: 4, kind: 'cosmetic', itemId: 'frame_ring', doubled: true));
        await openWon();
        await pumpEventQueue();
        expect(names(), <String>['daily_chest_opened', 'coin_spent']);
        expect(logged().first, <String, Object?>{
          'event': 'daily_chest_opened',
          'free': 0,
          'cost': 8,
          'slot': 4,
          'prize': 'cosmetic',
          'tier': 'epic',
          'coins': 0,
          'xp': 10,
          'doubled': 1,
        });

        analytics.events.clear();
        reply((_, _) => _opened(coins: 5, free: true));
        await openWon(maxCost: 0);
        await pumpEventQueue();
        expect(names(), <String>['daily_chest_opened', 'coin_earned']);
        expect((logged().first['free'], logged().first['cost'], logged().first['tier']), (1, 0, 'common'));
      },
    );

    test('a cosmetic and its coin fallback both log the prize as a cosmetic', () async {
      reply((_, _) => _opened(slot: 4, kind: 'cosmetic', itemId: 'frame_ring'));
      await openWon();
      await pumpEventQueue();
      reply((_, _) => _opened(slot: 4, kind: 'cosmetic', coins: 25));
      await openWon();
      await pumpEventQueue();
      final List<List<Object?>> opens = <List<Object?>>[
        for (final Map<String, Object?> e in logged())
          if (e['event'] == 'daily_chest_opened') <Object?>[e['prize'], e['tier'], e['coins'], e['xp']],
      ];
      expect(opens, <List<Object?>>[
        <Object?>['cosmetic', 'epic', 0, 10],
        <Object?>['cosmetic', 'epic', 25, 10],
      ]);
    });

    test('a replay logs the XP the reply reports, which is none', () async {
      reply((_, _) => _opened(slot: 3, coins: 20, replay: true));
      await openWon();
      await pumpEventQueue();
      expect(logged().first['xp'], 0);
    });

    test('a refusal logs nothing', () async {
      reply((_, _) => _refused('daily_chest_already_opened'));
      await service.openDailyChest(maxCost: 8);
      await pumpEventQueue();
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
          (_, _) => _refused(
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

    test('every refusal adopts the quests of its reply and makes no other call', () async {
      const List<String> reasons = <String>[
        'daily_chest_price_changed',
        'daily_chest_already_opened',
        'daily_chest_insufficient_balance',
      ];
      for (final (int index, String reason) in reasons.indexed) {
        service.questsNotifier.value = QuestState.fromMap(_quests(chestOpened: false));
        reply(
          (_, _) => _refused(
            reason,
            quests: _quests(chestOpened: reason == 'daily_chest_already_opened', allClaimed: false),
            rev: 6 + index,
            insufficient: reason == 'daily_chest_insufficient_balance',
          ),
        );
        calls.clear();
        await service.openDailyChest(maxCost: 0);
        await pumpEventQueue();

        final QuestState quests = service.questsNotifier.value!;
        expect(
          (quests.items.where((q) => !q.claimed).length, quests.chestOpened),
          (1, reason == 'daily_chest_already_opened'),
          reason: reason,
        );
        expect(calls.map((c) => c.$1), <String>['openDailyChest'], reason: reason);
      }
    });

    test('the quests of a refusal are still there after a restart', () async {
      reply((_, _) => _refused('daily_chest_price_changed', quests: _quests(chestOpened: false, allClaimed: false)));
      await service.openDailyChest(maxCost: 0);
      await pumpEventQueue();

      service.resetSession();
      expect(service.questsNotifier.value, isNull);
      await service.restoreLocalEconomyForCurrentUser();

      expect(service.questsNotifier.value?.items.where((q) => !q.claimed).length, 1);
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
        if (name == 'reconcileRankRewards') return <String, Object?>{};
        calls.add((name, params));
        if (calls.length == 1) throw FirebaseFunctionsException(code: 'unavailable', message: 'lost');
        if (calls.length == 3) return _refused('daily_chest_already_opened');
        return _opened(coins: 10);
      };
      final DailyChestResult lost = await service.openDailyChest(maxCost: 8);
      expect(lost, isA<ChestFailed>());
      expect((lost as ChestFailed).reason, 'unavailable');
      expect(service.balanceNotifier.value, 100);
      expect(await service.openDailyChest(maxCost: 8), isA<ChestWon>());
      expect(await service.openDailyChest(maxCost: 8), isA<ChestRefused>());
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

    test('the call waits 20 seconds for the server, not the plugin default of 60', () async {
      await openWon();
      expect(backend.timeoutsMs['openDailyChest'], 20000);
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
        if (name == 'reconcileRankRewards') return <String, Object?>{};
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
