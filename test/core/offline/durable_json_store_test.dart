import 'dart:async';
import 'dart:io';

import 'package:Prism/core/offline/durable_json_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory root;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('prism-json-store-');
  });

  tearDown(() async {
    await root.delete(recursive: true);
  });

  test('awaited records survive a store restart', () async {
    final first = DurableJsonStore('walls', directory: root);
    await first.write('wall/1', <String, Object?>{'id': '1', 'saved': true});

    final restarted = DurableJsonStore('walls', directory: root);

    expect(await restarted.read('wall/1'), <String, Object?>{'id': '1', 'saved': true});
  });

  test('corrupt record is isolated from valid siblings', () async {
    final store = DurableJsonStore('walls', directory: root);
    await store.write('one', <String, Object?>{'value': 1});
    await store.write('two', <String, Object?>{'value': 2});
    final record = (await root.list().where((entity) => entity is File).cast<File>().toList()).firstWhere(
      (file) => file.readAsStringSync().contains('"two"'),
    );
    await record.writeAsString('{broken');

    expect(await store.read('two'), isNull);
    expect(await store.readAll(), <String, Map<String, Object?>>{
      'one': <String, Object?>{'value': 1},
    });
  });

  test('read returns null if the record is deleted after its size check', () async {
    final writer = DurableJsonStore('walls', directory: root);
    await writer.write('racing', <String, Object?>{'value': 1});
    final checked = Completer<void>();
    final continueRead = Completer<void>();
    final reader = DurableJsonStore(
      'walls',
      directory: root,
      beforeReadContents: (_) async {
        checked.complete();
        await continueRead.future;
      },
    );

    final pendingRead = reader.read('racing');
    await checked.future;
    final record = (await root.list().where((entity) => entity is File).cast<File>().toList()).single;
    await record.delete();
    continueRead.complete();

    expect(await pendingRead, isNull);
  });

  test('unsafe keys are stored without escaping the store directory', () async {
    final store = DurableJsonStore('walls', directory: root);
    await store.write('../../outside', <String, Object?>{'safe': true});

    expect(await store.read('../../outside'), <String, Object?>{'safe': true});
    expect(await File('${root.parent.path}/outside.json').exists(), isFalse);
    expect((await root.list().toList()).every((entity) => entity is File), isTrue);
  });

  test('a failed write does not poison later writes', () async {
    final blocked = File('${root.path}/blocked')..writeAsStringSync('not a directory');
    final store = DurableJsonStore('walls', directory: Directory(blocked.path));

    await expectLater(store.write('first', <String, Object?>{'value': 1}), throwsA(isA<FileSystemException>()));

    blocked.deleteSync();
    Directory(blocked.path).createSync();
    await store.write('second', <String, Object?>{'value': 2});
    final restarted = DurableJsonStore('walls', directory: Directory(blocked.path));
    expect(await restarted.read('second'), <String, Object?>{'value': 2});
  });

  test('concurrent writes are durable before they complete', () async {
    final store = DurableJsonStore('walls', directory: root);
    await Future.wait(<Future<void>>[
      for (var index = 0; index < 5; index++) store.write('wall-$index', <String, Object?>{'index': index}),
    ]);

    expect(await DurableJsonStore('walls', directory: root).readAll(), hasLength(5));
  });

  test('rejects a record over the hard byte cap without creating a partial record', () async {
    final store = DurableJsonStore('walls', directory: root);

    await expectLater(
      store.write('large', <String, Object?>{
        'payload': List<String>.filled(DurableJsonStore.maxRecordBytes + 1, 'x').join(),
      }),
      throwsA(isA<DurableJsonStoreLimitException>()),
    );

    expect(await store.read('large'), isNull);
    expect(await root.list().toList(), isEmpty);
  });

  test('counts UTF-8 bytes when enforcing the record limit', () async {
    final store = DurableJsonStore('walls', directory: root);
    final payload = 'é' * (DurableJsonStore.maxRecordBytes ~/ 2);

    await expectLater(
      store.write('unicode', <String, Object?>{'payload': payload}),
      throwsA(isA<DurableJsonStoreLimitException>()),
    );
    expect(await root.list().toList(), isEmpty);
  });

  test('does not undercount a corrupt directory already over the byte cap when replacing a record', () async {
    final store = DurableJsonStore('walls', directory: root);
    await store.write('target', <String, Object?>{'value': 'old'});
    final targetId = (await root.list().first as File).path;
    await File(targetId).writeAsBytes(List<int>.filled(40 * 1024 * 1024, 0), flush: true);
    for (final name in <String>['over-budget-a.json', 'over-budget-b.json']) {
      final file = File('${root.path}/$name');
      await file.create();
      await file.open(mode: FileMode.writeOnly).then((handle) async {
        await handle.truncate(40 * 1024 * 1024);
        await handle.close();
      });
    }

    await expectLater(
      store.write('target', <String, Object?>{'value': 'new'}),
      throwsA(isA<DurableJsonStoreLimitException>()),
    );
  });
}
