import 'dart:convert';
import 'dart:io';

import 'package:Prism/core/coins/economy_snapshot_store.dart';
import 'package:Prism/core/coins/economy_state.dart';
import 'package:Prism/core/offline/durable_json_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory directory;
  late EconomySnapshotStore snapshots;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('economy-snapshot-test-');
    snapshots = EconomySnapshotStore(store: DurableJsonStore('test', directory: directory));
  });

  tearDown(() async {
    await directory.delete(recursive: true);
  });

  test('restores the same owner from a new store instance and never stores coin authority', () async {
    await snapshots.write('owner-a', 4, <String, dynamic>{
      'quests': <String, Object?>{'dayKey': '2026-10-17'},
      'passes': <String, Object?>{'autoRotatePassUntil': 1_900_000_000_000},
      'coins': 999999,
    });

    final EconomySnapshotStore restarted = EconomySnapshotStore(store: DurableJsonStore('test', directory: directory));
    final EconomySnapshot? restored = await restarted.read('owner-a');

    expect(restored?.revision, 4);
    expect(restored?.data['quests'], <String, dynamic>{'dayKey': '2026-10-17'});
    expect(restored?.data.containsKey('coins'), isFalse);
    expect(await restarted.read('owner-b'), isNull);
  });

  test('newer revisions win and cleanup removes only the selected owner', () async {
    await snapshots.write('owner-a', 5, <String, dynamic>{
      'quests': <String, Object?>{'dayKey': 'new'},
    });
    await snapshots.write('owner-a', 3, <String, dynamic>{
      'quests': <String, Object?>{'dayKey': 'old'},
    });
    await snapshots.write('owner-b', 1, <String, dynamic>{
      'quests': <String, Object?>{'dayKey': 'other'},
    });

    await snapshots.clearForUser('owner-a');

    expect(await snapshots.read('owner-a'), isNull);
    expect((await snapshots.read('owner-b'))?.data['quests'], <String, dynamic>{'dayKey': 'other'});
  });

  test('revision is embedded in restored data and inventory list shape survives restart', () async {
    await snapshots.write('owner-a', 7, <String, dynamic>{
      'inventory': <String, Object?>{
        'owned': <String>['frame-a', 'glow-b'],
      },
    });
    final EconomySnapshot? restored = await EconomySnapshotStore(
      store: DurableJsonStore('test', directory: directory),
    ).read('owner-a');

    expect(restored?.data['rev'], 7);
    expect((restored?.data['inventory'] as Map)['owned'], <String>['frame-a', 'glow-b']);
  });

  test('reads snapshots through the durable store record-size boundary', () async {
    const String ownerId = 'owner-a';
    const int revision = 1;
    Map<String, Object?> envelope(String payload) => <String, Object?>{
      'key': ownerId,
      'value': <String, Object?>{
        'ownerId': ownerId,
        'rev': revision,
        'data': <String, Object?>{
          'quests': <String, Object?>{'payload': payload},
          'rev': revision,
        },
      },
    };
    final int baseBytes = utf8.encode(jsonEncode(envelope(''))).length;
    final String payload = List<String>.filled(DurableJsonStore.maxRecordBytes - baseBytes, 'x').join();

    await snapshots.write(ownerId, revision, <String, dynamic>{
      'quests': <String, Object?>{'payload': payload},
    });

    final EconomySnapshot? restored = await snapshots.read(ownerId);
    expect(restored?.data['quests'], <String, dynamic>{'payload': payload});

    await expectLater(
      snapshots.write('owner-b', revision, <String, dynamic>{
        'quests': <String, Object?>{'payload': '$payload x'},
      }),
      throwsA(isA<DurableJsonStoreLimitException>()),
    );
  });

  test('authoritative snapshots remove fields omitted by the server', () async {
    await snapshots.write('owner-a', 2, <String, dynamic>{
      'drops': <String, Object?>{
        'unlocked': <String, Object?>{'x': 1},
      },
    });
    await snapshots.replace('owner-a', 3, <String, dynamic>{
      'quests': <String, Object?>{'dayKey': 'today'},
    });

    final EconomySnapshot? restored = await snapshots.read('owner-a');
    expect(restored?.data.containsKey('drops'), isFalse);
    expect(restored?.data['quests'], <String, dynamic>{'dayKey': 'today'});
  });

  test('clear cancels a write that was queued before owner cleanup', () async {
    final Future<void> write = snapshots.write('owner-a', 8, <String, dynamic>{
      'passes': <String, Object?>{'active': true},
    });
    final Future<void> clear = snapshots.clearForUser('owner-a');
    await Future.wait(<Future<void>>[write, clear]);

    expect(await snapshots.read('owner-a'), isNull);
  });

  test('root display projection is filtered and owner cleanup cancels stale writes', () async {
    await snapshots.writeRoot('owner-a', <String, dynamic>{
      'xp': 240,
      'xpWeek': <String, Object?>{'weekKey': '2026-W42', 'xp': 40},
      'cosmetics': <String, Object?>{'frame': 'frame-a'},
      'coins': 999999,
    });

    expect(await snapshots.readRoot('owner-a'), <String, dynamic>{
      'xp': 240,
      'xpWeek': <String, dynamic>{'weekKey': '2026-W42', 'xp': 40},
      'cosmetics': <String, dynamic>{'frame': 'frame-a'},
    });

    final Future<void> staleWrite = snapshots.writeRoot('owner-a', <String, dynamic>{'xp': 999});
    final Future<void> clear = snapshots.clearForUser('owner-a');
    await Future.wait(<Future<void>>[staleWrite, clear]);

    expect(await snapshots.readRoot('owner-a'), isNull);
  });

  test('restored passes enforce their server expiry', () {
    final Passes passes = Passes.fromMap(<String, Object?>{
      'autoRotatePassUntil': DateTime.utc(2026, 10, 17).millisecondsSinceEpoch,
    });

    expect(passes.autoRotatePassActive(DateTime.utc(2026, 10, 16)), isTrue);
    expect(passes.autoRotatePassActive(DateTime.utc(2026, 10, 17)), isFalse);
  });
}
