import 'dart:async';

import 'package:Prism/core/purchases/paywall_orchestrator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('stays presenting until every overlapping paywall call finishes', () async {
    final PaywallPresentationGate gate = PaywallPresentationGate();
    final Completer<void> first = Completer<void>();
    final Completer<void> second = Completer<void>();

    final Future<void> firstCall = gate.run(() => first.future);
    final Future<void> secondCall = gate.run(() => second.future);
    expect(gate.presenting.value, isTrue);

    first.complete();
    await firstCall;
    expect(gate.presenting.value, isTrue);

    second.complete();
    await secondCall;
    expect(gate.presenting.value, isFalse);
    gate.dispose();
  });
}
