import 'dart:async';

import 'package:Prism/core/router/deep_link_action_entity.dart';
import 'package:Prism/core/router/pending_deep_link_queue.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a link that arrives while an earlier one resolves is handled, not stuck', () async {
    final PendingDeepLinkQueue queue = PendingDeepLinkQueue()..add(const ShortCodeIntent(code: 'a', rawUri: 'first'));
    final List<String> handled = <String>[];
    final Completer<void> resolving = Completer<void>();
    final Completer<void> entered = Completer<void>();
    Future<void> handle(DeepLinkActionEntity action) async {
      handled.add(action.rawUri);
      if (handled.length == 1) {
        entered.complete();
        await resolving.future;
      }
    }

    final Future<void> draining = queue.drain(handle, onError: (_, _, _) => fail('no error expected'));
    await entered.future;
    queue.add(const UserLinkIntent(profileIdentifier: 'bob', rawUri: 'second'));
    await queue.drain(handle, onError: (_, _, _) {}); // Busy: returns at once, the first drain owns the queue.
    expect(handled, <String>['first']);

    resolving.complete();
    await draining;

    expect(handled, <String>['first', 'second']);
    expect(queue.isEmpty, isTrue);
  });

  test('a link that throws is reported and the links after it still run', () async {
    final PendingDeepLinkQueue queue = PendingDeepLinkQueue()
      ..add(const ShortCodeIntent(code: 'a', rawUri: 'fails'))
      ..add(const UserLinkIntent(profileIdentifier: 'bob', rawUri: 'next'));
    final List<String> handled = <String>[];
    final List<String> failed = <String>[];

    await queue.drain((action) async {
      if (action.rawUri == 'fails') throw StateError('launch failed');
      handled.add(action.rawUri);
    }, onError: (action, _, _) => failed.add(action.rawUri));

    expect(failed, <String>['fails']);
    expect(handled, <String>['next']);
    expect(queue.isEmpty, isTrue);
  });
}
