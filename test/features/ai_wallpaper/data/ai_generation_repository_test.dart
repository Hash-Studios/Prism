import 'dart:async';
import 'dart:convert';

import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/firestore/firestore_client.dart';
import 'package:Prism/features/ai_wallpaper/data/repositories/ai_generation_repository_impl.dart';
import 'package:Prism/features/ai_wallpaper/domain/entities/ai_charge_mode.dart';
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
}
