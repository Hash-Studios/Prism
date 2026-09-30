import 'package:Prism/core/constants/app_constants.dart' as app_constants;
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/firestore/firestore_client.dart';
import 'package:Prism/core/firestore/firestore_query_specs.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'in_memory_local_store.dart';

class CoinsTestBackend {
  Future<dynamic> Function(String name, Map<String, dynamic> parameters) onCall = (_, _) async => claimPayload;

  static const Map<String, Object> claimPayload = <String, Object>{
    'claimed': true,
    'alreadyClaimedToday': false,
    'streakDay': 3,
    'streakCount': 3,
    'dailyReward': 8,
    'totalReward': 8,
    'newBalance': 108,
    'todayLocalKey': '2026-09-30',
  };

  Future<void> install() async {
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockDecodedMessageHandler<Object?>(
      const BasicMessageChannel<Object?>(
        'dev.flutter.pigeon.firebase_core_platform_interface.FirebaseCoreHostApi.initializeCore',
        _FirebaseCoreTestCodec(),
      ),
      (_) async => <Object?>[
        <Object?>[
          (
            130,
            <Object?>[
              '[DEFAULT]',
              (
                129,
                <Object?>[
                  'test-api-key',
                  'test-app-id',
                  'test-sender',
                  'test-project',
                  ...List<Object?>.filled(10, null),
                ],
              ),
              true,
              <String, Object?>{},
            ],
          ),
        ],
      ],
    );
    messenger.setMockDecodedMessageHandler<Object?>(
      const BasicMessageChannel<Object?>(
        'dev.flutter.pigeon.cloud_functions_platform_interface.CloudFunctionsHostApi.call',
        StandardMessageCodec(),
      ),
      (message) async {
        final arguments = Map<String, dynamic>.from((message! as List<Object?>).first! as Map<Object?, Object?>);
        try {
          return <Object?>[
            await onCall(
              arguments['functionName'] as String,
              Map<String, dynamic>.from(arguments['parameters'] as Map<Object?, Object?>),
            ),
          ];
        } on FirebaseFunctionsException catch (error) {
          return <Object?>[
            error.code,
            error.message,
            <String, Object?>{'code': error.code, 'message': error.message, 'additionalData': error.details},
          ];
        }
      },
    );
    await Firebase.initializeApp();
    if (!getIt.isRegistered<SettingsLocalDataSource>()) {
      getIt.registerSingleton<SettingsLocalDataSource>(SettingsLocalDataSource(InMemoryLocalStore()));
    }
    app_state.prismUser = app_constants.createGuestPrismUser()
      ..id = 'user-1'
      ..loggedIn = true
      ..coins = 100;
  }
}

class _FirebaseCoreTestCodec extends StandardMessageCodec {
  const _FirebaseCoreTestCodec();

  // Firebase core's native Pigeon response uses tags 129 (options) and 130 (app).
  @override
  void writeValue(WriteBuffer buffer, Object? value) {
    if (value case (final int tag, final List<Object?> fields)) {
      buffer.putUint8(tag);
      super.writeValue(buffer, fields);
    } else {
      super.writeValue(buffer, value);
    }
  }
}

class CoinsTestFirestore extends Fake implements FirestoreClient {
  Map<String, dynamic> userData = <String, dynamic>{};
  Future<Map<String, dynamic>>? userResponse;
  List<Map<String, dynamic>> transactions = <Map<String, dynamic>>[];
  int queries = 0;
  int? dedupeWindowMs;

  @override
  Future<T?> getById<T>(
    String collection,
    String id,
    T Function(Map<String, dynamic>, String) map, {
    required String sourceTag,
    bool preferCacheFirst = false,
  }) async => map(userResponse == null ? userData : await userResponse!, id);

  @override
  Future<List<T>> query<T>(FirestoreQuerySpec spec, T Function(Map<String, dynamic>, String) map) async {
    queries++;
    dedupeWindowMs = spec.dedupeWindowMs;
    return transactions.map((row) => map(row, row['id'] as String)).toList();
  }
}
