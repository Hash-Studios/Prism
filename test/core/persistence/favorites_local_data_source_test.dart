import 'dart:async';
import 'dart:io';

import 'package:Prism/core/offline/durable_json_store.dart';
import 'package:Prism/core/persistence/data_sources/favorites_local_data_source.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/in_memory_local_store.dart';

void main() {
  late Directory directory;
  late FavoritesLocalDataSource source;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('prism-favorites-lock-test-');
    source = FavoritesLocalDataSource(
      InMemoryLocalStore(),
      durableStore: DurableJsonStore('favorites-lock-test', directory: directory),
    );
  });

  tearDown(() async {
    await directory.delete(recursive: true);
  });

  test('a stalled send does not block local reads or newer intent writes', () async {
    const String owner = 'favorites-lock-owner';
    final Map<String, Object?> oldOperation = await source.createFavouriteOperation(
      owner,
      'wall-1',
      desired: true,
      wall: <String, Object?>{'id': 'wall-1'},
    );
    final Completer<void> sendStarted = Completer<void>();
    final Completer<void> releaseSend = Completer<void>();
    final Future<bool> oldSend = source.runFavouriteOperationsIfCurrent(
      owner,
      <String, String>{'wall-1': oldOperation['operationId']! as String},
      () async {
        sendStarted.complete();
        await releaseSend.future;
      },
    );
    Map<String, Object?>? currentBeforeRelease;
    Map<String, Object?>? newOperation;
    try {
      await sendStarted.future.timeout(const Duration(seconds: 10));
      currentBeforeRelease = await source.readFavouriteOperation(owner, 'wall-1').timeout(const Duration(seconds: 10));
      newOperation = await source
          .createFavouriteOperation(owner, 'wall-1', desired: false, wall: <String, Object?>{'id': 'wall-1'})
          .timeout(const Duration(seconds: 10));
    } finally {
      releaseSend.complete();
      await oldSend;
    }

    expect(currentBeforeRelease?['operationId'], oldOperation['operationId']);
    expect(newOperation['revision'], 2);
    expect(await oldSend, isTrue);
    expect(
      await source.updateFavouriteOperationStatus(
        owner,
        'wall-1',
        oldOperation['operationId']! as String,
        status: 'synced',
      ),
      isFalse,
    );
    expect((await source.readFavouriteOperation(owner, 'wall-1'))?['status'], 'pending');
    expect((await source.readFavouriteOperation(owner, 'wall-1'))?['desired'], false);
  });
}
