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

    final Future<void> draining = queue.drain(handle);
    await entered.future;
    queue.add(const UserLinkIntent(profileIdentifier: 'bob', rawUri: 'second'));
    await queue.drain(handle); // Busy: returns at once, the first drain owns the queue.
    expect(handled, <String>['first']);

    resolving.complete();
    await draining;

    expect(handled, <String>['first', 'second']);
    expect(queue.isEmpty, isTrue);
  });
}
