import 'dart:async';

import 'package:Prism/core/coins/economy_config.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/firestore/firestore_client.dart';
import 'package:Prism/core/startup/firebase_init.dart';
import 'package:Prism/features/startup/data/repositories/startup_repository_impl.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_firestore_client.dart';

class _HangingFirestore extends FakeFirestoreClient {
  int reads = 0;

  @override
  Future<T?> getById<T>(
    String collection,
    String id,
    T Function(Map<String, dynamic> data, String docId) map, {
    required String sourceTag,
    bool preferCacheFirst = false,
  }) {
    reads++;
    return Completer<T?>().future;
  }
}

void main() {
  late _HangingFirestore firestore;

  setUp(() async {
    await getIt.reset();
    firestore = _HangingFirestore();
    getIt.registerSingleton<FirestoreClient>(firestore);
    EconomyConfig.resetForTest();
  });

  tearDown(() async {
    await getIt.reset();
    EconomyConfig.resetForTest();
  });

  test('bootstrap returns without waiting for the economy config read', () async {
    FirebaseInit.setFuture(Future<bool>.value(true));

    final result = await StartupRepositoryImpl().bootstrap().timeout(const Duration(seconds: 1));

    expect(result.isSuccess, isTrue);
    expect(firestore.reads, 1);
  });
}
