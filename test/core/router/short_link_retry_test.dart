import 'dart:async';

import 'package:Prism/core/router/short_link_retry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ShortLinkRetryScheduler', () {
    late StreamController<bool> online;
    late bool connected;
    late List<String> retried;
    late ShortLinkRetryScheduler scheduler;

    setUp(() {
      online = StreamController<bool>.broadcast();
      connected = false;
      retried = <String>[];
      scheduler = ShortLinkRetryScheduler(
        onlineChanges: () => online.stream,
        hasConnection: () async => connected,
        retry: retried.add,
      );
    });

    tearDown(() async {
      scheduler.dispose();
      await online.close();
    });

    test('retries once when the connection comes back', () async {
      scheduler.schedule('abc');
      online.add(false);
      await Future<void>.delayed(Duration.zero);
      expect(retried, isEmpty);

      online.add(true);
      await Future<void>.delayed(Duration.zero);
      online.add(true);
      await Future<void>.delayed(Duration.zero);

      expect(retried, <String>['abc']);
      expect(scheduler.hasPending, isFalse);
    });

    test('retries on resume only when a connection exists', () async {
      scheduler.schedule('abc');

      await scheduler.onResumed();
      expect(retried, isEmpty);
      expect(scheduler.hasPending, isTrue);

      connected = true;
      await scheduler.onResumed();
      await scheduler.onResumed();

      expect(retried, <String>['abc']);
    });

    test('resume with nothing pending does not check the connection', () async {
      var checked = false;
      final idle = ShortLinkRetryScheduler(
        onlineChanges: () => online.stream,
        hasConnection: () async => checked = true,
        retry: retried.add,
      );

      await idle.onResumed();

      expect(checked, isFalse);
    });

    test('each queued code retries in arrival order', () async {
      scheduler.schedule('old');
      scheduler.schedule('new');

      online.add(true);
      await Future<void>.delayed(Duration.zero);

      expect(retried, <String>['old', 'new']);
    });

    test('dispose drops the pending code', () async {
      scheduler.schedule('abc');
      scheduler.dispose();

      online.add(true);
      await Future<void>.delayed(Duration.zero);

      expect(retried, isEmpty);
    });
  });
}
