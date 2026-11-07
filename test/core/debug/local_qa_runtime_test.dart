import 'dart:io';

import 'package:Prism/core/debug/local_qa_adapters.dart';
import 'package:Prism/core/debug/local_qa_runtime.dart';
import 'package:Prism/env/env.dart';
import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/firebase_core_platform_interface.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _NativeCore extends MockFirebaseApp {
  _NativeCore(this.nativeApps);

  final List<CoreInitializeResponse> nativeApps;
  int creates = 0;

  @override
  Future<List<CoreInitializeResponse>> initializeCore() async => nativeApps;

  @override
  Future<CoreInitializeResponse> initializeApp(String name, CoreFirebaseOptions options) async {
    creates++;
    return CoreInitializeResponse(name: name, options: options, pluginConstants: {});
  }
}

class _AuthBoundary extends FirebaseAuthPlatform {
  int connects = 0;

  @override
  FirebaseAuthPlatform delegateFor({required FirebaseApp app}) => this;

  @override
  FirebaseAuthPlatform setInitialValues({String? languageCode, InternalUserDetails? currentUser}) => this;

  @override
  Future<void> useAuthEmulator(String host, int port) async {
    connects++;
    throw StateError('emulator transport reached');
  }
}

CoreInitializeResponse nativeApp(String name, {String project = 'demo-prism', String? bucket}) =>
    CoreInitializeResponse(
      name: name,
      options: CoreFirebaseOptions(
        apiKey: 'AIzaSy000000000000000000000000000000000',
        appId: '1:1234567890:ios:0123456789abcdef',
        messagingSenderId: '1234567890',
        projectId: project,
        storageBucket: bucket,
      ),
      pluginConstants: {},
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('QA stores isolate identities and never clear ordinary preferences', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{'session': 'ordinary session'});
    final viewer = LocalQaStore('viewer');
    final creator = LocalQaStore('creator');
    await viewer.init();
    await creator.init();
    expect(viewer.get('session'), isNull);
    await viewer.set('session', 'local viewer');
    await creator.set('session', 'local creator');
    expect(await viewer.keys(), <String>['session']);
    await viewer.clearAll();
    expect(viewer.get('session'), isNull);
    expect(creator.get('session'), 'local creator');
    expect((await SharedPreferences.getInstance()).getString('session'), 'ordinary session');
  });

  test('QA requires explicit activation and blocks external hosts and undeclared ports', () async {
    final previous = HttpOverrides.current;
    addTearDown(() => HttpOverrides.global = previous);
    if (!Env.localQa) {
      expect(LocalQaRuntime.installNetworkPolicy, throwsStateError);
      expect(HttpOverrides.current, same(previous));
      return;
    }
    LocalQaRuntime.installNetworkPolicy();
    final client = HttpClient();
    addTearDown(() => client.close(force: true));
    for (final url in <String>['https://example.com/', 'http://127.0.0.1:8080/', 'http://169.254.169.254/']) {
      await expectLater(() => client.getUrl(Uri.parse(url)), throwsStateError);
    }
  });

  group('native Firebase discovery', () {
    late _AuthBoundary auth;

    setUp(() {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      MethodChannelFirebase.appInstances = {};
      MethodChannelFirebase.isCoreInitialized = false;
      FirebasePlatform.instance = MethodChannelFirebase();
      auth = _AuthBoundary();
      FirebaseAuthPlatform.instance = auth;
    });

    tearDown(() {
      TestFirebaseCoreHostApi.setUp(null);
      MethodChannelFirebase.appInstances = {};
      MethodChannelFirebase.isCoreInitialized = false;
      debugDefaultTargetPlatformOverride = null;
    });

    test('reuses the lazy iOS default without a bucket instead of throwing duplicate-app', () async {
      final core = _NativeCore([nativeApp('[DEFAULT]')]);
      TestFirebaseCoreHostApi.setUp(core);
      expect(Firebase.apps, isEmpty);
      await expectLater(
        LocalQaRuntime.initializeFirebase(),
        throwsA(isA<StateError>().having((error) => error.message, 'message', 'emulator transport reached')),
      );
      expect(core.creates, 0);
      expect(auth.connects, 1);
    });

    test('rejects a lazy non-demo secondary before touching Auth', () async {
      TestFirebaseCoreHostApi.setUp(
        _NativeCore([
          nativeApp('[DEFAULT]', bucket: 'demo-prism.appspot.com'),
          nativeApp('production', project: 'prism-wallpapers'),
        ]),
      );
      await expectLater(
        LocalQaRuntime.initializeFirebase(),
        throwsA(isA<StateError>().having((error) => error.message, 'message', contains('non-demo Firebase'))),
      );
      expect(auth.connects, 0);
    });

    test('creates the default when only a named demo app already exists', () async {
      final core = _NativeCore([nativeApp('named')]);
      TestFirebaseCoreHostApi.setUp(core);
      await Firebase.initializeApp(
        name: 'named',
        options: const FirebaseOptions(
          apiKey: 'AIzaSy000000000000000000000000000000000',
          appId: '1:1234567890:ios:0123456789abcdef',
          messagingSenderId: '1234567890',
          projectId: 'demo-prism',
        ),
      );
      await expectLater(
        LocalQaRuntime.initializeFirebase(),
        throwsA(isA<StateError>().having((error) => error.message, 'message', 'emulator transport reached')),
      );
      expect(Firebase.app().options.projectId, 'demo-prism');
      expect(core.creates, 1);
    });
  });
}
