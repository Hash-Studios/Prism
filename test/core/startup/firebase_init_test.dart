import 'dart:async';

import 'package:Prism/core/startup/firebase_init.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a bounded readiness wait does not prevent later Firebase identity restoration', () async {
    final completer = Completer<bool>();
    FirebaseInit.setFuture(completer.future);

    expect(await FirebaseInit.waitUntilReady(timeout: const Duration(milliseconds: 1)), isFalse);

    completer.complete(true);
    expect(
      await FirebaseInit.readyFuture,
      isTrue,
      reason: 'a bounded offline wait must not replace eventual readiness',
    );
  });
}
