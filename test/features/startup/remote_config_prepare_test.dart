import 'dart:async';

import 'package:Prism/features/startup/data/repositories/startup_repository_impl.dart';
import 'package:fake_async/fake_async.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

// ignore_for_file: depend_on_referenced_packages

class _MockRemoteConfig extends Mock implements FirebaseRemoteConfig {}

void main() {
  late _MockRemoteConfig rc;
  final calls = <String>[];

  setUpAll(
    () => registerFallbackValue(RemoteConfigSettings(fetchTimeout: Duration.zero, minimumFetchInterval: Duration.zero)),
  );

  setUp(() {
    calls.clear();
    rc = _MockRemoteConfig();
    when(() => rc.setConfigSettings(any())).thenAnswer((_) async => calls.add('settings'));
    when(() => rc.setDefaults(any())).thenAnswer((_) async => calls.add('defaults'));
    when(() => rc.activate()).thenAnswer((_) async {
      calls.add('activate');
      return true;
    });
  });

  test('cached values are activated before the fetch starts', () async {
    when(() => rc.fetchAndActivate()).thenAnswer((_) async {
      calls.add('fetch');
      return true;
    });

    await prepareRemoteConfig(rc, release: true);

    expect(calls, <String>['settings', 'defaults', 'activate', 'fetch']);
  });

  test('release builds use a 5 s timeout and a 1 h minimum interval, debug builds fetch every time', () async {
    when(() => rc.fetchAndActivate()).thenAnswer((_) async => true);

    await prepareRemoteConfig(rc, release: true);
    await prepareRemoteConfig(rc, release: false);

    final settings = verify(() => rc.setConfigSettings(captureAny())).captured.cast<RemoteConfigSettings>();
    expect(settings[0].fetchTimeout, const Duration(seconds: 5));
    expect(settings[0].minimumFetchInterval, const Duration(hours: 1));
    expect(settings[1].minimumFetchInterval, Duration.zero);
  });

  test('a fetch that never answers does not hold startup past the budget', () {
    fakeAsync((async) {
      when(() => rc.fetchAndActivate()).thenAnswer((_) => Completer<bool>().future);
      var done = false;

      unawaited(prepareRemoteConfig(rc, release: true).then((_) => done = true));
      async.elapse(const Duration(seconds: 4));
      expect(done, isFalse);
      async.elapse(const Duration(seconds: 2));

      expect(done, isTrue);
    });
  });

  test('a failed fetch, even one that fails after the budget, does not throw', () async {
    when(() => rc.fetchAndActivate()).thenAnswer((_) async => throw StateError('offline'));

    await prepareRemoteConfig(rc, release: true);
  });
}
