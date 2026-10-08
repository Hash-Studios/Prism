// ignore_for_file: depend_on_referenced_packages

import 'dart:async';

import 'package:Prism/core/startup/session_end_watcher.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const debounce = Duration(seconds: 5);
  late StreamController<Object?> tokens;
  late bool loggedIn;
  late int ended;
  late SessionEndWatcher watcher;

  // The watcher starts its timer inside the fake zone, so it must be built there.
  void run(void Function(FakeAsync async) body) {
    fakeAsync((async) {
      tokens = StreamController<Object?>.broadcast(sync: true);
      loggedIn = true;
      ended = 0;
      watcher = SessionEndWatcher(
        idTokenChanges: tokens.stream,
        isLoggedIn: () => loggedIn,
        onSessionEnded: () async => ended++,
      )..start();
      body(async);
      watcher.dispose();
      unawaited(tokens.close());
    });
  }

  test('a null user while the app is signed in ends the session after the debounce', () {
    run((async) {
      tokens.add(null);
      async.elapse(const Duration(seconds: 4));
      expect(ended, 0);
      async.elapse(const Duration(seconds: 2));

      expect(ended, 1);
    });
  });

  test('a token refresh inside the debounce window cancels it', () {
    run((async) {
      tokens.add(null);
      async.elapse(const Duration(seconds: 2));
      tokens.add('user');
      async.elapse(debounce);

      expect(ended, 0);
    });
  });

  test('a normal token refresh never fires', () {
    run((async) {
      tokens.add('user');
      tokens.add('user');
      async.elapse(debounce * 2);

      expect(ended, 0);
    });
  });

  test('a sign-out the user started does not count, because the app is already signed out', () {
    run((async) {
      loggedIn = false;
      tokens.add(null);
      async.elapse(debounce * 2);

      expect(ended, 0);
    });
  });

  test('the app signing out inside the debounce window cancels it', () {
    run((async) {
      tokens.add(null);
      loggedIn = false;
      async.elapse(debounce * 2);

      expect(ended, 0);
    });
  });

  test('one lost session fires once', () {
    run((async) {
      tokens.add(null);
      tokens.add(null);
      async.elapse(debounce * 3);

      expect(ended, 1);
    });
  });

  test('a disposed watcher ignores events', () {
    run((async) {
      watcher.dispose();
      tokens.add(null);
      async.elapse(debounce * 2);

      expect(ended, 0);
    });
  });
}
