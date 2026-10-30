// Firebase platform-interface packages are transitive, but these fakes need them.
// ignore_for_file: depend_on_referenced_packages

import 'dart:async';
import 'dart:io';

import 'package:Prism/auth/user_model.dart';
import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/constants/app_constants.dart' as app_constants;
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/firestore/firestore_client.dart';
import 'package:Prism/core/firestore/firestore_telemetry.dart';
import 'package:Prism/core/firestore/firestore_tracked_client.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/utils/json_utils.dart';
import 'package:Prism/data/upload/wallpaper/wallfirestore.dart';
import 'package:cloud_firestore/cloud_firestore.dart' show FirebaseFirestore;
import 'package:cloud_firestore_platform_interface/cloud_firestore_platform_interface.dart';
import 'package:cloud_functions_platform_interface/cloud_functions_platform_interface.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/in_memory_local_store.dart';

class _FakeFirestorePlatform extends FirebaseFirestorePlatform {
  final List<String> updatedPaths = <String>[];
  Map<String, dynamic>? savedWall;
  String? savedWallPath;
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
  Future<DocumentSnapshotPlatform> get([GetOptions options = const GetOptions()]) async => DocumentSnapshotPlatform(
    firestore,
    path,
    null,
    InternalSnapshotMetadata(hasPendingWrites: false, isFromCache: false),
  );

  @override
  Future<void> set(Map<String, dynamic> data, [SetOptions? options]) async {
    final _FakeFirestorePlatform platform = firestore as _FakeFirestorePlatform;
    if (path.startsWith('walls/')) {
      platform.savedWall = Map<String, dynamic>.of(data);
      platform.savedWallPath = path;
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

  final Object? Function(String? name, Object? parameters) onCall;

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

  final Object? Function(String? name, Object? parameters) onCall;

  @override
  Future<dynamic> call([dynamic parameters]) async => onCall(name, parameters);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _FakeFirestorePlatform firestore;
  final List<(String?, Map<String, dynamic>)> callableCalls = <(String?, Map<String, dynamic>)>[];
  Map<String, Object> awardReply = const <String, Object>{'success': true, 'changed': false};
  late PrismUsersV2 originalUser;
  const MethodChannel toastChannel = MethodChannel('PonnamKarthik/fluttertoast');
  const MethodChannel pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
    firestore = _FakeFirestorePlatform();
    FirebaseFirestorePlatform.instance = firestore;
    FirebaseFunctionsPlatform.instance = _FakeFunctionsPlatform(null, 'asia-south1', (name, parameters) {
      callableCalls.add((name, toJsonMap(parameters)));
      return switch (name) {
        // A deployed older award reply requests XP reconciliation even when this reward was already claimed.
        'awardCoins' => awardReply,
        'reconcileRankRewards' => const <String, Object>{'success': true, 'inventoryChanged': false},
        _ => throw StateError('Unexpected callable: $name'),
      };
    });
    await getIt.reset();
    getIt.registerSingleton<SettingsLocalDataSource>(SettingsLocalDataSource(InMemoryLocalStore()));
    getIt.registerSingleton<FirestoreClient>(
      FirestoreTrackedClient(FirebaseFirestore.instance, const FirestoreConsoleTelemetrySink()),
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      toastChannel,
      (MethodCall call) async => true,
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      pathProviderChannel,
      (MethodCall call) async => Directory.systemTemp.path,
    );
  });

  setUp(() async {
    await getIt<SettingsLocalDataSource>().delete('uploadsWeekStart');
    await getIt<SettingsLocalDataSource>().delete('uploadsThisWeek');
    originalUser = app_state.prismUser;
    final PrismUsersV2 user = app_constants.createGuestPrismUser()
      ..id = 'uploader'
      ..loggedIn = true;
    app_state.prismUser = user;
    CoinsService.instance.resetSession();
    firestore.updatedPaths.clear();
    firestore.savedWall = null;
    firestore.savedWallPath = null;
    firestore.failUserUpdate = false;
    firestore.wallWriteStarted = null;
    firestore.allowWallWrite = null;
    firestore.userUpdateAttempted = null;
    callableCalls.clear();
    awardReply = const <String, Object>{'success': true, 'changed': false};
  });

  tearDown(() async {
    await pumpEventQueue();
    CoinsService.instance.resetSession();
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

  test('private upload persists an empty original and its opaque original path', () async {
    const thumb = 'https://example.test/preview.jpg';
    final result = await createRecord(
      'protected-wall',
      'Prism',
      thumb,
      '',
      null,
      null,
      null,
      null,
      null,
      false,
      wallpaperPath: 'private/original.jpg',
      wallpaperSha: 'original-sha',
    );
    expect(result, WallSubmissionResult.submitted);
    expect(firestore.savedWall!['wallpaper_url'], isEmpty);
    expect(firestore.savedWall!['wallpaper_thumb'], thumb);
    expect(firestore.savedWall!.values, contains('private/original.jpg'));
  });

  test('quota sync failure does not fail createRecord after the wall has been saved', () async {
    firestore.failUserUpdate = true;
    firestore.userUpdateAttempted = Completer<void>();
    final result = await createRecord('wall-id', null, null, null, null, null, null, null, null, false);
    await firestore.userUpdateAttempted!.future;
    await pumpEventQueue();

    expect(result, WallSubmissionResult.submitted);
    expect(firestore.updatedPaths, contains('usersv2/uploader'));
    final List<Map<String, dynamic>> awards = <Map<String, dynamic>>[
      for (final (name, parameters) in callableCalls)
        if (name == 'awardCoins') parameters,
    ];
    expect(awards, hasLength(1));
    expect(awards.single['action'], 'firstWallpaperUpload');
    expect(awards.single['sourceTag'], 'coins.first_wallpaper_upload');
    final List<Map<String, dynamic>> reconciliations = <Map<String, dynamic>>[
      for (final (name, parameters) in callableCalls)
        if (name == 'reconcileRankRewards') parameters,
    ];
    expect(reconciliations, hasLength(1));
    expect(reconciliations.single['sourceTag'], 'coins.rank_rewards.reconcile');
  });

  test('challenge upload keeps its stable wall ID and server-confirmed reward receipt', () async {
    awardReply = const <String, Object>{
      'success': true,
      'changed': true,
      'previousBalance': 30,
      'currentBalance': 37,
      'delta': 7,
      'transactionId': 'server-upload-receipt',
    };
    CoinMutationResult? receipt;

    final result = await createRecord(
      'challenge-wall',
      'Prism',
      null,
      null,
      null,
      null,
      null,
      null,
      null,
      false,
      docId: 'wall_challenge-wall',
      challengeId: 'weekly-theme',
      onUploadAward: (result) => receipt = result,
    );

    expect(result, WallSubmissionResult.submitted);
    expect(firestore.savedWallPath, 'walls/wall_challenge-wall');
    expect(firestore.savedWall!['id'], 'challenge-wall');
    expect(firestore.savedWall!['challengeId'], 'weekly-theme');
    expect(receipt, isNotNull);
    expect(receipt!.delta, 7);
    expect(receipt!.currentBalance, 37);
    expect(receipt!.transactionId, 'server-upload-receipt');
    expect(app_state.prismUser.coins, 37);
    expect(callableCalls.where((call) => call.$1 == 'awardCoins'), hasLength(1));
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
    await pumpEventQueue();
    expect(firestore.updatedPaths, contains('usersv2/uploader'));
    expect(firestore.updatedPaths, isNot(contains('usersv2/other-account')));
    expect(callableCalls, isEmpty);
    expect(app_state.prismUser.uploadsThisWeek, 0);
  });
}
