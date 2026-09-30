import 'dart:async';

import 'package:Prism/core/router/deep_link_action_entity.dart';
import 'package:Prism/core/router/pending_deep_link_queue.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('holds cold-start setup links until startup is ready', () async {
    final queue = PendingDeepLinkQueue()..add(const SetupLinkIntent(rawUri: 'setup/first'));
    final handled = <String>[];
    Future<void> handle(DeepLinkActionEntity action) async => handled.add(action.rawUri);

    await queue.drain(handle, ready: false);
    expect(handled, isEmpty);
    expect(queue.isEmpty, isFalse);
    await queue.drain(handle, ready: true);
    expect(handled, <String>['setup/first']);
    expect(queue.isEmpty, isTrue);
  });

  test('drains setup links that arrive during resolution without overlapping handlers', () async {
    final PendingDeepLinkQueue queue = PendingDeepLinkQueue()
      ..add(const SetupLinkIntent(rawUri: 'https://prismwalls.com/setup/first'));
    final List<String> handled = <String>[];
    final resolving = Completer<void>();
    final entered = Completer<void>();
    Future<void> handle(DeepLinkActionEntity action) async {
      handled.add(action.rawUri);
      if (handled.length == 1) {
        entered.complete();
        await resolving.future;
      }
    }

    final draining = queue.drain(handle, ready: true);
    await entered.future;
    queue.add(const SetupLinkIntent(rawUri: 'https://prismwalls.com/setup/second'));
    await queue.drain(handle, ready: true);
    expect(handled, <String>['https://prismwalls.com/setup/first']);
    resolving.complete();
    await draining;

    expect(handled, <String>['https://prismwalls.com/setup/first', 'https://prismwalls.com/setup/second']);
    expect(queue.isEmpty, isTrue);
  });
}
