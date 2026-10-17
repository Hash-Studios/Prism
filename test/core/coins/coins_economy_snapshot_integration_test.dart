import 'dart:async';
import 'dart:io';

import 'package:Prism/core/coins/coin_action.dart';
import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/coins/economy_config.dart';
import 'package:Prism/core/coins/economy_snapshot_store.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/firestore/firestore_client.dart';
import 'package:Prism/core/firestore/firestore_error.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/offline/durable_json_store.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/coins_test_backend.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final CoinsTestBackend backend = CoinsTestBackend();
  final CoinsService service = CoinsService.instance;
  late Directory directory;

  setUp(() async {
    await getIt.reset();
    await backend.install();
    getIt.registerSingleton<FirestoreClient>(CoinsTestFirestore());
    directory = await Directory.systemTemp.createTemp('coins-economy-integration-');
    service.resetSession();
    service.setEconomySnapshotStoreForTest(
      EconomySnapshotStore(store: DurableJsonStore('integration', directory: directory)),
    );
  });

  tearDown(() async {
    service.resetSession();
    await getIt.reset();
    await directory.delete(recursive: true);
  });

  test('an acknowledged shop purchase is durable across store instances', () async {
    backend.onCall = (_, _) async => <String, Object>{
      'success': true,
      'changed': true,
      'currentBalance': 90,
      'delta': -10,
      'owned': <String>['frame-cosmos'],
    };

    final result = await service.purchaseShopItem('frame-cosmos');
    final EconomySnapshot? snapshot = await EconomySnapshotStore(
      store: DurableJsonStore('integration', directory: directory),
    ).read(app_state.prismUser.id);

    expect(result.outcome.name, 'purchased');
    expect(snapshot?.revision, 0);
    expect(snapshot?.data['inventory'], <String, dynamic>{
      'owned': <String>['frame-cosmos'],
    });
    expect(snapshot?.data.containsKey('coins'), isFalse);
  });

  test('snapshot disk limit cannot hide an acknowledged purchase', () async {
    final String oversizedOwnedId = String.fromCharCodes(List<int>.filled(1_100_000, 120));
    backend.onCall = (_, _) async => <String, Object>{
      'success': true,
      'changed': true,
      'currentBalance': 90,
      'delta': -10,
      'owned': <String>[oversizedOwnedId],
    };

    final result = await service.purchaseShopItem('frame-acknowledged');

    expect(result.outcome.name, 'purchased');
    expect(app_state.prismUser.coins, 90);
  });

  test('snapshot disk failure does not prevent an unknown spend from queuing its refund', () async {
    final File blockingFile = File('${directory.path}/not-a-directory');
    await blockingFile.writeAsString('blocked');
    service.setEconomySnapshotStoreForTest(
      EconomySnapshotStore(store: DurableJsonStore('blocked', directory: Directory(blockingFile.path))),
    );
    backend.onCall = (_, _) async => throw FirebaseFunctionsException(code: 'unavailable', message: 'offline');

    final result = await service.spend(CoinSpendAction.wallpaperDownload);
    final String queued = getIt<SettingsLocalDataSource>().get<String>('pendingAiRefunds', defaultValue: '');

    expect(result.unknownOutcomeTransactionId, isNotEmpty);
    expect(queued, contains(result.unknownOutcomeTransactionId));
  });

  test('local restore restores passes, quests, and inventory without a Firestore read', () async {
    final CoinsTestFirestore firestore = CoinsTestFirestore();
    getIt.unregister<FirestoreClient>();
    getIt.registerSingleton<FirestoreClient>(firestore);
    final EconomySnapshotStore snapshotStore = EconomySnapshotStore(
      store: DurableJsonStore('integration', directory: directory),
    );
    await snapshotStore.write(backend.userId, 3, <String, dynamic>{
      'passes': <String, Object?>{
        'autoRotatePassUntil': DateTime.utc(2099).millisecondsSinceEpoch,
        'liveStyles': <String, int>{'expired-style': DateTime.utc(2000).millisecondsSinceEpoch},
      },
      'quests': <String, Object?>{'dayKey': '2026-10-17'},
      'inventory': <String, Object?>{
        'owned': <String>['frame-local'],
      },
    });
    await snapshotStore.writeRoot(backend.userId, <String, dynamic>{
      'xp': 240,
      'xpWeek': <String, Object?>{'weekKey': economyWeekKey(DateTime.now()), 'xp': 40},
      'cosmetics': <String, Object?>{'frame': 'frame-equipped', 'nameGlow': 'glow-equipped'},
    });

    await service.restoreLocalEconomyForCurrentUser();

    expect(service.currentPasses.autoRotatePassActive(DateTime.utc(2026)), isTrue);
    expect(service.currentPasses.liveStyleActive('expired-style', DateTime.utc(2026)), isFalse);
    expect(service.questsNotifier.value?.dayKey, '2026-10-17');
    expect(service.inventoryNotifier.value.owned, contains('frame-local'));
    expect(service.xpNotifier.value.xp, 240);
    expect(service.xpNotifier.value.weekXp, 40);
    expect(service.inventoryNotifier.value.frame, 'frame-equipped');
    expect(service.inventoryNotifier.value.nameGlow, 'glow-equipped');
    expect(firestore.getByIdCalls, 0);
    expect(firestore.privateEconomyServerReads, 0);
  });

  test('local restore never applies another owner snapshot', () async {
    await EconomySnapshotStore(store: DurableJsonStore('integration', directory: directory)).write(
      backend.userId,
      3,
      <String, dynamic>{
        'inventory': <String, Object?>{
          'owned': <String>['frame-owner-a'],
        },
      },
    );
    app_state.prismUser.id = 'different-owner';

    await service.restoreLocalEconomyForCurrentUser();

    expect(service.inventoryNotifier.value.owned, isEmpty);
  });

  test('equal revision private read cannot overwrite an acknowledged purchase in flight', () async {
    final Completer<Map<String, dynamic>?> privateResponse = Completer<Map<String, dynamic>?>();
    final CoinsTestFirestore firestore = CoinsTestFirestore()..privateEconomyResponse = privateResponse.future;
    getIt.unregister<FirestoreClient>();
    getIt.registerSingleton<FirestoreClient>(firestore);
    await EconomySnapshotStore(store: DurableJsonStore('integration', directory: directory)).write(
      backend.userId,
      6,
      <String, dynamic>{
        'inventory': <String, Object?>{
          'owned': <String>['frame-acknowledged'],
        },
      },
    );
    backend.onCall = (_, _) async => <String, Object>{
      'success': true,
      'changed': true,
      'owned': <String>['frame-acknowledged'],
    };

    final Future<void> bootstrap = service.bootstrapForCurrentUser();
    await firestore.privateEconomyReadStarted.future.timeout(const Duration(seconds: 2));
    expect(firestore.privateEconomyServerReads, 1);
    await service.purchaseShopItem('frame-acknowledged');
    privateResponse.complete(<String, dynamic>{
      'rev': 6,
      'inventory': <String, dynamic>{'owned': <String, dynamic>{}},
    });
    await bootstrap;

    expect(service.inventoryNotifier.value.owned, contains('frame-acknowledged'));
  });

  test('authoritative missing private read cannot clear a purchase made in flight', () async {
    final Completer<Map<String, dynamic>?> privateResponse = Completer<Map<String, dynamic>?>();
    final CoinsTestFirestore firestore = CoinsTestFirestore()..privateEconomyResponse = privateResponse.future;
    getIt.unregister<FirestoreClient>();
    getIt.registerSingleton<FirestoreClient>(firestore);
    backend.onCall = (_, _) async => <String, Object>{
      'success': true,
      'changed': true,
      'owned': <String>['frame-acknowledged'],
    };

    final Future<void> bootstrap = service.bootstrapForCurrentUser();
    await firestore.privateEconomyReadStarted.future.timeout(const Duration(seconds: 2));
    expect(firestore.privateEconomyServerReads, 1);
    await service.purchaseShopItem('frame-acknowledged');
    privateResponse.complete(null);
    await bootstrap;

    expect(service.inventoryNotifier.value.owned, contains('frame-acknowledged'));
  });

  test('a newer server snapshot replaces omitted fields and preserves timestamp-owned keys', () async {
    final CoinsTestFirestore firestore = CoinsTestFirestore()
      ..docs['usersv2/${backend.userId}/private/economy'] = <String, dynamic>{
        'rev': 7,
        'quests': <String, dynamic>{'dayKey': '2026-10-17'},
        'inventory': <String, dynamic>{
          'owned': <String, dynamic>{'frame-new': 1_800_000_000_000},
        },
      };
    getIt.unregister<FirestoreClient>();
    getIt.registerSingleton<FirestoreClient>(firestore);
    await EconomySnapshotStore(store: DurableJsonStore('integration', directory: directory)).write(
      backend.userId,
      6,
      <String, dynamic>{
        'inventory': <String, Object?>{
          'owned': <String>['frame-old'],
        },
        'drops': <String, Object?>{
          'unlocked': <String, Object?>{'wall': <String, Object?>{}},
        },
      },
    );

    await service.bootstrapForCurrentUser();

    expect(service.inventoryNotifier.value.owned, <String>{'frame-new'});
    expect(service.dropsUnlockedNotifier.value, isEmpty);
  });

  test('an equal-revision quest-patched server snapshot hydrates the complete economy document', () async {
    final CoinsTestFirestore firestore = CoinsTestFirestore()
      ..docs['usersv2/${backend.userId}/private/economy'] = <String, dynamic>{
        'rev': 7,
        'quests': <String, dynamic>{'dayKey': '2026-10-17'},
        'inventory': <String, dynamic>{
          'owned': <String, dynamic>{'frame-retained': 1_800_000_000_000},
        },
        'passes': <String, dynamic>{'autoRotatePassUntil': DateTime.utc(2099).millisecondsSinceEpoch},
      };
    getIt.unregister<FirestoreClient>();
    getIt.registerSingleton<FirestoreClient>(firestore);
    await EconomySnapshotStore(store: DurableJsonStore('integration', directory: directory)).write(
      backend.userId,
      7,
      <String, dynamic>{
        'quests': <String, dynamic>{'dayKey': '2026-10-17'},
      },
    );

    await service.bootstrapForCurrentUser();

    expect(service.questsNotifier.value?.dayKey, '2026-10-17');
    expect(service.inventoryNotifier.value.owned, <String>{'frame-retained'});
    expect(service.currentPasses.autoRotatePassActive(DateTime.utc(2026)), isTrue);
  });

  test('confirmed absence clears durability while unavailable reads preserve it', () async {
    final EconomySnapshotStore store = EconomySnapshotStore(
      store: DurableJsonStore('integration', directory: directory),
    );
    await store.write(backend.userId, 5, <String, dynamic>{
      'inventory': <String, Object?>{
        'owned': <String>['frame-saved'],
      },
    });
    final CoinsTestFirestore firestore = CoinsTestFirestore();
    getIt.unregister<FirestoreClient>();
    getIt.registerSingleton<FirestoreClient>(firestore);

    await service.bootstrapForCurrentUser();
    expect(await store.read(backend.userId), isNull);

    await store.write(backend.userId, 5, <String, dynamic>{
      'inventory': <String, Object?>{
        'owned': <String>['frame-saved'],
      },
    });
    service.resetSession();
    getIt.unregister<FirestoreClient>();
    getIt.registerSingleton<FirestoreClient>(
      CoinsTestFirestore()..privateEconomyError = FirestoreError(code: 'unavailable', message: 'offline'),
    );

    await service.bootstrapForCurrentUser();

    expect(service.inventoryNotifier.value.owned, contains('frame-saved'));
    expect((await store.read(backend.userId))?.revision, 5);
  });

  test('permission denial retains the private snapshot in memory and on disk', () async {
    final EconomySnapshotStore store = EconomySnapshotStore(
      store: DurableJsonStore('integration', directory: directory),
    );
    await store.write(backend.userId, 5, <String, dynamic>{
      'inventory': <String, Object?>{
        'owned': <String>['frame-saved'],
      },
    });
    getIt.unregister<FirestoreClient>();
    getIt.registerSingleton<FirestoreClient>(
      CoinsTestFirestore()..privateEconomyError = FirestoreError(code: 'permission-denied', message: 'denied'),
    );

    await service.bootstrapForCurrentUser();

    expect(service.inventoryNotifier.value.owned, contains('frame-saved'));
    final EconomySnapshot? retained = await store.read(backend.userId);
    expect(retained?.revision, 5);
    expect(retained?.data['inventory'], <String, dynamic>{
      'owned': <String>['frame-saved'],
    });

    service.resetSession();
    await service.restoreLocalEconomyForCurrentUser();

    expect(service.inventoryNotifier.value.owned, contains('frame-saved'));
    final EconomySnapshot? restored = await store.read(backend.userId);
    expect(restored?.revision, 5);
    expect(restored?.data['inventory'], <String, dynamic>{
      'owned': <String>['frame-saved'],
    });
  });

  test('owner cleanup during a confirmed server read cannot restore late state', () async {
    final Completer<Map<String, dynamic>?> privateResponse = Completer<Map<String, dynamic>?>();
    final CoinsTestFirestore firestore = CoinsTestFirestore()..privateEconomyResponse = privateResponse.future;
    getIt.unregister<FirestoreClient>();
    getIt.registerSingleton<FirestoreClient>(firestore);

    final Future<void> bootstrap = service.bootstrapForCurrentUser();
    await firestore.privateEconomyReadStarted.future.timeout(const Duration(seconds: 2));
    await service.clearForUser(backend.userId);
    privateResponse.complete(<String, dynamic>{
      'rev': 8,
      'inventory': <String, dynamic>{
        'owned': <String, dynamic>{'frame-late': 1},
      },
    });
    await bootstrap;

    expect(service.inventoryNotifier.value.owned, isEmpty);
    expect(
      await EconomySnapshotStore(store: DurableJsonStore('integration', directory: directory)).read(backend.userId),
      isNull,
    );
  });

  test('owner cleanup during a pending purchase rejects its late private result', () async {
    final Completer<dynamic> response = Completer<dynamic>();
    final Completer<void> callStarted = Completer<void>();
    backend.callStarted = callStarted;
    backend.onCall = (_, _) => response.future;
    final Future<ShopPurchaseResult> purchase = service.purchaseShopItem('frame-late');
    await callStarted.future.timeout(const Duration(seconds: 2));
    backend.callStarted = null;
    await service.clearForUser(backend.userId);
    response.complete(<String, Object>{
      'success': true,
      'changed': true,
      'currentBalance': 90,
      'delta': -10,
      'owned': <String>['frame-late'],
    });

    final ShopPurchaseResult result = await purchase;
    expect(result.outcome, ShopPurchaseOutcome.failed);
    expect(service.inventoryNotifier.value.owned, isEmpty);
    final EconomySnapshot? snapshot = await EconomySnapshotStore(
      store: DurableJsonStore('integration', directory: directory),
    ).read(backend.userId);
    expect(snapshot, isNull);
  });

  test('a late missing private read cannot erase a pass acknowledged without a revision', () async {
    final Completer<Map<String, dynamic>?> privateResponse = Completer<Map<String, dynamic>?>();
    final CoinsTestFirestore firestore = CoinsTestFirestore()..privateEconomyResponse = privateResponse.future;
    getIt.unregister<FirestoreClient>();
    getIt.registerSingleton<FirestoreClient>(firestore);
    const int passUntil = 1_800_000_000_000;
    backend.onCall = (_, _) async => <String, Object>{
      'success': true,
      'changed': true,
      'previousBalance': 100,
      'currentBalance': 50,
      'delta': -50,
      'passUntil': passUntil,
    };

    final Future<void> bootstrap = service.bootstrapForCurrentUser();
    await firestore.privateEconomyReadStarted.future.timeout(const Duration(seconds: 2));
    final result = await service.spend(CoinSpendAction.autoRotatePass7d);
    privateResponse.complete(null);
    await bootstrap;

    final EconomySnapshot? snapshot = await EconomySnapshotStore(
      store: DurableJsonStore('integration', directory: directory),
    ).read(backend.userId);
    expect(result.success, isTrue);
    expect(service.currentPasses.autoRotatePassUntil?.millisecondsSinceEpoch, passUntil);
    expect(snapshot?.data['passes'], containsPair('autoRotatePassUntil', passUntil));
  });

  test('a late old private read cannot erase an acknowledged live style without a revision', () async {
    final Completer<Map<String, dynamic>?> privateResponse = Completer<Map<String, dynamic>?>();
    final CoinsTestFirestore firestore = CoinsTestFirestore()..privateEconomyResponse = privateResponse.future;
    getIt.unregister<FirestoreClient>();
    getIt.registerSingleton<FirestoreClient>(firestore);
    const int passUntil = 1_800_000_000_000;
    backend.onCall = (_, _) async => <String, Object>{
      'success': true,
      'changed': true,
      'previousBalance': 100,
      'currentBalance': 80,
      'delta': -20,
      'passUntil': passUntil,
    };

    final Future<void> bootstrap = service.bootstrapForCurrentUser();
    await firestore.privateEconomyReadStarted.future.timeout(const Duration(seconds: 2));
    final result = await service.spend(CoinSpendAction.liveWallpaperStyle, styleId: 'neon_wave');
    privateResponse.complete(<String, dynamic>{
      'passes': <String, dynamic>{'liveStyles': <String, dynamic>{}},
    });
    await bootstrap;

    final EconomySnapshot? snapshot = await EconomySnapshotStore(
      store: DurableJsonStore('integration', directory: directory),
    ).read(backend.userId);
    expect(result.success, isTrue);
    expect(service.currentPasses.liveStyles['neon_wave']?.millisecondsSinceEpoch, passUntil);
    expect((snapshot?.data['passes'] as Map<String, dynamic>)['liveStyles'], containsPair('neon_wave', passUntil));
  });

  test('a late old private read cannot restore grace downloads spent without a revision', () async {
    final Completer<Map<String, dynamic>?> privateResponse = Completer<Map<String, dynamic>?>();
    final CoinsTestFirestore firestore = CoinsTestFirestore()..privateEconomyResponse = privateResponse.future;
    getIt.unregister<FirestoreClient>();
    getIt.registerSingleton<FirestoreClient>(firestore);
    backend.onCall = (_, _) async => <String, Object>{
      'success': true,
      'changed': false,
      'bypassed': true,
      'previousBalance': 100,
      'currentBalance': 100,
      'delta': 0,
      'reason': 'grace_download',
      'graceDownloadsLeft': 2,
    };

    final Future<void> bootstrap = service.bootstrapForCurrentUser();
    await firestore.privateEconomyReadStarted.future.timeout(const Duration(seconds: 2));
    final result = await service.spend(CoinSpendAction.wallpaperDownload);
    privateResponse.complete(<String, dynamic>{'graceDownloadsUsed': 0});
    await bootstrap;

    final EconomySnapshot? snapshot = await EconomySnapshotStore(
      store: DurableJsonStore('integration', directory: directory),
    ).read(backend.userId);
    expect(result.success, isTrue);
    expect(service.graceDownloadsLeft, 2);
    expect(snapshot?.data['graceDownloadsUsed'], 1);
  });
}
