import 'dart:async';
import 'dart:io';

import 'package:Prism/auth/user_model.dart';
import 'package:Prism/core/constants/app_constants.dart' as app_constants;
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/data/upload/wallpaper/wallfirestore.dart';
import 'package:cloud_firestore_platform_interface/cloud_firestore_platform_interface.dart';
import 'package:cloud_functions_platform_interface/cloud_functions_platform_interface.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/in_memory_local_store.dart';

class _FakeFirestorePlatform extends FirebaseFirestorePlatform {
  final List<String> updatedPaths = <String>[];
  Completer<void>? wallWriteStarted;
  Completer<void>? allowWallWrite;
  Completer<void>? userUpdateAttempted;
  bool failUserUpdate = false;

  @override
  FirebaseFirestorePlatform delegateFor({required FirebaseApp app, required String databaseId}) => this;

  @override
  CollectionReferencePlatform collection(String collectionPath) => _FakeCollectionReference(this, collectionPath);
}

class _FakeCollectionReference extends CollectionReferencePlatform {
  _FakeCollectionReference(super.firestore, super.path);

  @override
  DocumentReferencePlatform doc([String? path]) =>
      _FakeDocumentReference(firestore, '${this.path}/${path ?? 'new-wall'}');
}

class _FakeDocumentReference extends DocumentReferencePlatform {
  _FakeDocumentReference(super.firestore, super.path);

  @override
  Future<void> set(Map<String, dynamic> data, [SetOptions? options]) async {
    final _FakeFirestorePlatform platform = firestore as _FakeFirestorePlatform;
    if (path.startsWith('walls/')) {
      platform.wallWriteStarted?.complete();
      await platform.allowWallWrite?.future;
    }
  }

  @override
  Future<void> update(Map<FieldPath, dynamic> data) async {
    final _FakeFirestorePlatform platform = firestore as _FakeFirestorePlatform;
    platform.updatedPaths.add(path);
    platform.userUpdateAttempted?.complete();
    if (platform.failUserUpdate) throw StateError('offline');
  }
}

class _FakeFunctionsPlatform extends FirebaseFunctionsPlatform {
  _FakeFunctionsPlatform(super.app, super.region, this.onCall);

  final void Function() onCall;

  @override
  FirebaseFunctionsPlatform delegateFor({FirebaseApp? app, required String region}) =>
      _FakeFunctionsPlatform(app, region, onCall);

  @override
  HttpsCallablePlatform httpsCallable(String? origin, String name, HttpsCallableOptions options) =>
      _FakeHttpsCallable(this, origin, name, options, null, onCall);

  @override
  HttpsCallablePlatform httpsCallableWithUri(String? origin, Uri uri, HttpsCallableOptions options) =>
      _FakeHttpsCallable(this, origin, null, options, uri, onCall);
}

class _FakeHttpsCallable extends HttpsCallablePlatform {
  _FakeHttpsCallable(super.functions, super.origin, super.name, super.options, super.uri, this.onCall);

  final void Function() onCall;

  @override
  Future<dynamic> call([dynamic parameters]) async {
    onCall();
    return const <String, Object>{'success': true, 'changed': false};
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _FakeFirestorePlatform firestore;
  var rewardCalls = 0;
  late PrismUsersV2 originalUser;
  const MethodChannel toastChannel = MethodChannel('PonnamKarthik/fluttertoast');
  const MethodChannel pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
    firestore = _FakeFirestorePlatform();
    FirebaseFirestorePlatform.instance = firestore;
    FirebaseFunctionsPlatform.instance = _FakeFunctionsPlatform(null, 'asia-south1', () => rewardCalls++);
    await getIt.reset();
    getIt.registerSingleton<SettingsLocalDataSource>(SettingsLocalDataSource(InMemoryLocalStore()));
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      toastChannel,
      (MethodCall call) async => true,
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      pathProviderChannel,
      (MethodCall call) async => Directory.systemTemp.path,
    );
  });

  setUp(() {
    originalUser = app_state.prismUser;
    final PrismUsersV2 user = app_constants.createGuestPrismUser()
      ..id = 'uploader'
      ..loggedIn = true;
    app_state.prismUser = user;
    firestore.updatedPaths.clear();
    firestore.failUserUpdate = false;
    firestore.wallWriteStarted = null;
    firestore.allowWallWrite = null;
    firestore.userUpdateAttempted = null;
    rewardCalls = 0;
  });

  tearDown(() {
    app_state.prismUser = originalUser;
  });

  tearDownAll(() async {
    await getIt.reset();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(toastChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      pathProviderChannel,
      null,
    );
  });

  test('quota sync failure does not fail createRecord after the wall has been saved', () async {
    firestore.failUserUpdate = true;
    firestore.userUpdateAttempted = Completer<void>();
    final result = await createRecord('wall-id', null, null, null, null, null, null, null, null, false);
    await firestore.userUpdateAttempted!.future;

    expect(result, WallSubmissionResult.submitted);
    expect(firestore.updatedPaths, contains('usersv2/uploader'));
    expect(rewardCalls, 1);
  });

  test('quota sync and reward stay with the submitting account after an account switch', () async {
    firestore.wallWriteStarted = Completer<void>();
    firestore.allowWallWrite = Completer<void>();
    final Future<WallSubmissionResult> submission = createRecord(
      'wall-id',
      null,
      null,
      null,
      null,
      null,
      null,
      null,
      null,
      false,
    );
    await firestore.wallWriteStarted!.future;
    app_state.prismUser = app_constants.createGuestPrismUser()
      ..id = 'other-account'
      ..loggedIn = true;
    firestore.allowWallWrite!.complete();

    expect(await submission, WallSubmissionResult.submitted);
    expect(firestore.updatedPaths, contains('usersv2/uploader'));
    expect(firestore.updatedPaths, isNot(contains('usersv2/other-account')));
    expect(rewardCalls, 0);
    expect(app_state.prismUser.uploadsThisWeek, 0);
  });
}
