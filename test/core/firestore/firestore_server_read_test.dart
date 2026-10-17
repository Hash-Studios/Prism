import 'dart:async';

import 'package:Prism/core/firestore/firestore_query_specs.dart';
import 'package:Prism/core/firestore/firestore_server_read.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_firestore_client.dart';

typedef _Snapshot<T> = ({List<T> items, bool isFromCache});

class _MetadataClient extends FakeFirestoreClient {
  _MetadataClient(this.events);

  final Stream<_Snapshot<String>> Function() events;
  FirestoreQuerySpec? seenSpec;

  @override
  Stream<({List<T> items, bool isFromCache})> watchQueryWithMetadata<T>(
    FirestoreQuerySpec spec,
    T Function(Map<String, dynamic> data, String docId) map,
  ) {
    seenSpec = spec;
    return events().map(
      (snapshot) => (
        items: snapshot.items.map((String id) => map(<String, dynamic>{}, id)).toList(growable: false),
        isFromCache: snapshot.isFromCache,
      ),
    );
  }
}

void main() {
  test('ignores cached empty results and accepts a server empty result', () async {
    final StreamController<_Snapshot<String>> controller = StreamController<_Snapshot<String>>();
    final _MetadataClient client = _MetadataClient(() => controller.stream);
    final Future<List<String>> result = client.queryFromServer<String>(
      const FirestoreQuerySpec(collection: 'items', sourceTag: 'items.read'),
      (_, id) => id,
      timeout: const Duration(seconds: 1),
    );
    bool completed = false;
    result.then((_) => completed = true);

    controller.add((items: <String>[], isFromCache: true));
    await Future<void>.delayed(Duration.zero);
    expect(completed, isFalse);
    controller.add((items: <String>[], isFromCache: false));

    expect(await result, isEmpty);
    await controller.close();
  });

  test('getFromServer filters by document id, limits to one, and maps server row', () async {
    final _MetadataClient client = _MetadataClient(
      () => Stream<_Snapshot<String>>.value((items: <String>['row'], isFromCache: false)),
    );

    expect(
      await client.getFromServer<String>('items', 'item-1', (_, id) => '$id-mapped', sourceTag: 'item.read'),
      'row-mapped',
    );
    expect(client.seenSpec?.filters.single.field, firestoreDocumentIdField);
    expect(client.seenSpec?.filters.single.value, 'item-1');
    expect(client.seenSpec?.filters.single.op, FirestoreFilterOp.isEqualTo);
    expect(client.seenSpec?.limit, 1);
  });

  test('accepts a synchronous server event before listen returns', () async {
    final _MetadataClient client = _MetadataClient(
      () => Stream<_Snapshot<String>>.multi((controller) {
        controller.addSync((items: <String>['sync'], isFromCache: false));
      }, isBroadcast: false),
    );

    expect(
      await client.queryFromServer<String>(
        const FirestoreQuerySpec(collection: 'items', sourceTag: 'items.read'),
        (_, id) => id,
      ),
      <String>['sync'],
    );
  });

  test('times out and cancels the metadata subscription', () async {
    int cancellations = 0;
    final StreamController<({List<String> items, bool isFromCache})> controller =
        StreamController<({List<String> items, bool isFromCache})>(onCancel: () => cancellations++);
    final FakeFirestoreClient client = _StreamMetadataClient(controller.stream);

    await expectLater(
      client.queryFromServer<String>(
        const FirestoreQuerySpec(collection: 'items', sourceTag: 'items.read'),
        (_, id) => id,
        timeout: const Duration(milliseconds: 1),
      ),
      throwsA(isA<TimeoutException>()),
    );
    expect(cancellations, 1);
    await controller.close();
  });

  test('timeout does not wait for a slow subscription cancellation', () async {
    final Completer<void> cancellation = Completer<void>();
    final StreamController<({List<String> items, bool isFromCache})> controller =
        StreamController<({List<String> items, bool isFromCache})>(onCancel: () => cancellation.future);
    final FakeFirestoreClient client = _StreamMetadataClient(controller.stream);

    await expectLater(
      client.queryFromServer<String>(
        const FirestoreQuerySpec(collection: 'items', sourceTag: 'items.read'),
        (_, id) => id,
        timeout: const Duration(milliseconds: 1),
      ),
      throwsA(isA<TimeoutException>()),
    );
    expect(cancellation.isCompleted, isFalse);
    cancellation.complete();
    await controller.close();
  });

  test('does not leak a failed cancellation after a server result', () async {
    final StreamController<({List<String> items, bool isFromCache})> controller =
        StreamController<({List<String> items, bool isFromCache})>(
          onCancel: () => Future<void>.error(StateError('cancel failed')),
        );
    final FakeFirestoreClient client = _StreamMetadataClient(controller.stream);
    final Future<List<String>> result = client.queryFromServer<String>(
      const FirestoreQuerySpec(collection: 'items', sourceTag: 'items.read'),
      (_, id) => id,
    );
    controller.add((items: <String>['server'], isFromCache: false));

    expect(await result, <String>['server']);
    await Future<void>.delayed(Duration.zero);
  });

  test('propagates stream errors and cancels', () async {
    int cancellations = 0;
    final StreamController<({List<String> items, bool isFromCache})> controller =
        StreamController<({List<String> items, bool isFromCache})>(onCancel: () => cancellations++);
    final FakeFirestoreClient client = _StreamMetadataClient(controller.stream);
    final Future<List<String>> result = client.queryFromServer<String>(
      const FirestoreQuerySpec(collection: 'items', sourceTag: 'items.read'),
      (_, id) => id,
    );
    controller.addError(StateError('stream failed'));

    await expectLater(result, throwsA(isA<StateError>()));
    expect(cancellations, 1);
    await controller.close();
  });

  test('waits through stream completion without a server event until timeout', () async {
    final _MetadataClient client = _MetadataClient(() => Stream<_Snapshot<String>>.empty());

    await expectLater(
      client.queryFromServer<String>(
        const FirestoreQuerySpec(collection: 'items', sourceTag: 'items.read'),
        (_, id) => id,
        timeout: const Duration(milliseconds: 1),
      ),
      throwsA(isA<TimeoutException>()),
    );
  });
}

class _StreamMetadataClient extends FakeFirestoreClient {
  _StreamMetadataClient(this.stream);

  final Stream<({List<String> items, bool isFromCache})> stream;

  @override
  Stream<({List<T> items, bool isFromCache})> watchQueryWithMetadata<T>(
    FirestoreQuerySpec spec,
    T Function(Map<String, dynamic> data, String docId) map,
  ) => stream.map(
    (snapshot) => (
      items: snapshot.items.map((String id) => map(<String, dynamic>{}, id)).toList(growable: false),
      isFromCache: snapshot.isFromCache,
    ),
  );
}
