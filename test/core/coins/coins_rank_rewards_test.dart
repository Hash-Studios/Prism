import 'dart:async';
import 'dart:io';

import 'package:Prism/core/coins/coin_action.dart';
import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/coins/economy_config.dart';
import 'package:Prism/core/coins/economy_snapshot_store.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/firestore/firestore_client.dart';
import 'package:Prism/core/firestore/firestore_error.dart';
import 'package:Prism/core/offline/durable_json_store.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/coins_test_backend.dart';

class _PausingRootSnapshotStore extends EconomySnapshotStore {
  _PausingRootSnapshotStore({required super.store});

  final Completer<void> started = Completer<void>();
  final Completer<void> resume = Completer<void>();

  @override
  Future<Map<String, dynamic>?> readRoot(String ownerId) async {
    final Map<String, dynamic>? snapshot = await super.readRoot(ownerId);
    if (!started.isCompleted) {
      started.complete();
      await resume.future;
    }
    return snapshot;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final CoinsTestBackend backend = CoinsTestBackend();
  final CoinsService coins = CoinsService.instance;
  late Directory directory;
  late EconomySnapshotStore store;
  late CoinsTestFirestore firestore;

  Map<String, Object?> inventoryReply(int rev, List<String> owned, {bool changed = true}) => <String, Object?>{
    'success': true,
    'rev': rev,
    'owned': owned,
    'added': changed ? owned : <String>[],
    'inventoryChanged': changed,
  };

  Future<void> seed({int rev = 6, List<String> owned = const <String>['frame_ring']}) async {
    await store.write(backend.userId, rev, <String, dynamic>{
      'quests': <String, Object?>{'dayKey': 'saved-day'},
      'passes': <String, Object?>{'autoRotatePassUntil': DateTime.utc(2099).millisecondsSinceEpoch},
      'drops': <String, Object?>{
        'unlocked': <String, Object?>{
          'wall': <String, Object?>{'weekKey': 'saved-week', 'url': 'saved-url'},
        },
      },
      'inventory': <String, Object?>{'owned': owned},
    });
    await coins.restoreLocalEconomyForCurrentUser();
  }

  setUp(() async {
    await getIt.reset();
    await backend.install();
    coins.resetSession();
    directory = await Directory.systemTemp.createTemp('rank-rewards-');
    store = EconomySnapshotStore(store: DurableJsonStore('rank_rewards', directory: directory));
    coins.setEconomySnapshotStoreForTest(store);
    firestore = CoinsTestFirestore()..userData = <String, dynamic>{'coins': 100, 'xp': 650};
    getIt.registerSingleton<FirestoreClient>(firestore);
  });

  tearDown(() async {
    coins.resetSession();
    await getIt.reset();
    await directory.delete(recursive: true);
  });

  test('inventory replies persist without clearing quests, passes or drops', () async {
    await seed();
    backend.onCall = (name, params) async {
      expect(name, 'reconcileRankRewards');
      expect(params.keys, <String>['sourceTag']);
      return inventoryReply(7, <String>['frame_ring', 'glow_aurora']);
    };

    await coins.reconcileRankRewards();

    expect(coins.inventoryNotifier.value.owned, <String>{'frame_ring', 'glow_aurora'});
    expect(coins.questsNotifier.value?.dayKey, 'saved-day');
    expect(coins.currentPasses.autoRotatePassActive(DateTime.utc(2026)), isTrue);
    expect(coins.dropsUnlockedNotifier.value['wall']?.url, 'saved-url');
    final EconomySnapshot? saved = await store.read(backend.userId);
    expect(saved?.revision, 7);
    expect(saved?.data['quests'], <String, Object?>{'dayKey': 'saved-day'});
    expect(saved?.data.containsKey('passes'), isTrue);
    expect(app_state.prismUser.coins, 100);
  });

  test('an owned refusal still patches and persists confirmed inventory', () async {
    await seed();
    backend.onCall = (_, _) async => <String, Object?>{
      ...inventoryReply(7, <String>['frame_ring', 'glow_aurora']),
      'success': false,
      'reason': 'shop_item_owned',
      'currentBalance': 100,
      'delta': 0,
    };

    final ShopPurchaseResult result = await coins.purchaseShopItem('glow_aurora');

    expect(result.outcome, ShopPurchaseOutcome.owned);
    expect(result.owned, contains('glow_aurora'));
    final EconomySnapshot? saved = await store.read(backend.userId);
    expect(saved?.revision, 7);
    expect((saved?.data['inventory'] as Map)['owned'], contains('glow_aurora'));
    expect(coins.questsNotifier.value?.dayKey, 'saved-day');
  });

  test('an older inventory reply changes neither ownership nor balance', () async {
    await seed(rev: 8, owned: <String>['frame_gold', 'glow_aurora']);
    backend.onCall = (_, _) async => <String, Object?>{
      ...inventoryReply(7, <String>[]),
      'currentBalance': 1,
      'delta': -99,
    };

    await coins.reconcileRankRewards();

    expect(coins.inventoryNotifier.value.owned, <String>{'frame_gold', 'glow_aurora'});
    expect(app_state.prismUser.coins, 100);
    expect((await store.read(backend.userId))?.revision, 8);
  });

  test('an owned refusal protects inventory from an equal-revision full read already in flight', () async {
    await seed();
    final Completer<Map<String, dynamic>?> privateRead = Completer<Map<String, dynamic>?>();
    firestore.privateEconomyResponse = privateRead.future;
    backend.onCall = (_, _) async => <String, Object?>{
      ...inventoryReply(7, <String>['frame_ring', 'glow_aurora']),
      'success': false,
      'reason': 'shop_item_owned',
    };

    final Future<void> refresh = coins.refreshBalance();
    await firestore.privateEconomyReadStarted.future;
    expect((await coins.purchaseShopItem('glow_aurora')).outcome, ShopPurchaseOutcome.owned);
    privateRead.complete(<String, dynamic>{
      'rev': 7,
      'inventory': <String, Object?>{'owned': <String>[]},
    });
    await refresh;

    expect(coins.inventoryNotifier.value.owned, <String>{'frame_ring', 'glow_aurora'});
    expect(coins.questsNotifier.value?.dayKey, 'saved-day');
    expect((await store.read(backend.userId))?.revision, 7);
  });

  for (final bool bootstrap in <bool>[true, false]) {
    test('${bootstrap ? 'bootstrap' : 'refresh'} hydrates private state after confirmed XP', () async {
      final String week = economyWeekKey(DateTime.now());
      await store.writeRoot(backend.userId, <String, dynamic>{
        'xp': 450,
        'xpWeek': <String, Object?>{'weekKey': week, 'xp': 5},
        'cosmetics': <String, Object?>{'frame': 'frame_ring'},
      });
      await seed();
      final Completer<Map<String, dynamic>?> privateRead = Completer<Map<String, dynamic>?>();
      final Completer<Map<String, dynamic>> rootRead = Completer<Map<String, dynamic>>();
      firestore.privateEconomyResponse = privateRead.future;
      firestore.userResponse = rootRead.future;
      backend.onCall = (_, _) async => <String, Object?>{
        ...inventoryReply(6, <String>['frame_ring'], changed: false),
        'xp': 650,
        'xpWeek': <String, Object?>{'weekKey': week, 'xp': 25},
      };

      final Future<void> refresh = bootstrap ? coins.bootstrapForCurrentUser() : coins.refreshBalance();
      await firestore.privateEconomyReadStarted.future;
      await coins.reconcileRankRewards();
      expect(coins.xpNotifier.value.xp, 650);
      privateRead.complete(<String, dynamic>{
        'rev': 6,
        'quests': <String, Object?>{'dayKey': 'server-day'},
        'inventory': <String, Object?>{
          'owned': <String>['frame_ring'],
        },
        'passes': <String, Object?>{'premiumPassUntil': DateTime.utc(2099).millisecondsSinceEpoch},
      });
      rootRead.complete(<String, dynamic>{
        'coins': 100,
        'xp': 450,
        'xpWeek': <String, Object?>{'weekKey': week, 'xp': 5},
        if (bootstrap) 'cosmetics': <String, Object?>{'frame': 'frame_ring'},
        'coinState': <String, Object?>{'streakBest': 9, 'firstWallpaperUploadRewarded': true},
      });
      await refresh;

      expect(coins.questsNotifier.value?.dayKey, 'server-day');
      expect(coins.currentPasses.premiumPassActive(DateTime.utc(2026)), isTrue);
      expect(coins.currentPasses.autoRotatePassActive(DateTime.utc(2026)), isFalse);
      expect(coins.streakNotifier.value.best, 9);
      expect(coins.earnFlagsNotifier.value.firstUploadRewarded, isTrue);
      expect(coins.inventoryNotifier.value.frame, bootstrap ? 'frame_ring' : null);
      expect(coins.xpNotifier.value.xp, 650);
      expect(coins.xpNotifier.value.weekXp, 25);
      expect((await store.read(backend.userId))?.data['quests'], <String, Object?>{'dayKey': 'server-day'});
      expect((await store.readRoot(backend.userId))?['xp'], 650);
      expect((await store.readRoot(backend.userId))?['xpWeek'], <String, Object?>{'weekKey': week, 'xp': 25});
      expect(
        (await store.readRoot(backend.userId))?['cosmetics'],
        bootstrap ? <String, Object?>{'frame': 'frame_ring'} : null,
      );
    });
  }

  test('local restore hydrates cosmetics and private state without replacing confirmed XP during its read', () async {
    await store.writeRoot(backend.userId, <String, dynamic>{'xp': 450});
    await seed();
    await store.writeRoot(backend.userId, <String, dynamic>{
      'xp': 450,
      'cosmetics': <String, Object?>{'nameGlow': 'glow_ember'},
    });
    await store.write(backend.userId, 6, <String, dynamic>{
      'quests': <String, Object?>{'dayKey': 'later-cache'},
    });
    final _PausingRootSnapshotStore pausing = _PausingRootSnapshotStore(
      store: DurableJsonStore('rank_rewards', directory: directory),
    );
    coins.setEconomySnapshotStoreForTest(pausing);
    backend.onCall = (_, _) async => <String, Object?>{
      ...inventoryReply(6, <String>['frame_ring'], changed: false),
      'xp': 650,
    };

    final Future<void> restore = coins.restoreLocalEconomyForCurrentUser();
    await pausing.started.future;
    await coins.reconcileRankRewards();
    pausing.resume.complete();
    await restore;

    expect(coins.xpNotifier.value.xp, 650);
    expect(coins.inventoryNotifier.value.nameGlow, 'glow_ember');
    expect(coins.questsNotifier.value?.dayKey, 'later-cache');
  });

  for (final bool bootstrap in <bool>[true, false]) {
    test('${bootstrap ? 'bootstrap' : 'refresh'} clears missing private state without erasing concurrent XP', () async {
      await store.writeRoot(backend.userId, <String, dynamic>{'xp': 450});
      await seed(rev: 0, owned: <String>[]);
      final Completer<Map<String, dynamic>?> privateRead = Completer<Map<String, dynamic>?>();
      firestore.privateEconomyResponse = privateRead.future;
      firestore.userData = <String, dynamic>{
        'coins': 100,
        'xp': 450,
        'cosmetics': <String, Object?>{'frame': 'frame_ring'},
        'coinState': <String, Object?>{'streakBest': 9},
      };
      backend.onCall = (_, _) async => <String, Object?>{...inventoryReply(0, <String>[], changed: false), 'xp': 480};

      final Future<void> refresh = bootstrap ? coins.bootstrapForCurrentUser() : coins.refreshBalance();
      await firestore.privateEconomyReadStarted.future;
      await coins.reconcileRankRewards();
      privateRead.complete(null);
      await refresh;

      expect(coins.questsNotifier.value, isNull);
      expect(coins.currentPasses.autoRotatePassActive(DateTime.utc(2026)), isFalse);
      final EconomySnapshot? saved = await store.read(backend.userId);
      expect(saved?.data.containsKey('quests') ?? false, isFalse);
      expect(saved?.data.containsKey('passes') ?? false, isFalse);
      expect(coins.xpNotifier.value.xp, 480);
      expect(coins.streakNotifier.value.best, 9);
      expect(coins.inventoryNotifier.value.frame, 'frame_ring');
      expect((await store.readRoot(backend.userId))?['xp'], 480);
      expect((await store.readRoot(backend.userId))?['cosmetics'], <String, Object?>{'frame': 'frame_ring'});
    });
  }

  test('a delayed refused purchase cannot erase a newer reconciliation', () async {
    await seed();
    final Completer<Object?> delayed = Completer<Object?>();
    final Completer<void> started = Completer<void>();
    backend.onCall = (name, _) {
      if (name == 'purchaseShopItem') {
        started.complete();
        return delayed.future;
      }
      return Future<Object?>.value(inventoryReply(8, <String>['frame_ring', 'glow_aurora', 'frame_gold']));
    };
    final Future<ShopPurchaseResult> purchase = coins.purchaseShopItem('glow_aurora');
    await started.future;
    await coins.reconcileRankRewards();
    delayed.complete(<String, Object?>{
      ...inventoryReply(7, <String>['frame_ring', 'glow_aurora']),
      'success': false,
      'reason': 'shop_item_owned',
      'currentBalance': 10,
    });

    expect((await purchase).outcome, ShopPurchaseOutcome.owned);
    expect(coins.inventoryNotifier.value.owned, contains('frame_gold'));
    expect(app_state.prismUser.coins, 100);
    expect((await store.read(backend.userId))?.revision, 8);
  });

  test('a shop receipt replay merges inventory and refreshes balance without publishing historical debit', () async {
    await seed();
    final Completer<Map<String, dynamic>> root = Completer<Map<String, dynamic>>();
    firestore.userResponse = root.future;
    firestore.docs['usersv2/${backend.userId}/private/economy'] = <String, dynamic>{
      'rev': 7,
      'inventory': <String, Object?>{
        'owned': <String>['frame_ring', 'glow_aurora'],
      },
    };
    final List<int> balances = <int>[];
    final Completer<void> balanceRefreshed = Completer<void>();
    void balanceChanged() {
      balances.add(coins.balanceNotifier.value);
      if (coins.balanceNotifier.value == 70 && !balanceRefreshed.isCompleted) balanceRefreshed.complete();
    }

    coins.balanceNotifier.addListener(balanceChanged);
    addTearDown(() => coins.balanceNotifier.removeListener(balanceChanged));
    coins.deltaNotifier.value = 0;
    backend.onCall = (name, _) async => <String, Object?>{
      ...inventoryReply(7, <String>['frame_ring', 'glow_aurora'], changed: false),
      if (name == 'purchaseShopItem') ...<String, Object?>{
        'changed': false,
        'reason': 'duplicate',
        'previousBalance': 15,
        'currentBalance': 5,
        'delta': -10,
      },
    };

    final ShopPurchaseResult result = await coins.purchaseShopItem('frame_ring');
    await firestore.privateEconomyReadStarted.future;
    expect(result.outcome, ShopPurchaseOutcome.purchased);
    expect(result.owned, contains('glow_aurora'));
    expect(app_state.prismUser.coins, 100);
    expect(coins.deltaNotifier.value, 0);
    root.complete(<String, dynamic>{'coins': 70, 'xp': 650});
    await balanceRefreshed.future.timeout(const Duration(seconds: 2));
    await coins.reconcileRankRewards();

    expect(app_state.prismUser.coins, 70);
    expect(balances, isNot(contains(5)));
    expect(firestore.userDocReads, 1);
  });

  for (final bool duplicate in <bool>[false, true]) {
    test('a delayed ${duplicate ? 'replayed' : 'successful'} shop receipt refreshes the current balance', () async {
      await seed();
      final Completer<Object?> delayed = Completer<Object?>();
      final Completer<void> started = Completer<void>();
      final Completer<Map<String, dynamic>> root = Completer<Map<String, dynamic>>();
      firestore.userResponse = root.future;
      firestore.docs['usersv2/${backend.userId}/private/economy'] = <String, dynamic>{
        'rev': 8,
        'inventory': <String, Object?>{
          'owned': <String>['frame_ring', 'theme_rose', 'glow_aurora'],
        },
      };
      final List<int> balances = <int>[];
      final Completer<void> balanceRefreshed = Completer<void>();
      void balanceChanged() {
        balances.add(coins.balanceNotifier.value);
        if (coins.balanceNotifier.value == 70 && !balanceRefreshed.isCompleted) balanceRefreshed.complete();
      }

      coins.balanceNotifier.addListener(balanceChanged);
      addTearDown(() => coins.balanceNotifier.removeListener(balanceChanged));
      backend.onCall = (name, _) {
        if (name == 'purchaseShopItem') {
          started.complete();
          return delayed.future;
        }
        return Future<Object?>.value(inventoryReply(8, <String>['frame_ring', 'theme_rose', 'glow_aurora']));
      };
      final Future<ShopPurchaseResult> purchase = coins.purchaseShopItem('theme_rose');
      await started.future;
      await coins.reconcileRankRewards();
      delayed.complete(<String, Object?>{
        ...inventoryReply(7, <String>['frame_ring', 'theme_rose']),
        if (duplicate) 'reason': 'duplicate',
        'currentBalance': 5,
        'delta': -95,
      });

      expect((await purchase).outcome, ShopPurchaseOutcome.purchased);
      await firestore.privateEconomyReadStarted.future;
      expect(coins.inventoryNotifier.value.owned, contains('glow_aurora'));
      expect(app_state.prismUser.coins, 100);
      root.complete(<String, dynamic>{'coins': 70, 'xp': 650});
      await balanceRefreshed.future.timeout(const Duration(seconds: 2));
      await coins.reconcileRankRewards();

      expect(app_state.prismUser.coins, 70);
      expect(balances, isNot(contains(5)));
      expect(firestore.userDocReads, 1);
      expect((await store.read(backend.userId))?.revision, 8);
    });
  }

  test('a delayed equip cannot overwrite cosmetics after a newer inventory revision', () async {
    await seed();
    final Completer<Object?> delayed = Completer<Object?>();
    final Completer<void> started = Completer<void>();
    backend.onCall = (name, _) {
      if (name == 'equipCosmetic') {
        started.complete();
        return delayed.future;
      }
      return Future<Object?>.value(inventoryReply(8, <String>['frame_ring', 'frame_gold']));
    };
    final Future<bool> equip = coins.equipCosmetic(CosmeticSlot.frame, 'frame_ring');
    await started.future;
    await coins.reconcileRankRewards();
    delayed.complete(<String, Object?>{
      ...inventoryReply(7, <String>['frame_ring']),
      'cosmetics': <String, Object?>{'frame': 'frame_ring'},
    });

    expect(await equip, isFalse);
    expect(coins.inventoryNotifier.value.frame, isNull);
    expect(coins.inventoryNotifier.value.owned, contains('frame_gold'));
  });

  test('a refused equip can reconcile ownership without equipping', () async {
    await seed();
    backend.onCall = (_, _) async => <String, Object?>{
      ...inventoryReply(7, <String>['frame_ring', 'frame_gold']),
      'success': false,
      'reason': 'cosmetic_pro_only',
    };

    expect(await coins.equipCosmetic(CosmeticSlot.frame, 'frame_prism'), isFalse);
    expect(coins.inventoryNotifier.value.owned, contains('frame_gold'));
    expect(coins.inventoryNotifier.value.frame, isNull);
    expect((await store.read(backend.userId))?.revision, 7);
  });

  test('account switches discard reconciliation replies and keep caches scoped', () async {
    await seed();
    final Completer<Object?> delayed = Completer<Object?>();
    final Completer<void> started = Completer<void>();
    backend.onCall = (_, _) {
      started.complete();
      return delayed.future;
    };
    final Future<void> reconcile = coins.reconcileRankRewards();
    await started.future;
    final String previousUser = backend.userId;
    app_state.prismUser.id = 'other-account';
    coins.resetSession();
    delayed.complete(inventoryReply(7, <String>['frame_gold']));
    await reconcile;

    expect(coins.inventoryNotifier.value.owned, isEmpty);
    expect((await store.read(previousUser))?.revision, 6);
    expect(await store.read('other-account'), isNull);
  });

  test('signing out and back into the same account discards the prior session reply', () async {
    await seed();
    final Completer<Object?> delayed = Completer<Object?>();
    final Completer<void> started = Completer<void>();
    backend.onCall = (_, _) {
      started.complete();
      return delayed.future;
    };
    final Future<void> reconcile = coins.reconcileRankRewards();
    await started.future;
    coins.resetSession();
    delayed.complete(inventoryReply(7, <String>['frame_gold']));
    await reconcile;

    expect(coins.inventoryNotifier.value.owned, isEmpty);
    expect((await store.read(backend.userId))?.revision, 6);
  });

  test('a full snapshot at the inventory revision still hydrates quests and passes', () async {
    await seed();
    backend.onCall = (_, _) async => inventoryReply(7, <String>['frame_ring', 'glow_aurora'], changed: false);
    await coins.reconcileRankRewards();
    firestore.docs['usersv2/${backend.userId}/private/economy'] = <String, dynamic>{
      'rev': 7,
      'quests': <String, Object?>{'dayKey': 'server-day'},
      'inventory': <String, Object?>{
        'owned': <String, int>{'frame_ring': 1, 'glow_aurora': 2},
      },
      'passes': <String, Object?>{'premiumPassUntil': DateTime.utc(2099).millisecondsSinceEpoch},
    };

    await coins.refreshBalance();

    expect(coins.questsNotifier.value?.dayKey, 'server-day');
    expect(coins.currentPasses.premiumPassActive(DateTime.utc(2026)), isTrue);
    expect(coins.currentPasses.autoRotatePassActive(DateTime.utc(2026)), isFalse);
    expect(coins.inventoryNotifier.value.owned, contains('glow_aurora'));
    expect((await store.read(backend.userId))?.data['quests'], <String, Object?>{'dayKey': 'server-day'});
  });

  test('a reconciliation in flight coalesces work and runs a follow-up pass', () async {
    await seed();
    int requests = 0;
    final Completer<Object?> firstReply = Completer<Object?>();
    final Completer<void> started = Completer<void>();
    backend.onCall = (_, _) {
      requests++;
      if (requests == 1) {
        started.complete();
        return firstReply.future;
      }
      return Future<Object?>.value(inventoryReply(8, <String>['frame_ring', 'glow_aurora', 'frame_gold']));
    };
    final Future<void> first = coins.reconcileRankRewards();
    await started.future;
    final Future<void> second = coins.reconcileRankRewards();
    final Future<void> third = coins.reconcileRankRewards();
    expect(identical(first, second), isTrue);
    expect(identical(first, third), isTrue);
    firstReply.complete(inventoryReply(7, <String>['frame_ring', 'glow_aurora']));
    await Future.wait(<Future<void>>[first, second, third]);

    expect(requests, 2);
    expect(coins.inventoryNotifier.value.owned, contains('frame_gold'));
  });

  test('offline reconciliation preserves cache and retries on the next reconcile', () async {
    await seed();
    firestore.privateEconomyError = FirestoreError(code: 'unavailable', message: 'offline');
    int requests = 0;
    backend.onCall = (_, _) async {
      requests++;
      if (requests == 1) throw FirebaseFunctionsException(code: 'unavailable', message: 'offline');
      return inventoryReply(7, <String>['frame_ring', 'glow_aurora']);
    };

    await coins.reconcileRankRewards();
    expect(coins.inventoryNotifier.value.owned, <String>{'frame_ring'});
    expect((await store.read(backend.userId))?.revision, 6);
    await coins.reconcileRankRewards();

    expect(requests, 2);
    expect(coins.inventoryNotifier.value.owned, <String>{'frame_ring', 'glow_aurora'});
    expect((await store.read(backend.userId))?.revision, 7);
  });

  test('a successful XP award refreshes ownership without replaying rank-up feedback', () async {
    await seed();
    final Completer<void> reconciled = Completer<void>();
    backend.onCall = (name, _) async {
      if (name == 'awardCoins') {
        return <String, Object?>{
          'success': true,
          'changed': true,
          'currentBalance': 120,
          'previousBalance': 100,
          'delta': 20,
        };
      }
      expect(name, 'reconcileRankRewards');
      if (!reconciled.isCompleted) reconciled.complete();
      return inventoryReply(7, <String>['frame_ring', 'glow_aurora']);
    };

    await coins.award(CoinEarnAction.dailyLogin);
    await reconciled.future;
    await coins.reconcileRankRewards();

    expect(coins.inventoryNotifier.value.owned, contains('glow_aurora'));
    expect(coins.lastClaimNotifier.value, isNull);
    expect(coins.questAwardsNotifier.value, isEmpty);
    expect(app_state.prismUser.coins, 120);
  });

  test('reconciliation hydrates authoritative XP and keeps cached equipped cosmetics', () async {
    await store.writeRoot(backend.userId, <String, dynamic>{
      'xp': 450,
      'xpWeek': <String, Object?>{'weekKey': economyWeekKey(DateTime.now()), 'xp': 20},
      'cosmetics': <String, Object?>{'frame': 'frame_ring', 'nameGlow': 'glow_ember'},
    });
    await seed();
    backend.onCall = (_, _) async => <String, Object?>{
      ...inventoryReply(7, <String>['frame_ring', 'glow_aurora']),
      'xp': 650,
      'xpWeek': <String, Object?>{'weekKey': economyWeekKey(DateTime.now()), 'xp': 40},
    };

    await coins.reconcileRankRewards();

    expect(coins.xpNotifier.value.xp, 650);
    expect(coins.xpNotifier.value.weekXp, 40);
    expect(coins.inventoryNotifier.value.frame, 'frame_ring');
    expect(coins.inventoryNotifier.value.nameGlow, 'glow_ember');
    expect((await store.readRoot(backend.userId))?['cosmetics'], <String, Object?>{
      'frame': 'frame_ring',
      'nameGlow': 'glow_ember',
    });

    backend.onCall = (_, _) async => <String, Object?>{
      ...inventoryReply(7, <String>['frame_ring', 'glow_aurora'], changed: false),
      'xp': 600,
      'xpWeek': <String, Object?>{'weekKey': '2000-W01', 'xp': 999},
    };
    await coins.reconcileRankRewards();
    expect(coins.xpNotifier.value.xp, 650);
    expect(coins.xpNotifier.value.weekXp, 40);
  });

  test('a delayed completed quest keeps award feedback without replaying stale XP or quest state', () async {
    await seed();
    final Completer<Object?> delayed = Completer<Object?>();
    final Completer<void> started = Completer<void>();
    backend.onCall = (name, _) {
      if (name == 'progressQuest') {
        started.complete();
        return delayed.future;
      }
      return Future<Object?>.value(<String, Object?>{
        ...inventoryReply(8, <String>['frame_ring', 'glow_aurora']),
        'xp': 650,
        'xpWeek': <String, Object?>{'weekKey': economyWeekKey(DateTime.now()), 'xp': 25},
      });
    };
    final Future<QuestState?> progress = coins.progressQuest(QuestEvent.viewWotd);
    await started.future;
    await coins.reconcileRankRewards();
    delayed.complete(<String, Object?>{
      'success': true,
      'rev': 7,
      'quests': <String, Object?>{'dayKey': 'stale-day'},
      'currentBalance': 1,
      'awarded': <Object?>[
        <String, Object?>{'id': 'wotd_view', 'coins': 2, 'xp': 25},
      ],
    });
    await progress;
    await coins.reconcileRankRewards();

    expect(coins.questsNotifier.value?.dayKey, 'saved-day');
    expect(coins.questAwardsNotifier.value.single.xp, 25);
    expect(coins.xpNotifier.value.xp, 650);
    expect(app_state.prismUser.coins, 100);
    expect((await store.read(backend.userId))?.revision, 8);
  });
}
