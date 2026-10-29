import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/firestore/firestore_client.dart';
import 'package:Prism/core/firestore/firestore_query_specs.dart';
import 'package:Prism/core/offline/durable_json_store.dart';
import 'package:Prism/features/ai_wallpaper/data/repositories/ai_generation_repository_impl.dart';
import 'package:Prism/features/ai_wallpaper/domain/entities/ai_charge_mode.dart';
import 'package:Prism/features/ai_wallpaper/domain/entities/ai_generation_record.dart';
import 'package:Prism/features/ai_wallpaper/domain/entities/ai_quality_tier.dart';
import 'package:Prism/features/ai_wallpaper/domain/entities/ai_style_preset.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../../../support/fake_firestore_client.dart';

class _FakeUser extends Fake implements User {
  @override
  String get uid => 'user-1';

  @override
  Future<String> getIdToken([bool forceRefresh = false]) async => 'token';
}

class _FakeAuth extends Fake implements FirebaseAuth {
  @override
  User? get currentUser => _FakeUser();
}

class _GatedDurableJsonStore extends Fake implements DurableJsonStore {
  final Map<String, Map<String, Object?>> records = <String, Map<String, Object?>>{};
  final Completer<void> writeStarted = Completer<void>();
  final Completer<void> writeGate = Completer<void>();

  @override
  Future<Map<String, Object?>?> read(String key) async => records[key];

  @override
  Future<Map<String, Map<String, Object?>>> readAll() async => <String, Map<String, Object?>>{
    for (final MapEntry<String, Map<String, Object?>> entry in records.entries)
      entry.key: Map<String, Object?>.from(entry.value),
  };

  @override
  Future<void> write(String key, Map<String, Object?> value) async {
    if (!writeStarted.isCompleted) {
      writeStarted.complete();
      await writeGate.future;
    }
    records[key] = Map<String, Object?>.from(value);
  }

  @override
  Future<void> delete(String key) async {
    records.remove(key);
  }

  @override
  Future<void> clear() async => records.clear();
}

class _GatedFirestoreClient extends FakeFirestoreClient {
  final Completer<void> queryStarted = Completer<void>();
  final Completer<void> queryGate = Completer<void>();

  @override
  Future<List<T>> query<T>(FirestoreQuerySpec spec, T Function(Map<String, dynamic> data, String docId) map) async {
    if (!queryStarted.isCompleted) queryStarted.complete();
    await queryGate.future;
    return super.query(spec, map);
  }
}

class _StalledHistoryWriteFirestoreClient extends FakeFirestoreClient {
  final Completer<void> writeStarted = Completer<void>();
  final Completer<void> writeGate = Completer<void>();

  @override
  Future<void> setDoc(
    String collection,
    String id,
    Map<String, dynamic> data, {
    bool merge = false,
    required String sourceTag,
  }) async {
    writeStarted.complete();
    await writeGate.future;
    await super.setDoc(collection, id, data, merge: merge, sourceTag: sourceTag);
  }
}

class _FailingHistorySaveFirestoreClient extends FakeFirestoreClient {
  @override
  Future<void> setDoc(
    String collection,
    String id,
    Map<String, dynamic> data, {
    bool merge = false,
    required String sourceTag,
  }) async {
    throw StateError('remote history save failed');
  }
}

final String _okBody = jsonEncode(<String, Object>{
  'generationId': 'gen-1',
  'imageUrls': <String, String>{'imageUrl': 'https://cdn/full.png', 'watermarkedImageUrl': 'https://cdn/wm.png'},
});

AiGenerationRepositoryImpl _repository(http.Client client) => AiGenerationRepositoryImpl.forTest(
  client: client,
  auth: _FakeAuth(),
  requestTimeout: const Duration(milliseconds: 20),
);

Future<void> _generate(AiGenerationRepositoryImpl repository, {String? chargeTxId}) => repository.generate(
  prompt: 'misty peaks',
  stylePreset: AiStylePreset.nature,
  qualityTier: AiQualityTier.fast,
  targetSize: '1080x1920',
  chargeMode: AiChargeMode.coinSpend,
  coinsSpent: 10,
  chargeTxId: chargeTxId,
);

