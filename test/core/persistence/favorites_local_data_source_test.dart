import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:Prism/core/offline/durable_json_store.dart';
import 'package:Prism/core/persistence/data_sources/favorites_local_data_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/features/favourite_walls/domain/entities/favourite_wall_entity.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../features/favourite_walls/support/fav_fixtures.dart';

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

  test('snapshot encoding runs outside the calling isolate and survives restart', () async {
    final wall = LegacyFavouriteWall(
      id: 'legacy',
      source: WallpaperSource.unknown,
      legacyPayload: <String, Object?>{
        'url': 'https://example.com/legacy.jpg',
        'probe': _BackgroundOnlyJson(Isolate.current.controlPort),
      },
    );
    await source.updateWallSnapshot('owner', (_) => [prismFav('first'), wall, wall, prismFav('')]);

    final restarted = FavoritesLocalDataSource(
      InMemoryLocalStore(),
      durableStore: DurableJsonStore('favorites-lock-test', directory: directory),
    );
    final walls = await restarted.readWallSnapshot('owner');
    expect(walls.map((wall) => wall.id), unorderedEquals(['first', 'legacy']));
    expect(walls.firstWhere((wall) => wall.id == 'legacy').fullUrl, 'https://example.com/legacy.jpg');
  });

  test('concurrent snapshot updates preserve every change and clear waits for writes', () async {
    await Future.wait([
      for (var index = 0; index < 8; index++)
        source.updateWallSnapshot('owner', (current) => [...current, prismFav('wall-$index')]),
    ]);
    expect(
      (await source.readWallSnapshot('owner')).map((wall) => wall.id),
      unorderedEquals([for (var index = 0; index < 8; index++) 'wall-$index']),
    );
    final write = source.updateWallSnapshot('owner', (current) => [...current, prismFav('last')]);
    final clear = source.clearUser('owner');
    await Future.wait([write, clear]);
    expect(await source.readWallSnapshot('owner'), isEmpty);
    expect(await DurableJsonStore('favorites-lock-test', directory: directory).readAll(), isEmpty);
  });

  test('multi-shard snapshots retain unicode, dates and pins, then remove old shards', () async {
    final saved = DateTime.utc(2026, 1, 2);
    final pinned = DateTime.utc(2026, 1, 3);
    final author = '雪' * 90000;
    await source.updateWallSnapshot(
      'owner',
      (_) => [
        prismFav('first', author: author, favouritedAt: saved).withPinnedAt(pinned),
        prismFav('second', author: author, favouritedAt: saved),
      ],
    );
    final store = DurableJsonStore('favorites-lock-test', directory: directory);
    expect((await store.read('owner::snapshot'))?['shardCount'], 2);
    final walls = await source.readWallSnapshot('owner');
    expect(walls, hasLength(2));
    expect(walls.first.authorName, author);
    expect(walls.first.favouritedAt, saved);
    expect(walls.first.pinnedAt, pinned);

    await source.updateWallSnapshot('owner', (_) => []);
    expect(await source.readWallSnapshot('owner'), isEmpty);
    expect((await store.readAll()).keys, ['owner::snapshot']);
  });

  test('failed snapshot keeps the previous generation and permits a later write', () async {
    await source.updateWallSnapshot('owner', (_) => [prismFav('saved')]);
    await expectLater(
      source.updateWallSnapshot(
        'owner',
        (_) => [
          prismFav('partial', author: 'x' * 300000),
          prismFav('too-large', author: 'x' * DurableJsonStore.maxRecordBytes),
        ],
      ),
      throwsA(isA<DurableJsonStoreLimitException>()),
    );
    expect((await source.readWallSnapshot('owner')).single.id, 'saved');
    await source.updateWallSnapshot('owner', (current) => [...current, prismFav('next')]);
    expect((await source.readWallSnapshot('owner')).map((wall) => wall.id), unorderedEquals(['saved', 'next']));
  });

  test('custom snapshot chunker is used when provided', () async {
    var chunkerCalled = false;
    final customSource = FavoritesLocalDataSource(
      InMemoryLocalStore(),
      durableStore: DurableJsonStore('favorites-chunker-test', directory: directory),
      snapshotChunker: (docs) async {
        chunkerCalled = true;
        return [docs];
      },
    );
    await customSource.updateWallSnapshot('owner', (_) => [prismFav('w1')]);
    expect(chunkerCalled, isTrue);
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

class _BackgroundOnlyJson {
  _BackgroundOnlyJson(this.caller);

  final SendPort caller;

  String toJson() {
    if (Isolate.current.controlPort == caller) {
      throw StateError('Snapshot JSON encoded on the calling isolate');
    }
    return 'background';
  }
}
