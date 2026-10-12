import 'dart:async';
import 'dart:convert';

import 'package:Prism/core/coins/coin_action.dart';
import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/coins/downloaded_link_lookup.dart';
import 'package:Prism/core/constants/app_constants.dart' as app_constants;
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/firestore/firestore_client.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/coins_test_backend.dart';
import '../../support/in_memory_local_store.dart';

const Map<String, Object> _spent = <String, Object>{
  'success': true,
  'changed': true,
  'previousBalance': 100,
  'currentBalance': 95,
  'delta': -5,
  'transactionId': 'spend_tx',
};

const Map<String, Object> _refunded = <String, Object>{
  'success': true,
  'changed': true,
  'previousBalance': 95,
  'currentBalance': 100,
  'delta': 5,
};

class _FlakySettings extends SettingsLocalDataSource {
  _FlakySettings() : super(InMemoryLocalStore());

  bool failSets = false;
  bool failDeletes = false;
  final Set<String> failingKeys = <String>{};

  @override
  Future<void> set(String key, Object? value) {
    if (failSets || failingKeys.contains(key)) throw StateError('write failed');
    return super.set(key, value);
  }

  @override
  Future<void> delete(String key) {
    if (failDeletes) throw StateError('delete failed');
    return super.delete(key);
  }
}

class _PausingSettings extends SettingsLocalDataSource {
  _PausingSettings() : super(InMemoryLocalStore());

  final Completer<void> stored = Completer<void>();
  final Completer<void> resume = Completer<void>();
  bool _paused = false;

  @override
  Future<void> set(String key, Object? value) async {
    await super.set(key, value);
    if (key == _ledgerKey && !_paused) {
      _paused = true;
      stored.complete();
      await resume.future;
    }
  }
}