void main() {
  setUp(() => getIt.registerSingleton<FirestoreClient>(FakeFirestoreClient()));
  tearDown(getIt.reset);

  test('repository construction does not access Firebase Auth before an online operation', () {
    expect(() => AiGenerationRepositoryImpl(), returnsNormally);
  });

  for (final variation in <bool>[false, true]) {
    for (final field in <String>['generationId', 'imageUrl', 'watermarkedImageUrl']) {
      test('rejects wrong-type $field for variation=$variation', () async {
        final data = jsonDecode(_okBody) as Map<String, dynamic>;
        if (field == 'generationId') {
          data[field] = 7;
        } else {
          (data['imageUrls'] as Map<String, dynamic>)[field] = <String, bool>{'bad': true};
        }
        final repository = _repository(MockClient((_) async => http.Response(jsonEncode(data), 200)));
        await expectLater(
          variation
              ? repository.generateVariation(generationId: 'gen-0', chargeMode: AiChargeMode.coinSpend, coinsSpent: 10)
              : _generate(repository),
          throwsA(
            isA<AiGenerationApiException>()
                .having((e) => e.code, 'code', 'provider_error')
                .having((e) => e.statusCode, 'status', 502),
          ),
        );
      });
    }
  }

  for (final explicitNull in <bool>[false, true]) {
    test('optional watermark falls back to the image URL (null=$explicitNull)', () async {
      final repository = _repository(
        MockClient(
          (_) async => http.Response(
            jsonEncode(<String, Object>{
              'generationId': 'gen-1',
              'imageUrls': <String, Object?>{
                'imageUrl': 'https://cdn/full.png',
                if (explicitNull) 'watermarkedImageUrl': null,
              },
            }),
            200,
          ),
        ),
      );
      final record = await repository.generateVariation(
        generationId: 'gen-0',
        chargeMode: AiChargeMode.coinSpend,
        coinsSpent: 10,
      );
      expect(record.imageUrl, 'https://cdn/full.png');
      expect(record.watermarkedImageUrl, 'https://cdn/full.png');
    });
  }

  test('generate sends the charge transaction id', () async {
    final List<Map<String, dynamic>> bodies = <Map<String, dynamic>>[];
    final repository = _repository(
      MockClient((request) async {
        bodies.add(jsonDecode(request.body) as Map<String, dynamic>);
        return http.Response(_okBody, 200);
      }),
    );

    await _generate(repository, chargeTxId: 'spend_user-1_abc');

    expect(bodies.single['chargeTxId'], 'spend_user-1_abc');
  });

  test('all styles keep their worker values through generation and local and remote history', () async {
    const Map<AiStylePreset, String> workerValues = <AiStylePreset, String>{
      AiStylePreset.anime: 'anime',
      AiStylePreset.minimal: 'minimal',
      AiStylePreset.cyberpunk: 'cyberpunk',
      AiStylePreset.watercolor: 'watercolor',
      AiStylePreset.meshGradient: 'mesh gradient',
      AiStylePreset.abstract: 'abstract',
      AiStylePreset.nature: 'nature',
      AiStylePreset.space: 'space art',
      AiStylePreset.synthwave: 'synthwave',
      AiStylePreset.pixelArt: 'pixel art',
      AiStylePreset.render3d: '3d render',
      AiStylePreset.oilPainting: 'oil painting',
      AiStylePreset.ukiyoE: 'ukiyo-e',
    };
    final Directory directory = await Directory.systemTemp.createTemp('prism-ai-style-history-test');
    addTearDown(() => directory.delete(recursive: true));
    final List<String> requestedStyles = <String>[];
    final client = MockClient((request) async {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      final String style = body['stylePreset'] as String;
      requestedStyles.add(style);
      final response = jsonDecode(_okBody) as Map<String, dynamic>;
      response['generationId'] = style;
      return http.Response(jsonEncode(response), 200);
    });
    final repository = AiGenerationRepositoryImpl.forTest(
      client: client,
      auth: _FakeAuth(),
      localStore: DurableJsonStore('ai_style_test', directory: directory),
    );
    for (final entry in workerValues.entries) {
      final record = await repository.generate(
        prompt: 'a quiet scene',
        stylePreset: entry.key,
        qualityTier: AiQualityTier.fast,
        targetSize: '1080x1920',
        chargeMode: AiChargeMode.coinSpend,
        coinsSpent: 10,
      );
      expect(record.stylePreset, entry.key);
    }
    expect(requestedStyles, workerValues.values.toList());
    final expectedStyles = <String, AiStylePreset>{for (final entry in workerValues.entries) entry.value: entry.key};
    final afterRestart = AiGenerationRepositoryImpl.forTest(
      client: client,
      auth: _FakeAuth(),
      localStore: DurableJsonStore('ai_style_test', directory: directory),
    );
    final localHistory = await afterRestart.fetchLocalHistory(userId: 'user-1');
    expect(<String, AiStylePreset>{for (final record in localHistory) record.id: record.stylePreset}, expectedStyles);

    final firestore = getIt<FirestoreClient>() as FakeFirestoreClient;
    firestore.onQuery = (_) => <FakeDocRow>[for (final write in firestore.writes) (id: write.id, data: write.data!)];
    final remoteReader = AiGenerationRepositoryImpl.forTest(
      client: client,
      auth: _FakeAuth(),
      localStore: DurableJsonStore('ai_remote_style_test', directory: Directory('${directory.path}/remote')),
    );
    expect(await remoteReader.fetchLocalHistory(userId: 'user-1'), isEmpty);
    final remoteHistory = await remoteReader.fetchHistory(userId: 'user-1');
    expect(<String, AiStylePreset>{for (final record in remoteHistory) record.id: record.stylePreset}, expectedStyles);
  });

  test('generate leaves chargeTxId out when there is no charge', () async {
    final List<Map<String, dynamic>> bodies = <Map<String, dynamic>>[];
    final repository = _repository(
      MockClient((request) async {
        bodies.add(jsonDecode(request.body) as Map<String, dynamic>);
        return http.Response(_okBody, 200);
      }),
    );

    await _generate(repository);

    expect(bodies.single.containsKey('chargeTxId'), isFalse);
  });

  test('a free trial generation asks the worker for the free trial and sends no charge id', () async {
    final List<Map<String, dynamic>> bodies = <Map<String, dynamic>>[];
    final repository = _repository(
      MockClient((request) async {
        bodies.add(jsonDecode(request.body) as Map<String, dynamic>);
        return http.Response(_okBody, 200);
      }),
    );

    await repository.generate(
      prompt: 'misty peaks',
      stylePreset: AiStylePreset.nature,
      qualityTier: AiQualityTier.fast,
      targetSize: '1080x1920',
      chargeMode: AiChargeMode.freeTrial,
      coinsSpent: 0,
    );
    await _generate(repository);

    expect(bodies.first['freeTrial'], isTrue);
    expect(bodies.first.containsKey('chargeTxId'), isFalse);
    expect(bodies.last.containsKey('freeTrial'), isFalse);
  });

  test('a timeout is retried once with the same charge id', () async {
    final List<Map<String, dynamic>> bodies = <Map<String, dynamic>>[];
    final repository = _repository(
      MockClient((request) {
        bodies.add(jsonDecode(request.body) as Map<String, dynamic>);
        if (bodies.length == 1) return Completer<http.Response>().future;
        return Future<http.Response>.value(http.Response(_okBody, 200));
      }),
    );

    await _generate(repository, chargeTxId: 'spend_user-1_abc');

    expect(bodies, hasLength(2));
    expect(bodies[1]['chargeTxId'], 'spend_user-1_abc');
    expect(bodies[1], bodies[0]);
  });

  test('a second timeout surfaces the error', () async {
    int calls = 0;
    final repository = _repository(
      MockClient((request) {
        calls++;
        return Completer<http.Response>().future;
      }),
    );

    await expectLater(_generate(repository, chargeTxId: 'spend_user-1_abc'), throwsA(isA<TimeoutException>()));
    expect(calls, 2);
  });

  test('a timeout without a charge id is not retried', () async {
    int calls = 0;
    final repository = _repository(
      MockClient((request) {
        calls++;
        return Completer<http.Response>().future;
      }),
    );

    await expectLater(_generate(repository), throwsA(isA<TimeoutException>()));
    expect(calls, 1);
  });

  test('an API error keeps the worker code and is not retried', () async {
    int calls = 0;
    final repository = _repository(
      MockClient((request) async {
        calls++;
        return http.Response(jsonEncode(<String, String>{'error': 'charge_in_progress', 'message': 'x'}), 409);
      }),
    );

    await expectLater(
      _generate(repository, chargeTxId: 'spend_user-1_abc'),
      throwsA(isA<AiGenerationApiException>().having((e) => e.code, 'code', 'charge_in_progress')),
    );
    expect(calls, 1);
  });

  test('generateVariation sends the charge transaction id', () async {
    final List<Map<String, dynamic>> bodies = <Map<String, dynamic>>[];
    final repository = _repository(
      MockClient((request) async {
        bodies.add(jsonDecode(request.body) as Map<String, dynamic>);
        return http.Response(_okBody, 200);
      }),
    );

    await repository.generateVariation(
      generationId: 'gen-0',
      chargeMode: AiChargeMode.coinSpend,
      coinsSpent: 10,
      variationPrompt: 'warmer',
      chargeTxId: 'spend_user-1_abc',
    );

    expect(bodies.single['chargeTxId'], 'spend_user-1_abc');
    expect(bodies.single['variationPrompt'], 'warmer');
  });

  test('AI prompt and history are durable and isolated by owner when the remote history is unavailable', () async {
    final Directory directory = await Directory.systemTemp.createTemp('prism-ai-offline-test');
    addTearDown(() => directory.delete(recursive: true));
    final DurableJsonStore localStore = DurableJsonStore('ai_test', directory: directory);
    final repository = AiGenerationRepositoryImpl.forTest(
      client: MockClient((_) async => http.Response(_okBody, 200)),
      auth: _FakeAuth(),
      localStore: localStore,
    );
    final AiGenerationRecord record = AiGenerationRecord(
      id: 'gen-a',
      userId: 'user-1',
      createdAt: DateTime.utc(2026, 10, 17),
      prompt: 'quiet mountain lake',
      stylePreset: AiStylePreset.nature,
      qualityTier: AiQualityTier.fast,
      provider: 'test',
      model: 'test',
      seed: 3,
      width: 720,
      height: 1280,
      imageUrl: 'https://cdn.example/full.png',
      watermarkedImageUrl: 'https://cdn.example/watermarked.png',
      chargeMode: AiChargeMode.freeTrial,
      coinsSpent: 0,
      status: 'success',
    );
    await repository.savePrompt(userId: 'user-1', prompt: 'a saved prompt');
    await repository.savePrompt(userId: 'user-2', prompt: 'another account');
    await repository.saveHistoryRecord(record);
    final FakeFirestoreClient firestore = getIt<FirestoreClient>() as FakeFirestoreClient;
    firestore.queryError = StateError('offline');

    final AiGenerationRepositoryImpl afterRestart = AiGenerationRepositoryImpl.forTest(
      client: MockClient((_) async => http.Response(_okBody, 200)),
      auth: _FakeAuth(),
      localStore: DurableJsonStore('ai_test', directory: directory),
    );
    expect(await afterRestart.loadPrompt(userId: 'user-1'), 'a saved prompt');
    expect(await afterRestart.loadPrompt(userId: 'user-2'), 'another account');
    expect((await afterRestart.fetchHistory(userId: 'user-1')).map((item) => item.id), <String>['gen-a']);
    expect(await afterRestart.fetchLocalHistory(userId: 'user-2'), isEmpty);

    await afterRestart.clearForUser('user-1');
    expect(await afterRestart.loadPrompt(userId: 'user-1'), isNull);
    expect(await afterRestart.fetchLocalHistory(userId: 'user-1'), isEmpty);
    expect(await afterRestart.loadPrompt(userId: 'user-2'), 'another account');
  });

  test(
    'successful remote history keeps pending local records but drops synced records outside the remote window',
    () async {
      final Directory directory = await Directory.systemTemp.createTemp('prism-ai-history-window-test');
      addTearDown(() => directory.delete(recursive: true));
      final AiGenerationRecord pending = AiGenerationRecord(
        id: 'gen-pending',
        userId: 'user-1',
        createdAt: DateTime.utc(2026, 10, 17),
        prompt: 'saved while offline',
        stylePreset: AiStylePreset.nature,
        qualityTier: AiQualityTier.fast,
        provider: 'test',
        model: 'test',
        seed: 8,
        width: 720,
        height: 1280,
        imageUrl: 'https://cdn.example/pending.png',
        watermarkedImageUrl: 'https://cdn.example/pending-watermarked.png',
        chargeMode: AiChargeMode.freeTrial,
        coinsSpent: 0,
        status: 'success',
      );
      final AiGenerationRecord deletedRemotely = AiGenerationRecord(
        id: 'gen-deleted',
        userId: 'user-1',
        createdAt: DateTime.utc(2026, 10, 16),
        prompt: 'removed from server',
        stylePreset: AiStylePreset.nature,
        qualityTier: AiQualityTier.fast,
        provider: 'test',
        model: 'test',
        seed: 9,
        width: 720,
        height: 1280,
        imageUrl: 'https://cdn.example/deleted.png',
        watermarkedImageUrl: 'https://cdn.example/deleted-watermarked.png',
        chargeMode: AiChargeMode.freeTrial,
        coinsSpent: 0,
        status: 'success',
      );
      final DurableJsonStore localStore = DurableJsonStore('ai_history_window_test', directory: directory);
      await localStore.write('history/user-1/gen-pending', <String, Object?>{
        ...pending.toJson(),
        'createdAt': pending.createdAt.toIso8601String(),
        '_syncState': 'pending',
      });
      await localStore.write('history/user-1/gen-deleted', <String, Object?>{
        ...deletedRemotely.toJson(),
        'createdAt': deletedRemotely.createdAt.toIso8601String(),
        '_syncState': 'synced',
      });
      final AiGenerationRecord remote = AiGenerationRecord(
        id: 'gen-remote',
        userId: 'user-1',
        createdAt: DateTime.utc(2026, 10, 15),
        prompt: 'current server record',
        stylePreset: AiStylePreset.nature,
        qualityTier: AiQualityTier.fast,
        provider: 'test',
        model: 'test',
        seed: 12,
        width: 720,
        height: 1280,
        imageUrl: 'https://cdn.example/remote.png',
        watermarkedImageUrl: 'https://cdn.example/remote-watermarked.png',
        chargeMode: AiChargeMode.freeTrial,
        coinsSpent: 0,
        status: 'success',
      );
      final FakeFirestoreClient firestore = FakeFirestoreClient()
        ..onQuery = (_) => <FakeDocRow>[(id: remote.id, data: remote.toJson())];
      getIt.unregister<FirestoreClient>();
      getIt.registerSingleton<FirestoreClient>(firestore);
      final AiGenerationRepositoryImpl repository = AiGenerationRepositoryImpl.forTest(
        client: MockClient((_) async => http.Response(_okBody, 200)),
        auth: _FakeAuth(),
        localStore: localStore,
      );

      final List<AiGenerationRecord> result = await repository.fetchHistory(userId: 'user-1');

      expect(result.map((record) => record.id).toSet(), <String>{'gen-pending', 'gen-remote'});
    },
  );

  test('successful local and remote save marks history as synced', () async {
    final Directory directory = await Directory.systemTemp.createTemp('prism-ai-history-sync-test');
    addTearDown(() => directory.delete(recursive: true));
    final DurableJsonStore localStore = DurableJsonStore('ai_history_sync_test', directory: directory);
    final AiGenerationRepositoryImpl repository = AiGenerationRepositoryImpl.forTest(
      client: MockClient((_) async => http.Response(_okBody, 200)),
      auth: _FakeAuth(),
      localStore: localStore,
    );
    final AiGenerationRecord record = AiGenerationRecord(
      id: 'gen-synced',
      userId: 'user-1',
      createdAt: DateTime.utc(2026, 10, 17),
      prompt: 'saved online',
      stylePreset: AiStylePreset.nature,
      qualityTier: AiQualityTier.fast,
      provider: 'test',
      model: 'test',
      seed: 10,
      width: 720,
      height: 1280,
      imageUrl: 'https://cdn.example/synced.png',
      watermarkedImageUrl: 'https://cdn.example/synced-watermarked.png',
      chargeMode: AiChargeMode.freeTrial,
      coinsSpent: 0,
      status: 'success',
    );

    await repository.saveHistoryRecord(record);

    expect((await localStore.read('history/user-1/gen-synced'))?['_syncState'], 'synced');
  });

  test('failed remote history save remains pending and appears beside a successful remote window', () async {
    final Directory directory = await Directory.systemTemp.createTemp('prism-ai-pending-history-test');
    addTearDown(() => directory.delete(recursive: true));
    final DurableJsonStore localStore = DurableJsonStore('ai_pending_history_test', directory: directory);
    final _FailingHistorySaveFirestoreClient firestore = _FailingHistorySaveFirestoreClient();
    getIt.unregister<FirestoreClient>();
    getIt.registerSingleton<FirestoreClient>(firestore);
    final AiGenerationRepositoryImpl repository = AiGenerationRepositoryImpl.forTest(
      client: MockClient((_) async => http.Response(_okBody, 200)),
      auth: _FakeAuth(),
      localStore: localStore,
    );
    final AiGenerationRecord record = AiGenerationRecord(
      id: 'gen-pending-after-error',
      userId: 'user-1',
      createdAt: DateTime.utc(2026, 10, 17),
      prompt: 'saved locally first',
      stylePreset: AiStylePreset.nature,
      qualityTier: AiQualityTier.fast,
      provider: 'test',
      model: 'test',
      seed: 11,
      width: 720,
      height: 1280,
      imageUrl: 'https://cdn.example/pending-error.png',
      watermarkedImageUrl: 'https://cdn.example/pending-error-watermarked.png',
      chargeMode: AiChargeMode.freeTrial,
      coinsSpent: 0,
      status: 'success',
    );

    await expectLater(repository.saveHistoryRecord(record), throwsStateError);
    expect((await localStore.read('history/user-1/gen-pending-after-error'))?['_syncState'], 'pending');
    expect((await repository.fetchHistory(userId: 'user-1')).map((item) => item.id).toList(), <String>[
      'gen-pending-after-error',
    ]);
  });

  test('clearing an owner serializes after and removes an in-flight history write', () async {
    final _GatedDurableJsonStore localStore = _GatedDurableJsonStore();
    final AiGenerationRepositoryImpl repository = AiGenerationRepositoryImpl.forTest(
      client: MockClient((_) async => http.Response(_okBody, 200)),
      auth: _FakeAuth(),
      localStore: localStore,
    );
    final AiGenerationRecord record = AiGenerationRecord(
      id: 'gen-late',
      userId: 'user-1',
      createdAt: DateTime.utc(2026, 10, 17),
      prompt: 'late record',
      stylePreset: AiStylePreset.nature,
      qualityTier: AiQualityTier.fast,
      provider: 'test',
      model: 'test',
      seed: 4,
      width: 720,
      height: 1280,
      imageUrl: 'https://cdn.example/late.png',
      watermarkedImageUrl: 'https://cdn.example/late-watermarked.png',
      chargeMode: AiChargeMode.freeTrial,
      coinsSpent: 0,
      status: 'success',
    );
    final Future<void> write = repository.saveHistoryRecord(record);
    await localStore.writeStarted.future;
    final Future<void> clear = repository.clearForUser('user-1');
    await Future<void>.delayed(const Duration(milliseconds: 10));
    localStore.writeGate.complete();
    await Future.wait(<Future<void>>[write, clear]);

    expect(await repository.fetchLocalHistory(userId: 'user-1'), isEmpty);
  });

  test('clearing an owner prevents a late remote history fetch from restoring local history', () async {
    final Directory directory = await Directory.systemTemp.createTemp('prism-ai-late-history-test');
    addTearDown(() => directory.delete(recursive: true));
    final AiGenerationRecord record = AiGenerationRecord(
      id: 'gen-late-fetch',
      userId: 'user-1',
      createdAt: DateTime.utc(2026, 10, 17),
      prompt: 'late fetched record',
      stylePreset: AiStylePreset.nature,
      qualityTier: AiQualityTier.fast,
      provider: 'test',
      model: 'test',
      seed: 5,
      width: 720,
      height: 1280,
      imageUrl: 'https://cdn.example/fetched.png',
      watermarkedImageUrl: 'https://cdn.example/fetched-watermarked.png',
      chargeMode: AiChargeMode.freeTrial,
      coinsSpent: 0,
      status: 'success',
    );
    final _GatedFirestoreClient firestore = _GatedFirestoreClient()
      ..onQuery = (_) => <FakeDocRow>[(id: record.id, data: record.toJson())];
    getIt.unregister<FirestoreClient>();
    getIt.registerSingleton<FirestoreClient>(firestore);
    final AiGenerationRepositoryImpl repository = AiGenerationRepositoryImpl.forTest(
      client: MockClient((_) async => http.Response(_okBody, 200)),
      auth: _FakeAuth(),
      localStore: DurableJsonStore('ai_late_history_test', directory: directory),
    );

    final Future<List<AiGenerationRecord>> fetch = repository.fetchHistory(userId: 'user-1');
    await firestore.queryStarted.future;
    await repository.clearForUser('user-1');
    firestore.queryGate.complete();
    await fetch;

    expect(await repository.fetchLocalHistory(userId: 'user-1'), isEmpty);
  });

  test('a linked generation stores remixOf on its first local and remote history write', () async {
    final Directory directory = await Directory.systemTemp.createTemp('prism-ai-remix-history-test');
    addTearDown(() => directory.delete(recursive: true));
    final FakeFirestoreClient firestore = getIt<FirestoreClient>() as FakeFirestoreClient;
    final AiGenerationRepositoryImpl repository = AiGenerationRepositoryImpl.forTest(
      client: MockClient((_) async => http.Response(_okBody, 200)),
      auth: _FakeAuth(),
      localStore: DurableJsonStore('ai_remix_history_test', directory: directory),
    );

    final AiGenerationRecord generated = await repository.generate(
      prompt: 'misty peaks',
      stylePreset: AiStylePreset.nature,
      qualityTier: AiQualityTier.fast,
      targetSize: '1080x1920',
      chargeMode: AiChargeMode.coinSpend,
      coinsSpent: 10,
      remixOf: 'orig_1',
    );
    final List<AiGenerationRecord> local = await repository.fetchLocalHistory(userId: 'user-1');

    expect(generated.remixOf, 'orig_1');
    expect(local.single.remixOf, 'orig_1');
    expect(firestore.docs['aiGenerations']?['gen-1']?['remixOf'], 'orig_1');
  });

  test('a variation made while linked stores remixOf in history', () async {
    final Directory directory = await Directory.systemTemp.createTemp('prism-ai-remix-variation-test');
    addTearDown(() => directory.delete(recursive: true));
    final FakeFirestoreClient firestore = getIt<FirestoreClient>() as FakeFirestoreClient;
    final AiGenerationRepositoryImpl repository = AiGenerationRepositoryImpl.forTest(
      client: MockClient((_) async => http.Response(_okBody, 200)),
      auth: _FakeAuth(),
      localStore: DurableJsonStore('ai_remix_variation_test', directory: directory),
    );

    final AiGenerationRecord generated = await repository.generateVariation(
      generationId: 'gen-0',
      chargeMode: AiChargeMode.coinSpend,
      coinsSpent: 10,
      remixOf: 'orig_1',
    );

    expect(generated.remixOf, 'orig_1');
    expect((await repository.fetchLocalHistory(userId: 'user-1')).single.remixOf, 'orig_1');
    expect(firestore.docs['aiGenerations']?['gen-1']?['remixOf'], 'orig_1');
  });

  test('clearing an owner prevents a late linked generation response from restoring history', () async {
    final Directory directory = await Directory.systemTemp.createTemp('prism-ai-late-generation-test');
    addTearDown(() => directory.delete(recursive: true));
    final FakeFirestoreClient firestore = getIt<FirestoreClient>() as FakeFirestoreClient;
    final Completer<void> requestStarted = Completer<void>();
    final Completer<http.Response> responseGate = Completer<http.Response>();
    final AiGenerationRepositoryImpl repository = AiGenerationRepositoryImpl.forTest(
      client: MockClient((_) {
        requestStarted.complete();
        return responseGate.future;
      }),
      auth: _FakeAuth(),
      localStore: DurableJsonStore('ai_late_generation_test', directory: directory),
    );

    final Future<AiGenerationRecord> generation = repository.generate(
      prompt: 'misty peaks',
      stylePreset: AiStylePreset.nature,
      qualityTier: AiQualityTier.fast,
      targetSize: '1080x1920',
      chargeMode: AiChargeMode.coinSpend,
      coinsSpent: 10,
      remixOf: 'orig_1',
    );
    await requestStarted.future;
    await repository.clearForUser('user-1');
    responseGate.complete(http.Response(_okBody, 200));
    final AiGenerationRecord generated = await generation;

    expect(generated.remixOf, 'orig_1');
    expect(await repository.fetchLocalHistory(userId: 'user-1'), isEmpty);
    expect(firestore.writes, isEmpty);
  });

  test('a stalled remote history write does not block local prompt saves or clear', () async {
    final Directory directory = await Directory.systemTemp.createTemp('prism-ai-stalled-history-test');
    addTearDown(() => directory.delete(recursive: true));
    final _StalledHistoryWriteFirestoreClient firestore = _StalledHistoryWriteFirestoreClient();
    getIt.unregister<FirestoreClient>();
    getIt.registerSingleton<FirestoreClient>(firestore);
    final AiGenerationRepositoryImpl repository = AiGenerationRepositoryImpl.forTest(
      client: MockClient((_) async => http.Response(_okBody, 200)),
      auth: _FakeAuth(),
      localStore: DurableJsonStore('ai_stalled_history_test', directory: directory),
      requestTimeout: const Duration(seconds: 10),
    );
    final AiGenerationRecord record = AiGenerationRecord(
      id: 'gen-stalled',
      userId: 'user-1',
      createdAt: DateTime.utc(2026, 10, 17),
      prompt: 'remote history stalled',
      stylePreset: AiStylePreset.nature,
      qualityTier: AiQualityTier.fast,
      provider: 'test',
      model: 'test',
      seed: 6,
      width: 720,
      height: 1280,
      imageUrl: 'https://cdn.example/stalled.png',
      watermarkedImageUrl: 'https://cdn.example/stalled-watermarked.png',
      chargeMode: AiChargeMode.freeTrial,
      coinsSpent: 0,
      status: 'success',
    );

    bool historyWriteCompleted = false;
    final Future<void> historyWrite = repository.saveHistoryRecord(record).whenComplete(() {
      historyWriteCompleted = true;
    });
    await firestore.writeStarted.future;
    await repository.savePrompt(userId: 'user-1', prompt: 'still locally writable');
    expect(await repository.loadPrompt(userId: 'user-1'), 'still locally writable');
    await repository.clearForUser('user-1');
    expect(await repository.loadPrompt(userId: 'user-1'), isNull);
    expect(await repository.fetchLocalHistory(userId: 'user-1'), isEmpty);
    expect(historyWriteCompleted, isFalse);
    firestore.writeGate.complete();
    await historyWrite;
    expect(await repository.fetchLocalHistory(userId: 'user-1'), isEmpty);
  });
}
