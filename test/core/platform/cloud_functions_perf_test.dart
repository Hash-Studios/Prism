// ignore_for_file: depend_on_referenced_packages

import 'package:cloud_functions/cloud_functions.dart';
import 'package:cloud_functions_platform_interface/cloud_functions_platform_interface.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

class _Functions extends FirebaseFunctionsPlatform {
  _Functions() : super(null, 'perf-hook-test');

  Object? failure;

  @override
  FirebaseFunctionsPlatform delegateFor({FirebaseApp? app, required String region}) => this;

  @override
  HttpsCallablePlatform httpsCallable(String? origin, String name, HttpsCallableOptions options) =>
      _Callable(this, origin, name, options);
}

class _Callable extends HttpsCallablePlatform {
  _Callable(_Functions functions, String? origin, String name, HttpsCallableOptions options)
    : super(functions, origin, name, options, null);

  @override
  Future<dynamic> call([dynamic parameters]) async {
    final Object? failure = (functions as _Functions).failure;
    if (failure != null) throw failure;
    return <String, Object>{'views': 42};
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FirebaseFunctionsPlatform previous;
  late _Functions platform;
  late HttpsCallable callable;

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
    previous = FirebaseFunctionsPlatform.instance;
    platform = _Functions();
    FirebaseFunctionsPlatform.instance = platform;
    callable = FirebaseFunctions.instanceFor(region: 'perf-hook-test').httpsCallable('recordWallpaperView');
  });
  setUp(() {
    platform.failure = null;
    HttpsCallable.perfSink = (_, _, _) => throw StateError('diagnostic failed');
  });
  tearDown(() => HttpsCallable.perfSink = null);
  tearDownAll(() => FirebaseFunctionsPlatform.instance = previous);

  test('a broken latency sink preserves a successful callable response', () async {
    expect((await callable.call<Object?>()).data, <String, Object>{'views': 42});
  });

  test('a broken latency sink preserves the original callable failure', () async {
    final FirebaseFunctionsException failure = FirebaseFunctionsException(code: 'unavailable', message: 'offline');
    platform.failure = failure;
    await expectLater(callable.call<Object?>(), throwsA(same(failure)));
  });

  test('release callables never invoke a configured latency sink', () async {
    int samples = 0;
    HttpsCallable.perfSink = (_, _, _) => samples++;
    await callable.call<Object?>();
    expect(samples, 0);
  }, skip: !kReleaseMode);
}