const String _queueKey = 'pendingAiRefunds';
const String _ledgerKey = 'pendingDownloads_v2';
const String _legacyMarkerKey = 'pendingDownloadMarker';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final backend = CoinsTestBackend();
  final service = CoinsService.instance;
  final toastMessages = <String>[];

  setUp(() async {
    await backend.install();
    service.balanceNotifier.value = 100;
    toastMessages.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('PonnamKarthik/fluttertoast'),
      (call) async {
        if (call.method == 'showToast') toastMessages.add((call.arguments as Map)['msg'] as String);
        return true;
      },
    );
  });
  tearDown(() async {
    final settings = getIt<SettingsLocalDataSource>();
    await settings.delete(_queueKey);
    await settings.delete(_ledgerKey);
    await settings.delete(_legacyMarkerKey);
    service.pendingRetryInterval = const Duration(seconds: 30);
    service.abandonedDownloadAfter = const Duration(minutes: 2);
    service.isLinkDownloaded = isLinkInDownloadedIndex;
  });

  String stored(String key) => getIt<SettingsLocalDataSource>().get<String>(key, defaultValue: '');

  group('download spends', () {
    test('a download spend with no reply after both attempts is queued for refund', () async {
      final requestIds = <String>[];
      backend.onCall = (name, parameters) {
        requestIds.add(parameters['requestId'] as String);
        return Future<dynamic>.error(FirebaseFunctionsException(code: 'deadline-exceeded', message: 'slow'));
      };

      final result = await service.spend(CoinSpendAction.wallpaperDownload);

      final expectedId = 'spend_${app_state.prismUser.id}_${requestIds.first}';
      expect(result.unknownOutcomeTransactionId, expectedId);
      final entries = (jsonDecode(stored(_queueKey)) as List<Object?>).cast<Map<String, Object?>>();
      expect(entries.single['transactionId'], expectedId);
      expect(entries.single['action'], 'wallpaperDownload');
      expect(entries.single['reason'], 'download_failed_refund');
    });

    test('a queued download refund is sent with the download action and reason', () async {
      backend.onCall = (name, parameters) async =>
          throw FirebaseFunctionsException(code: 'unavailable', message: 'offline');
      await service.spend(CoinSpendAction.premiumWallpaperDownload);
      final refunds = <Map<String, dynamic>>[];
      backend.onCall = (name, parameters) async {
        refunds.add(parameters);
        return _refunded;
      };

      await service.retryPendingRefunds();

      expect(refunds.single['reason'], 'download_failed_refund');
      expect(refunds.single['transactionId'], startsWith('spend_${app_state.prismUser.id}_'));
      expect(stored(_queueKey), isEmpty);
    });

    test('a definite spend failure queues nothing', () async {
      backend.onCall = (name, parameters) async =>
          throw FirebaseFunctionsException(code: 'permission-denied', message: 'no');

      await service.spend(CoinSpendAction.wallpaperDownload);

      expect(stored(_queueKey), isEmpty);
    });

    test('the ledger label is sent trimmed to 60 characters', () async {
      final calls = <Map<String, dynamic>>[];
      backend.onCall = (name, parameters) async {
        calls.add(parameters);
        return _spent;
      };

      await service.spend(CoinSpendAction.wallpaperDownload, label: '  ${'a' * 80}  ');
      await service.spend(CoinSpendAction.wallpaperDownload, label: '   ');
      await service.spend(CoinSpendAction.wallpaperDownload);

      expect(calls[0]['label'], 'a' * 60);
      expect(calls[1].containsKey('label'), isFalse);
      expect(calls[2].containsKey('label'), isFalse);
    });
  });

  group('rewarded ad awards', () {
    test('a rewarded ad award carries a requestId and is retried once with the same id', () async {
      final requestIds = <String>[];
      backend.onCall = (name, parameters) async {
        requestIds.add(parameters['requestId'] as String);
        if (requestIds.length == 1) throw FirebaseFunctionsException(code: 'deadline-exceeded', message: 'slow');
        return <String, Object>{
          'success': true,
          'changed': true,
          'previousBalance': 100,
          'currentBalance': 110,
          'delta': 10,
          'adsRemaining': 3,
        };
      };

      final result = await service.award(CoinEarnAction.rewardedAd);

      expect(requestIds, hasLength(2));
      expect(requestIds[0], requestIds[1]);
      expect(requestIds[0], matches(RegExp(r'^[A-Za-z0-9_-]{8,64}$')));
      expect(result.changed, isTrue);
      expect(result.adsRemaining, 3);
      expect(service.adsRemainingToday, 3);
      expect(stored(_queueKey), isEmpty);
    });

    test('other awards do not carry a requestId', () async {
      final calls = <Map<String, dynamic>>[];
      backend.onCall = (name, parameters) async {
        calls.add(parameters);
        return _refunded;
      };

      await service.award(CoinEarnAction.dailyLogin);

      expect(calls.single.containsKey('requestId'), isFalse);
    });

    test('an ad reward with no reply after both attempts is queued and credited on retry', () async {
      final requestIds = <String>[];
      backend.onCall = (name, parameters) {
        requestIds.add(parameters['requestId'] as String);
        return Future<dynamic>.error(FirebaseFunctionsException(code: 'unavailable', message: 'offline'));
      };

      final result = await service.award(CoinEarnAction.rewardedAd);

      expect(requestIds, hasLength(2));
      expect(result.unknownOutcomeTransactionId, 'award_${app_state.prismUser.id}_${requestIds.first}');
      final entries = (jsonDecode(stored(_queueKey)) as List<Object?>).cast<Map<String, Object?>>();
      expect(entries.single['kind'], 'reward');
      expect(entries.single['requestId'], requestIds.first);

      final retried = <String>[];
      backend.onCall = (name, parameters) async {
        retried.add(parameters['requestId'] as String);
        return <String, Object>{
          'success': true,
          'changed': true,
          'previousBalance': 100,
          'currentBalance': 110,
          'delta': 10,
        };
      };
      await service.retryPendingRefunds();

      expect(retried, <String>[requestIds.first]);
      expect(app_state.prismUser.coins, 110);
      expect(stored(_queueKey), isEmpty);
      expect(toastMessages, contains('Your ad reward was added.'));
    });

    test('a daily-limit reply is not queued', () async {
      backend.onCall = (name, parameters) async => <String, Object>{
        'success': true,
        'changed': false,
        'previousBalance': 100,
        'currentBalance': 100,
        'delta': 0,
        'reason': 'rewarded_ad_limit',
        'adsRemaining': 0,
      };

      final result = await service.award(CoinEarnAction.rewardedAd);

      expect(result.reason, 'rewarded_ad_limit');
      expect(service.adsRemainingToday, 0);
      expect(stored(_queueKey), isEmpty);
    });

    test('a queued refund stays queued when the account changes during its retry', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      await getIt<SettingsLocalDataSource>().set(
        _queueKey,
        '[{"userId":"${app_state.prismUser.id}","kind":"refund","transactionId":"spend_tx_queued",'
        '"action":"aiGeneration","reason":"ai_generation_failed_refund","atMs":$now}]',
      );
      backend.onCall = (name, parameters) async {
        app_state.prismUser = app_constants.createGuestPrismUser();
        return _refunded;
      };

      await service.retryPendingRefunds();

      expect(stored(_queueKey), contains('spend_tx_queued'));
    });

    test('a reward older than 24 hours is dropped without a call', () async {
      final old = DateTime.now().subtract(const Duration(hours: 25)).millisecondsSinceEpoch;
      await getIt<SettingsLocalDataSource>().set(
        _queueKey,
        '[{"userId":"${app_state.prismUser.id}","kind":"reward","requestId":"old-request","atMs":$old}]',
      );
      var calls = 0;
      backend.onCall = (name, parameters) async {
        calls++;
        return _refunded;
      };

      await service.retryPendingRefunds();

      expect(calls, 0);
      expect(stored(_queueKey), isEmpty);
    });
  });

  group('pending download ledger', () {
    const linkA = 'https://x.test/a.jpg';
    const linkB = 'https://x.test/b.jpg';

    List<Map<String, dynamic>> ledger() {
      final raw = stored(_ledgerKey);
      return raw.isEmpty ? <Map<String, dynamic>>[] : (jsonDecode(raw) as List<Object?>).cast<Map<String, dynamic>>();
    }

    int msAgo(Duration age) => DateTime.now().subtract(age).millisecondsSinceEpoch;

    Map<String, Object?> entry({
      String txId = 'spend_tx_seeded',
      String? userId,
      String link = linkA,
      bool saved = false,
      Object? at,
    }) => <String, Object?>{
      'txId': txId,
      'userId': userId ?? app_state.prismUser.id,
      'link': link,
      'action': 'wallpaperDownload',
      'at': at ?? msAgo(const Duration(minutes: 3)),
      'saved': saved,
    };

    Future<void> seed(List<Map<String, Object?>> entries) =>
        getIt<SettingsLocalDataSource>().set(_ledgerKey, jsonEncode(entries));

    Future<void> seedLegacyMarker({Object? at, String txId = 'spend_tx_legacy'}) =>
        getIt<SettingsLocalDataSource>().set(
          _legacyMarkerKey,
          jsonEncode(<String, Object?>{
            'userId': app_state.prismUser.id,
            'txId': txId,
            'link': linkA,
            'action': 'wallpaperDownload',
            if (at != null) 'at': at,
          }),
        );

    Future<String> pay(String link) async {
      String? requestId;
      backend.onCall = (name, parameters) async {
        requestId = parameters['requestId'] as String;
        return _spent;
      };
      await service.spend(CoinSpendAction.wallpaperDownload, pendingDownloadLink: link);
      return 'spend_${app_state.prismUser.id}_$requestId';
    }

    List<Map<String, dynamic>> recordRefunds() {
      final refunds = <Map<String, dynamic>>[];
      backend.onCall = (name, parameters) async {
        refunds.add(parameters);
        return _refunded;
      };
      return refunds;
    }

    Iterable<Object?> txIds(List<Map<String, dynamic>> refunds) => refunds.map((refund) => refund['transactionId']);

    test('the entry is written before the spend call and kept after a charged spend', () async {
      String? ledgerDuringCall;
      backend.onCall = (name, parameters) async {
        ledgerDuringCall = stored(_ledgerKey);
        return _spent;
      };

      await service.spend(CoinSpendAction.wallpaperDownload, pendingDownloadLink: linkA);

      final during = (jsonDecode(ledgerDuringCall!) as List<Object?>).cast<Map<String, dynamic>>().single;
      expect(during['link'], linkA);
      expect(during['userId'], app_state.prismUser.id);
      expect(during['action'], 'wallpaperDownload');
      expect(during['txId'], startsWith('spend_${app_state.prismUser.id}_'));
      expect(during['at'], isA<int>());
      expect(during['saved'], isFalse);
      expect(ledger().single['txId'], during['txId']);
    });

    test('a refused spend removes only its own entry', () async {
      final firstTxId = await pay(linkA);
      backend.onCall = (name, parameters) async => <String, Object>{
        'success': false,
        'changed': false,
        'insufficientBalance': true,
        'previousBalance': 1,
        'currentBalance': 1,
        'delta': 0,
      };

      await service.spend(CoinSpendAction.wallpaperDownload, pendingDownloadLink: linkB);

      expect(ledger().map((e) => e['txId']), <Object?>[firstTxId]);
    });

    test('a spend with no reply leaves its refund to the queue and not to the ledger', () async {
      backend.onCall = (name, parameters) async =>
          throw FirebaseFunctionsException(code: 'deadline-exceeded', message: 'slow');

      await service.spend(CoinSpendAction.wallpaperDownload, pendingDownloadLink: linkA);

      expect(ledger(), isEmpty);
      expect(stored(_queueKey), isNotEmpty);
    });

    test('two paid downloads that both end with an unconfirmed refund are both refunded once their taps end', () async {
      final txIdA = await pay(linkA);
      final txIdB = await pay(linkB);
      await service.releasePendingDownload(txIdA);
      await service.releasePendingDownload(txIdB);
      service.abandonedDownloadAfter = Duration.zero;
      final refunds = recordRefunds();

      await service.refundAbandonedDownload();

      expect(txIds(refunds), unorderedEquals(<Object?>[txIdA, txIdB]));
      expect(ledger(), isEmpty);
    });

    test('a download that fails while another one saves is still refunded once its tap ends', () async {
      final txIdA = await pay(linkA);
      final txIdB = await pay(linkB);
      await service.markPendingDownloadSaved(txIdA);
      await service.clearPendingDownload(txIdA);
      await service.releasePendingDownload(txIdB);
      service.abandonedDownloadAfter = Duration.zero;
      final refunds = recordRefunds();

      await service.refundAbandonedDownload();

      expect(txIds(refunds), <Object?>[txIdB]);
      expect(ledger(), isEmpty);
    });

    test('finishing one download leaves the entry of the other one in the ledger', () async {
      final txIdA = await pay(linkA);
      final txIdB = await pay(linkB);

      await service.markPendingDownloadSaved(txIdA);
      await service.clearPendingDownload(txIdA);

      expect(ledger().map((e) => e['txId']), <Object?>[txIdB]);
      expect(ledger().single['saved'], isFalse);
    });

    test('a download that saved before the app died is not refunded', () async {
      final txId = await pay(linkA);
      await service.markPendingDownloadSaved(txId);
      service.abandonedDownloadAfter = Duration.zero;
      final refunds = recordRefunds();

      await service.refundAbandonedDownload();

      expect(refunds, isEmpty);
      expect(ledger(), isEmpty);
    });

    test('a saved entry is dropped without a refund whatever its time says', () async {
      await seed(<Map<String, Object?>>[
        entry(txId: 'saved_long_ago', saved: true),
        entry(txId: 'saved_no_time', saved: true, at: 'unknown'),
        entry(
          txId: 'saved_in_the_future',
          saved: true,
          at: DateTime.now().add(const Duration(days: 3)).millisecondsSinceEpoch,
        ),
      ]);
      final refunds = recordRefunds();

      await service.refundAbandonedDownload();

      expect(refunds, isEmpty);
      expect(ledger(), isEmpty);
    });

    test('an unsaved entry older than 2 minutes is refunded by its own txId and the user is told', () async {
      await seed(<Map<String, Object?>>[entry(txId: 'spend_tx_old')]);
      final refunds = recordRefunds();

      await service.refundAbandonedDownload();

      expect(refunds.single['transactionId'], 'spend_tx_old');
      expect(refunds.single['reason'], 'download_failed_refund');
      expect(ledger(), isEmpty);
      expect(toastMessages, contains('Your last download did not finish. Coins returned.'));
    });

    test('an entry younger than 2 minutes is left alone', () async {
      await seed(<Map<String, Object?>>[entry(at: msAgo(const Duration(seconds: 30)))]);
      final refunds = recordRefunds();

      await service.refundAbandonedDownload();

      expect(refunds, isEmpty);
      expect(ledger(), hasLength(1));
    });

    test(
      'a legacy marker younger than the grace period is refunded when it comes of age, with no further start',
      () async {
        service.abandonedDownloadAfter = const Duration(milliseconds: 300);
        await seedLegacyMarker(at: msAgo(const Duration(milliseconds: 100)));
        final refunds = recordRefunds();

        await service.refundAbandonedDownload();
        expect(refunds, isEmpty);
        await Future<void>.delayed(const Duration(milliseconds: 600));

        expect(txIds(refunds), <Object?>['spend_tx_legacy']);
      },
    );

    test(
      'a ledger entry younger than the grace period is refunded when it comes of age, with no further start',
      () async {
        service.abandonedDownloadAfter = const Duration(milliseconds: 300);
        await seed(<Map<String, Object?>>[entry(at: msAgo(const Duration(milliseconds: 100)))]);
        final refunds = recordRefunds();

        await service.refundAbandonedDownload();
        expect(refunds, isEmpty);
        await Future<void>.delayed(const Duration(milliseconds: 600));

        expect(txIds(refunds), <Object?>['spend_tx_seeded']);
        expect(ledger(), isEmpty);
      },
    );

    test('a download of this session whose refund never confirmed is refunded once it comes of age', () async {
      service.abandonedDownloadAfter = const Duration(milliseconds: 300);
      final txId = await pay(linkA);
      await service.releasePendingDownload(txId);
      final refunds = recordRefunds();

      await Future<void>.delayed(const Duration(milliseconds: 600));

      expect(txIds(refunds), <Object?>[txId]);
      expect(ledger(), isEmpty);
    });

    test('a download whose tap is still running is not refunded when the grace period passes', () async {
      service.abandonedDownloadAfter = const Duration(milliseconds: 300);
      await pay(linkA);
      final refunds = recordRefunds();

      await Future<void>.delayed(const Duration(milliseconds: 600));
      await service.refundAbandonedDownload();
      await service.retryPendingRefunds();

      expect(refunds, isEmpty);
      expect(ledger(), hasLength(1));
    });

    test('a running download is refunded right after its tap ends with an unconfirmed refund', () async {
      service.abandonedDownloadAfter = const Duration(milliseconds: 300);
      final txId = await pay(linkA);
      final refunds = recordRefunds();
      await Future<void>.delayed(const Duration(milliseconds: 600));
      expect(refunds, isEmpty);

      await service.releasePendingDownload(txId);

      expect(txIds(refunds), <Object?>[txId]);
      expect(ledger(), isEmpty);
    });

    test('releasing one download leaves the running download of another one alone', () async {
      service.abandonedDownloadAfter = Duration.zero;
      final txIdA = await pay(linkA);
      final txIdB = await pay(linkB);
      final refunds = recordRefunds();

      await service.releasePendingDownload(txIdA);
      await service.refundAbandonedDownload();

      expect(txIds(refunds), <Object?>[txIdA]);
      expect(ledger().map((e) => e['txId']), <Object?>[txIdB]);
    });

    test('releasing a download that already saved refunds nothing and keeps the stored entry', () async {
      service.abandonedDownloadAfter = Duration.zero;
      final txId = await pay(linkA);
      final refunds = recordRefunds();
      await service.markPendingDownloadSaved(txId);

      await service.releasePendingDownload(txId);

      expect(refunds, isEmpty);
      expect(ledger().single['saved'], isTrue);
    });

    test('an entry stored by an earlier run is refunded while a download of this run keeps running', () async {
      service.abandonedDownloadAfter = Duration.zero;
      await seed(<Map<String, Object?>>[entry(txId: 'spend_tx_earlier_run')]);
      final runningTxId = await pay(linkB);
      final refunds = recordRefunds();

      await service.refundAbandonedDownload();

      expect(txIds(refunds), <Object?>['spend_tx_earlier_run']);
      expect(ledger().map((e) => e['txId']), <Object?>[runningTxId]);
    });

    test('a download that saves before it comes of age is never refunded by the timer', () async {
      service.abandonedDownloadAfter = const Duration(milliseconds: 300);
      final txId = await pay(linkA);
      final refunds = recordRefunds();

      await service.markPendingDownloadSaved(txId);
      await service.clearPendingDownload(txId);
      await Future<void>.delayed(const Duration(milliseconds: 600));

      expect(refunds, isEmpty);
    });

    test('an entry stamped far ahead of the clock is refunded at once', () async {
      await seed(<Map<String, Object?>>[entry(at: DateTime.now().add(const Duration(days: 1)).millisecondsSinceEpoch)]);
      final refunds = recordRefunds();

      await service.refundAbandonedDownload();

      expect(txIds(refunds), <Object?>['spend_tx_seeded']);
    });

    test('an entry stamped slightly ahead of the clock waits the full grace period', () async {
      service.abandonedDownloadAfter = const Duration(milliseconds: 300);
      await seed(<Map<String, Object?>>[
        entry(at: DateTime.now().add(const Duration(milliseconds: 100)).millisecondsSinceEpoch),
      ]);
      final refunds = recordRefunds();

      await service.refundAbandonedDownload();
      expect(refunds, isEmpty);
      await Future<void>.delayed(const Duration(milliseconds: 900));

      expect(txIds(refunds), <Object?>['spend_tx_seeded']);
    });

    test('a refund the network lost keeps the entry, and the retry loop refunds it later', () async {
      service.pendingRetryInterval = const Duration(milliseconds: 20);
      service.startPendingRetryWatch();
      await seedLegacyMarker(at: msAgo(const Duration(minutes: 3)));
      var attempts = 0;
      final refunds = <Map<String, dynamic>>[];
      backend.onCall = (name, parameters) async {
        attempts++;
        if (attempts < 3) throw FirebaseFunctionsException(code: 'unavailable', message: 'offline');
        refunds.add(parameters);
        return _refunded;
      };

      await service.refundAbandonedDownload();
      expect(attempts, 1);
      expect(toastMessages, isEmpty);
      await Future<void>.delayed(const Duration(milliseconds: 400));

      expect(attempts, 3);
      expect(txIds(refunds), <Object?>['spend_tx_legacy']);
      expect(ledger(), isEmpty);
    });

    test('a refund the server refuses for good removes the entry', () async {
      await seed(<Map<String, Object?>>[entry()]);
      var calls = 0;
      backend.onCall = (name, parameters) {
        calls++;
        return Future<dynamic>.error(
          FirebaseFunctionsException(code: 'failed-precondition', message: 'No refundable spend.'),
        );
      };

      await service.refundAbandonedDownload();

      expect(calls, 1);
      expect(ledger(), isEmpty);
      expect(toastMessages, isEmpty);
    });

    test('the retry pass also refunds an abandoned download', () async {
      await seed(<Map<String, Object?>>[entry(txId: 'spend_tx_via_retry')]);
      final refunds = recordRefunds();

      await service.retryPendingRefunds();

      expect(txIds(refunds), <Object?>['spend_tx_via_retry']);
      expect(ledger(), isEmpty);
    });

    test('app start refunds an abandoned download', () async {
      final firestore = CoinsTestFirestore()..userData = <String, dynamic>{'coins': 100};
      getIt.registerSingleton<FirestoreClient>(firestore);
      addTearDown(() => getIt.unregister<FirestoreClient>());
      await seed(<Map<String, Object?>>[entry(txId: 'spend_tx_at_start')]);
      final refunds = recordRefunds();

      await service.bootstrapForCurrentUser();

      expect(txIds(refunds), <Object?>['spend_tx_at_start']);
      expect(ledger(), isEmpty);
    });

    test('a legacy marker is moved into the ledger and refunded', () async {
      await seedLegacyMarker(at: msAgo(const Duration(minutes: 3)));
      final refunds = recordRefunds();

      await service.refundAbandonedDownload();

      expect(refunds.single['transactionId'], 'spend_tx_legacy');
      expect(stored(_legacyMarkerKey), isEmpty);
      expect(ledger(), isEmpty);
    });

    test('a legacy marker that is still young moves into the ledger and the old key goes', () async {
      await seedLegacyMarker(at: msAgo(const Duration(seconds: 10)));
      final refunds = recordRefunds();

      await service.refundAbandonedDownload();

      expect(refunds, isEmpty);
      expect(stored(_legacyMarkerKey), isEmpty);
      expect(ledger().single, <String, Object?>{
        'txId': 'spend_tx_legacy',
        'userId': app_state.prismUser.id,
        'link': linkA,
        'action': 'wallpaperDownload',
        'at': ledger().single['at'],
        'saved': false,
        'legacy': true,
      });
    });

    test('a marker with no time is refunded', () async {
      await seedLegacyMarker();
      final refunds = recordRefunds();

      await service.refundAbandonedDownload();

      expect(txIds(refunds), <Object?>['spend_tx_legacy']);
    });

    test('a legacy marker whose link is in the Downloads index is dropped without a refund', () async {
      service.isLinkDownloaded = (link) => link == linkA;
      await seedLegacyMarker(at: msAgo(const Duration(minutes: 3)));
      final refunds = recordRefunds();

      await service.refundAbandonedDownload();

      expect(refunds, isEmpty);
      expect(stored(_legacyMarkerKey), isEmpty);
      expect(ledger(), isEmpty);
    });

    test('a legacy marker whose link is not in the Downloads index is refunded', () async {
      service.isLinkDownloaded = (link) => link == linkB;
      await seedLegacyMarker(at: msAgo(const Duration(minutes: 3)));
      final refunds = recordRefunds();

      await service.refundAbandonedDownload();

      expect(txIds(refunds), <Object?>['spend_tx_legacy']);
      expect(ledger(), isEmpty);
    });

    test('a legacy marker that waits for its grace period is still judged by the index when it comes of age', () async {
      service.abandonedDownloadAfter = const Duration(milliseconds: 300);
      await seedLegacyMarker(at: msAgo(const Duration(milliseconds: 100)));
      final refunds = recordRefunds();
      await service.refundAbandonedDownload();
      service.isLinkDownloaded = (link) => link == linkA;

      await Future<void>.delayed(const Duration(milliseconds: 600));

      expect(refunds, isEmpty);
      expect(ledger(), isEmpty);
    });

    test('an entry written by this build never consults the Downloads index', () async {
      service.isLinkDownloaded = (_) => true;
      await seed(<Map<String, Object?>>[entry(txId: 'spend_tx_new')]);
      final refunds = recordRefunds();

      await service.refundAbandonedDownload();

      expect(txIds(refunds), <Object?>['spend_tx_new']);
      expect(ledger(), isEmpty);
    });

    test('a time that is infinite or text never breaks the other entries', () async {
      final user = app_state.prismUser.id;
      String raw(String txId, String at) =>
          '{"txId":"$txId","userId":"$user","link":"$linkA","action":"wallpaperDownload","at":$at,"saved":false}';
      await getIt<SettingsLocalDataSource>().set(
        _ledgerKey,
        '[${raw('infinite', '1e309')},${raw('negative_infinite', '-1e309')},${raw('text', '"x"')},'
        '${raw('normal', '${msAgo(const Duration(minutes: 3))}')}]',
      );
      final refunds = recordRefunds();

      await service.refundAbandonedDownload();

      expect(txIds(refunds), unorderedEquals(<Object?>['infinite', 'negative_infinite', 'text', 'normal']));
      expect(ledger(), isEmpty);
    });

    test('an entry whose time is not a number is refunded', () async {
      await seed(<Map<String, Object?>>[entry(at: 'yesterday')]);
      final refunds = recordRefunds();

      await service.refundAbandonedDownload();

      expect(txIds(refunds), <Object?>['spend_tx_seeded']);
    });

    test('entries with no txId, user or link are dropped without a call', () async {
      await seed(<Map<String, Object?>>[
        entry()..remove('txId'),
        entry(txId: 'no_user')..['userId'] = '',
        entry(txId: 'no_link', link: ''),
        entry(txId: 'spend_tx_valid'),
      ]);
      final refunds = recordRefunds();

      await service.refundAbandonedDownload();

      expect(txIds(refunds), <Object?>['spend_tx_valid']);
      expect(ledger(), isEmpty);
    });

    test('an entry of another account is left alone while the signed-in account is served', () async {
      await seed(<Map<String, Object?>>[
        entry(txId: 'spend_tx_other', userId: 'someone-else'),
        entry(txId: 'spend_tx_mine'),
      ]);
      final refunds = recordRefunds();

      await service.refundAbandonedDownload();

      expect(txIds(refunds), <Object?>['spend_tx_mine']);
      expect(ledger().map((e) => e['txId']), <Object?>['spend_tx_other']);
    });

    test('a timer that fires after sign-out refunds nothing, and the entry is served after the next sign-in', () async {
      service.abandonedDownloadAfter = const Duration(milliseconds: 300);
      final userId = app_state.prismUser.id;
      final txId = await pay(linkA);
      await service.releasePendingDownload(txId);
      final refunds = recordRefunds();
      app_state.prismUser = app_constants.createGuestPrismUser();

      await Future<void>.delayed(const Duration(milliseconds: 600));
      expect(refunds, isEmpty);

      app_state.prismUser = app_constants.createGuestPrismUser()
        ..id = userId
        ..loggedIn = true;
      await service.refundAbandonedDownload();

      expect(txIds(refunds), <Object?>[txId]);
    });

    test('a sign-out during the refund call keeps the entry for the next sign-in', () async {
      final userId = app_state.prismUser.id;
      await seed(<Map<String, Object?>>[entry(txId: 'spend_tx_signed_out')]);
      backend.onCall = (name, parameters) async {
        app_state.prismUser = app_constants.createGuestPrismUser();
        return _refunded;
      };

      await service.refundAbandonedDownload();

      expect(ledger().map((e) => e['txId']), <Object?>['spend_tx_signed_out']);

      app_state.prismUser = app_constants.createGuestPrismUser()
        ..id = userId
        ..loggedIn = true;
      final refunds = recordRefunds();
      await service.refundAbandonedDownload();

      expect(txIds(refunds), <Object?>['spend_tx_signed_out']);
      expect(ledger(), isEmpty);
    });

    test('mark and clear act only on the entry of the given txId, whatever its link', () async {
      await seed(<Map<String, Object?>>[
        entry(txId: 'older'),
        entry(txId: 'newer'),
        entry(txId: 'other_link', link: linkB),
      ]);

      await service.markPendingDownloadSaved('older');
      expect(ledger().map((e) => '${e['txId']}:${e['saved']}'), <String>[
        'older:true',
        'newer:false',
        'other_link:false',
      ]);

      await service.clearPendingDownload('newer');
      expect(ledger().map((e) => e['txId']), <Object?>['older', 'other_link']);
    });

    test('mark, clear and release act on the entry of an account that is no longer signed in', () async {
      await seed(<Map<String, Object?>>[
        entry(txId: 'theirs_marked', userId: 'someone-else'),
        entry(txId: 'theirs_cleared', userId: 'someone-else'),
      ]);

      await service.markPendingDownloadSaved('theirs_marked');
      await service.clearPendingDownload('theirs_cleared');

      expect(ledger().map((e) => '${e['txId']}:${e['userId']}:${e['saved']}'), <String>[
        'theirs_marked:someone-else:true',
      ]);
    });

    test('an unknown txId changes nothing', () async {
      await seed(<Map<String, Object?>>[entry(txId: 'known')]);
      final before = stored(_ledgerKey);

      await service.markPendingDownloadSaved('unknown');
      await service.clearPendingDownload('unknown');
      await service.releasePendingDownload('unknown');

      expect(stored(_ledgerKey), before);
    });

    test('a charged spend hands back the ledger txId, an uncharged one hands back none', () async {
      final requestIds = <String>[];
      backend.onCall = (name, parameters) async {
        requestIds.add(parameters['requestId'] as String);
        return _spent;
      };
      final charged = await service.spend(CoinSpendAction.wallpaperDownload, pendingDownloadLink: linkA);
      final untracked = await service.spend(CoinSpendAction.wallpaperDownload);
      backend.onCall = (name, parameters) async => <String, Object>{
        'success': false,
        'changed': false,
        'insufficientBalance': true,
        'previousBalance': 1,
        'currentBalance': 1,
        'delta': 0,
      };
      final refused = await service.spend(CoinSpendAction.wallpaperDownload, pendingDownloadLink: linkB);

      expect(charged.pendingDownloadTxId, 'spend_${app_state.prismUser.id}_${requestIds.first}');
      expect(charged.pendingDownloadTxId, ledger().single['txId']);
      expect(charged.transactionId, 'spend_tx');
      expect(untracked.pendingDownloadTxId, isEmpty);
      expect(refused.pendingDownloadTxId, isEmpty);
    });

    group('when the ledger cannot be written', () {
      late _FlakySettings flaky;
      late SettingsLocalDataSource original;

      setUp(() {
        original = getIt<SettingsLocalDataSource>();
        flaky = _FlakySettings();
        getIt.unregister<SettingsLocalDataSource>();
        getIt.registerSingleton<SettingsLocalDataSource>(flaky);
      });
      tearDown(() {
        getIt.unregister<SettingsLocalDataSource>();
        getIt.registerSingleton<SettingsLocalDataSource>(original);
      });

      test('a failing saved write keeps the download live, so recovery does not refund it in this session', () async {
        final txId = await pay(linkA);
        flaky.failSets = true;
        await service.markPendingDownloadSaved(txId);
        flaky.failSets = false;
        service.abandonedDownloadAfter = Duration.zero;
        final refunds = recordRefunds();

        await service.refundAbandonedDownload();

        expect(refunds, isEmpty);
        expect(ledger().single['saved'], isFalse);

        await service.markPendingDownloadSaved(txId);
        await service.refundAbandonedDownload();

        expect(refunds, isEmpty);
        expect(ledger(), isEmpty);
      });

      test('a failing clear write keeps the download live, so recovery does not refund it in this session', () async {
        final txIdA = await pay(linkA);
        final txIdB = await pay(linkB);
        await service.releasePendingDownload(txIdB);
        flaky.failSets = true;
        await service.clearPendingDownload(txIdA);
        flaky.failSets = false;
        service.abandonedDownloadAfter = Duration.zero;
        final refunds = recordRefunds();

        await service.refundAbandonedDownload();

        expect(txIds(refunds), <Object?>[txIdB]);
        expect(ledger().map((e) => e['txId']), <Object?>[txIdA]);
      });

      test('a failing delete keeps the download live as well', () async {
        final txId = await pay(linkA);
        flaky.failDeletes = true;
        await service.clearPendingDownload(txId);
        flaky.failDeletes = false;
        service.abandonedDownloadAfter = Duration.zero;
        final refunds = recordRefunds();

        await service.refundAbandonedDownload();

        expect(refunds, isEmpty);
      });
    });

    group('when the account or the storage changes under a spend', () {
      late SettingsLocalDataSource original;

      setUp(() {
        original = getIt<SettingsLocalDataSource>();
      });
      tearDown(() {
        getIt.unregister<SettingsLocalDataSource>();
        getIt.registerSingleton<SettingsLocalDataSource>(original);
      });

      void useSettings(SettingsLocalDataSource settings) {
        getIt.unregister<SettingsLocalDataSource>();
        getIt.registerSingleton<SettingsLocalDataSource>(settings);
      }

      test('another account signing in while the entry is written is never charged', () async {
        final payer = app_state.prismUser.id;
        final settings = _PausingSettings();
        useSettings(settings);
        final calls = <String>[];
        backend.onCall = (name, parameters) async {
          calls.add('$name:${app_state.prismUser.id}');
          return _spent;
        };

        final spend = service.spend(CoinSpendAction.wallpaperDownload, pendingDownloadLink: linkA);
        await settings.stored.future;
        expect(ledger().single['userId'], payer);
        app_state.prismUser = app_constants.createGuestPrismUser()
          ..id = 'account-b'
          ..loggedIn = true
          ..coins = 100;
        settings.resume.complete();
        final result = await spend;

        expect(calls, isEmpty);
        expect(result.success, isFalse);
        expect(result.reason, 'not_logged_in');
        expect(result.pendingDownloadTxId, isEmpty);
        expect(result.unknownOutcomeTransactionId, isEmpty);
        expect(ledger(), isEmpty);
        expect(stored(_queueKey), isEmpty);
        expect(app_state.prismUser.coins, 100);

        app_state.prismUser = app_constants.createGuestPrismUser()
          ..id = payer
          ..loggedIn = true
          ..coins = 100;
        service.abandonedDownloadAfter = Duration.zero;
        final refunds = recordRefunds();
        await service.refundAbandonedDownload();
        expect(refunds, isEmpty);
      });

      test('a lost debit reply whose refund queue cannot be written keeps the entry for recovery', () async {
        final settings = _FlakySettings()..failingKeys.add(_queueKey);
        useSettings(settings);
        final requestIds = <String>[];
        backend.onCall = (name, parameters) {
          requestIds.add(parameters['requestId'] as String);
          return Future<dynamic>.error(FirebaseFunctionsException(code: 'unavailable', message: 'debit reply lost'));
        };

        await expectLater(
          service.spend(CoinSpendAction.wallpaperDownload, pendingDownloadLink: linkA),
          throwsA(isA<StateError>()),
        );

        final txId = 'spend_${app_state.prismUser.id}_${requestIds.first}';
        expect(requestIds, hasLength(2));
        expect(requestIds.toSet(), hasLength(1));
        expect(ledger().map((e) => e['txId']), <Object?>[txId]);

        service.abandonedDownloadAfter = Duration.zero;
        final refunds = recordRefunds();
        await service.refundAbandonedDownload();

        expect(txIds(refunds), <Object?>[txId]);
        expect(ledger(), isEmpty);
      });
    });
  });
}
