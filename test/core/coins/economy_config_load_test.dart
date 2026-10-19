import 'package:Prism/core/coins/economy_config.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/firestore/firestore_client.dart';
import 'package:Prism/core/firestore/firestore_query_specs.dart';
import 'package:flutter_test/flutter_test.dart';

class _ConfigFirestore extends Fake implements FirestoreClient {
  int cacheReads = 0;
  int serverReads = 0;
  bool cacheFails = false;
  bool serverFails = false;

  @override
  Future<T?> getById<T>(
    String collection,
    String id,
    T Function(Map<String, dynamic>, String) map, {
    required String sourceTag,
    bool preferCacheFirst = false,
  }) async {
    cacheReads++;
    if (cacheFails) throw StateError('cache unavailable');
    return map(<String, dynamic>{'version': 3}, id);
  }

  @override
  Stream<({List<T> items, bool isFromCache})> watchQueryWithMetadata<T>(
    FirestoreQuerySpec spec,
    T Function(Map<String, dynamic>, String) map,
  ) async* {
    serverReads++;
    if (serverFails) throw StateError('offline');
    yield (items: <T>[map(<String, dynamic>{'version': 4}, 'current')], isFromCache: false);
  }
}

void main() {
  late _ConfigFirestore firestore;

  setUp(() async {
    await getIt.reset();
    EconomyConfig.resetForTest();
    firestore = _ConfigFirestore();
    getIt.registerSingleton<FirestoreClient>(firestore);
  });

  tearDown(() async {
    EconomyConfig.resetForTest();
    await getIt.reset();
  });

  test('config refresh uses a confirmed server read instead of an offline cache fallback', () async {
    await EconomyConfig.load();

    expect(EconomyConfig.current.version, 4);
    expect(firestore.serverReads, 1);
  });

  test('an offline cache does not mark config fresh and prevent a later server refresh', () async {
    firestore.serverFails = true;
    await EconomyConfig.load();
    expect(EconomyConfig.current.version, 3);

    firestore.serverFails = false;
    await EconomyConfig.refreshIfStale();

    expect(EconomyConfig.current.version, 4);
    expect(firestore.serverReads, 2);
  });

  test('a failed cache read still attempts the server refresh', () async {
    firestore.cacheFails = true;

    await EconomyConfig.load();

    expect(EconomyConfig.current.version, 4);
    expect(firestore.serverReads, 1);
  });
}
