// ignore_for_file: depend_on_referenced_packages

import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:cloud_functions_platform_interface/cloud_functions_platform_interface.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter_test/flutter_test.dart';

class _StreamingFunctions extends FirebaseFunctionsPlatform {
  _StreamingFunctions(this.controller) : super(null, 'stream-cancellation');

  final StreamController<Object?> controller;
  Object? input;

  @override
  FirebaseFunctionsPlatform delegateFor({FirebaseApp? app, required String region}) => this;

  @override
  HttpsCallablePlatform httpsCallable(String? origin, String name, HttpsCallableOptions options) =>
      _StreamingCallable(this, origin, name, options);
}

class _StreamingCallable extends HttpsCallablePlatform {
  _StreamingCallable(_StreamingFunctions functions, String? origin, String name, HttpsCallableOptions options)
    : super(functions, origin, name, options, null);

  @override
  Stream<Object?> stream(Object? parameters) {
    final source = functions as _StreamingFunctions;
    source.input = parameters;
    return source.controller.stream;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('canceling a public callable stream cancels its native delegate', () async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
    final started = Completer<void>();
    final canceled = Completer<void>();
    final controller = StreamController<Object?>(onListen: started.complete, onCancel: canceled.complete);
    final previousPlatform = FirebaseFunctionsPlatform.instance;
    final platform = _StreamingFunctions(controller);
    FirebaseFunctionsPlatform.instance = platform;
    addTearDown(() async {
      FirebaseFunctionsPlatform.instance = previousPlatform;
      await controller.close();
    });
    final received = Completer<Chunk<String, String>>();
    final subscription = FirebaseFunctions.instanceFor(region: 'stream-cancellation')
        .httpsCallable('testStream')
        .stream<String, String>(<String, Object>{'request': 'wall'})
        .listen((response) => received.complete(response as Chunk<String, String>));

    await started.future;
    controller.add(<String, Object>{'message': 'first chunk'});
    expect((await received.future).partialData, 'first chunk');
    expect(platform.input, <String, Object>{'request': 'wall'});

    await subscription.cancel();
    expect(canceled.isCompleted, isTrue);
  });
}
