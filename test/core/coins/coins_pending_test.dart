import 'dart:convert';

import 'package:Prism/core/coins/coin_action.dart';
import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/coins_test_backend.dart';

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

const String _queueKey = 'pendingAiRefunds';
const String _markerKey = 'pendingDownloadMarker';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final backend = CoinsTestBackend();
  final service = CoinsService.instance;
  final toastMessages = <String>[];

  setUp(() async {
    await backend.install();
    service.balanceNotifier.value = 100;
    service.isLinkDownloaded = (_) => false;
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
    await settings.delete(_markerKey);
    service.pendingRetryInterval = const Duration(seconds: 30);
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

  group('pending download marker', () {
    test('the marker is written before the spend call and kept after a charged spend', () async {
      String? markerDuringCall;
      backend.onCall = (name, parameters) async {
        markerDuringCall = stored(_markerKey);
        return _spent;
      };

      await service.spend(CoinSpendAction.wallpaperDownload, pendingDownloadLink: 'https://x.test/a.jpg');

      final during = jsonDecode(markerDuringCall!) as Map<String, dynamic>;
      expect(during['link'], 'https://x.test/a.jpg');
      expect(during['txId'], startsWith('spend_${app_state.prismUser.id}_'));
      expect(during['at'], isA<int>());
      expect(stored(_markerKey), isNotEmpty);

      await service.clearPendingDownload();
      expect(stored(_markerKey), isEmpty);
    });

    test('a refused spend clears the marker', () async {
      backend.onCall = (name, parameters) async => <String, Object>{
        'success': false,
        'changed': false,
        'insufficientBalance': true,
        'previousBalance': 1,
        'currentBalance': 1,
        'delta': 0,
      };

      await service.spend(CoinSpendAction.wallpaperDownload, pendingDownloadLink: 'https://x.test/a.jpg');

      expect(stored(_markerKey), isEmpty);
    });

    Future<void> writeMarker({required Duration age}) => getIt<SettingsLocalDataSource>().set(
      _markerKey,
      jsonEncode(<String, Object>{
        'userId': app_state.prismUser.id,
        'txId': 'spend_tx_marker',
        'link': 'https://x.test/a.jpg',
        'action': 'wallpaperDownload',
        'at': DateTime.now().subtract(age).millisecondsSinceEpoch,
      }),
    );

    test('a marker older than 2 minutes whose file is missing is refunded', () async {
      await writeMarker(age: const Duration(minutes: 3));
      final refunds = <Map<String, dynamic>>[];
      backend.onCall = (name, parameters) async {
        refunds.add(parameters);
        return _refunded;
      };

      await service.refundAbandonedDownload();

      expect(refunds.single['transactionId'], 'spend_tx_marker');
      expect(refunds.single['reason'], 'download_failed_refund');
      expect(stored(_markerKey), isEmpty);
      expect(toastMessages, contains('Your last download did not finish. Coins returned.'));
    });

    test('a marker whose file is in the index is cleared without a refund', () async {
      await writeMarker(age: const Duration(minutes: 3));
      service.isLinkDownloaded = (link) => link == 'https://x.test/a.jpg';
      var calls = 0;
      backend.onCall = (name, parameters) async {
        calls++;
        return _refunded;
      };

      await service.refundAbandonedDownload();

      expect(calls, 0);
      expect(stored(_markerKey), isEmpty);
    });

    test('a marker younger than 2 minutes is left alone', () async {
      await writeMarker(age: const Duration(seconds: 30));
      var calls = 0;
      backend.onCall = (name, parameters) async {
        calls++;
        return _refunded;
      };

      await service.refundAbandonedDownload();

      expect(calls, 0);
      expect(stored(_markerKey), isNotEmpty);
    });

    test('a marker of another account is left alone', () async {
      await writeMarker(age: const Duration(minutes: 3));
      app_state.prismUser.id = 'someone-else';
      var calls = 0;
      backend.onCall = (name, parameters) async {
        calls++;
        return _refunded;
      };

      await service.refundAbandonedDownload();

      expect(calls, 0);
      expect(stored(_markerKey), isNotEmpty);
    });

    test('a refund the network lost keeps the marker for the next start', () async {
      await writeMarker(age: const Duration(minutes: 3));
      backend.onCall = (name, parameters) async =>
          throw FirebaseFunctionsException(code: 'unavailable', message: 'offline');

      await service.refundAbandonedDownload();

      expect(stored(_markerKey), isNotEmpty);
      expect(toastMessages, isEmpty);
    });
  });
}
