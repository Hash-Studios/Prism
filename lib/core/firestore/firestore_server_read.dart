import 'dart:async';

import 'package:Prism/core/firestore/firestore_client.dart';
import 'package:Prism/core/firestore/firestore_query_specs.dart';

extension FirestoreServerRead on FirestoreClient {
  Future<List<T>> queryFromServer<T>(
    FirestoreQuerySpec spec,
    T Function(Map<String, dynamic>, String) map, {
    Duration timeout = const Duration(seconds: 5),
  }) => _confirmedServerRead<T>(this, spec, map, timeout);

  Future<T?> getFromServer<T>(
    String collection,
    String id,
    T Function(Map<String, dynamic>, String) map, {
    required String sourceTag,
    Duration timeout = const Duration(seconds: 5),
  }) async {
    final List<T> items = await queryFromServer<T>(
      FirestoreQuerySpec(
        collection: collection,
        sourceTag: sourceTag,
        filters: <FirestoreFilter>[
          FirestoreFilter(field: firestoreDocumentIdField, op: FirestoreFilterOp.isEqualTo, value: id),
        ],
        limit: 1,
      ),
      map,
      timeout: timeout,
    );
    return items.isEmpty ? null : items.first;
  }
}

Future<List<T>> _confirmedServerRead<T>(
  FirestoreClient client,
  FirestoreQuerySpec spec,
  T Function(Map<String, dynamic>, String) map,
  Duration timeout,
) {
  final Completer<List<T>> completer = Completer<List<T>>();
  StreamSubscription<({List<T> items, bool isFromCache})>? subscription;
  Timer? timer;
  bool completed = false;

  void finish({List<T>? items, Object? error, StackTrace? stackTrace}) {
    if (completed) return;
    completed = true;
    timer?.cancel();
    final StreamSubscription<({List<T> items, bool isFromCache})>? active = subscription;
    if (active != null) _cancelWithoutWaiting(active);
    if (error != null) {
      completer.completeError(error, stackTrace ?? StackTrace.current);
    } else {
      completer.complete(items!);
    }
  }

  timer = Timer(timeout, () {
    finish(error: TimeoutException('No confirmed server snapshot for ${spec.sourceTag}.', timeout));
  });

  try {
    final Stream<({List<T> items, bool isFromCache})> stream = client.watchQueryWithMetadata<T>(spec, map);
    final StreamSubscription<({List<T> items, bool isFromCache})> listening = stream.listen((snapshot) {
      if (!snapshot.isFromCache) finish(items: snapshot.items);
    }, onError: (Object error, StackTrace stackTrace) => finish(error: error, stackTrace: stackTrace));
    subscription = listening;
    if (completed) _cancelWithoutWaiting(listening);
  } on Object catch (error, stackTrace) {
    finish(error: error, stackTrace: stackTrace);
  }

  return completer.future;
}

void _cancelWithoutWaiting<T>(StreamSubscription<T> subscription) {
  try {
    unawaited(subscription.cancel().then<void>((_) {}, onError: (Object _, StackTrace __) {}));
  } on Object {}
}
