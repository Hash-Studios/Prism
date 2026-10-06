import 'dart:async';

import 'package:Prism/core/constants/app_constants.dart' as app_constants;
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/firestore/firestore_client.dart';
import 'package:Prism/core/firestore/firestore_error.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/data/upload/wallpaper/wall_submission.dart';
import 'package:Prism/data/upload/wallpaper/wallfirestore.dart' as wallfirestore;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../support/in_memory_local_store.dart';

class _MockFirestoreClient extends Mock implements FirestoreClient {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const MethodChannel toastChannel = MethodChannel('PonnamKarthik/fluttertoast');

  test('quota-exceeded wall submission reports an error haptic', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final List<Object?> hapticTypes = <Object?>[];
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'HapticFeedback.vibrate') hapticTypes.add(call.arguments);
      return null;
    });
    messenger.setMockMethodCallHandler(toastChannel, (_) async => true);
    addTearDown(() {
      messenger.setMockMethodCallHandler(SystemChannels.platform, null);
      messenger.setMockMethodCallHandler(toastChannel, null);
    });
    await getIt.reset();
    addTearDown(getIt.reset);
    final SettingsLocalDataSource settings = SettingsLocalDataSource(InMemoryLocalStore());
    getIt.registerSingleton<SettingsLocalDataSource>(settings);
    final _MockFirestoreClient firestoreClient = _MockFirestoreClient();
    getIt.registerSingleton<FirestoreClient>(firestoreClient);
    app_state.prismUser = app_constants.createGuestPrismUser()..id = 'quota-test-user';
    addTearDown(() => app_state.prismUser = app_constants.createGuestPrismUser());
    final DateTime now = DateTime(2026, 10);
    final DateTime local = now.toLocal();
    final DateTime weekStart = DateTime(
      local.year,
      local.month,
      local.day,
    ).subtract(Duration(days: local.weekday - DateTime.monday));
    await settings.set('uploadsWeekStart', weekStart.toIso8601String());
    await settings.set('uploadsThisWeek', 3);

    final WallSubmissionResult result = await wallfirestore.createRecord(
      'wall-id',
      'Pexels',
      'thumb',
      'wallpaper',
      '1080x1920',
      'large',
      'Title',
      'Nature',
      'Description',
      true,
      now: () => now,
    );

    expect(result, WallSubmissionResult.quotaExceeded);
    expect(hapticTypes, <Object?>['HapticFeedbackType.errorNotification']);
    verifyNever(() => firestoreClient.addDoc(any(), any(), sourceTag: any(named: 'sourceTag')));
  });

  test('quota exhaustion returns quotaExceeded without saving or consuming quota', () async {
    var consumedQuota = false;
    var awardedUpload = false;
    final firestoreClient = _MockFirestoreClient();

    final result = await submitWallRecord(
      isPremium: false,
      hasFreeQuota: () => false,
      consumeFreeQuota: () async => consumedQuota = true,
      firestoreClient: firestoreClient,
      record: const <String, dynamic>{'id': 'wall-id'},
      awardFirstUpload: () async => awardedUpload = true,
    );

    expect(result, WallSubmissionResult.quotaExceeded);
    expect(consumedQuota, isFalse);
    verifyNever(() => firestoreClient.addDoc(any(), any(), sourceTag: any(named: 'sourceTag')));
    expect(awardedUpload, isFalse);
  });

  test('save failures propagate and do not run the first-upload reward', () async {
    final saveError = StateError('firestore write failed');
    var consumedQuota = false;
    var awardedUpload = false;
    final firestoreClient = _MockFirestoreClient();
    var attempts = 0;
    when(() => firestoreClient.addDoc(any(), any(), sourceTag: any(named: 'sourceTag'))).thenAnswer((_) async {
      if (attempts++ == 0) {
        throw saveError;
      }
      return 'doc-id';
    });

    await expectLater(
      submitWallRecord(
        isPremium: false,
        hasFreeQuota: () => true,
        consumeFreeQuota: () async => consumedQuota = true,
        firestoreClient: firestoreClient,
        record: const <String, dynamic>{'id': 'wall-id'},
        awardFirstUpload: () async => awardedUpload = true,
      ),
      throwsA(same(saveError)),
    );

    expect(consumedQuota, isFalse);
    expect(awardedUpload, isFalse);

    expect(
      await submitWallRecord(
        isPremium: false,
        hasFreeQuota: () => true,
        consumeFreeQuota: () async {},
        firestoreClient: firestoreClient,
        record: const <String, dynamic>{'id': 'wall-id-2'},
        awardFirstUpload: () async {},
      ),
      WallSubmissionResult.submitted,
    );
  });

  test('reward failures do not change a saved submission outcome', () async {
    final firestoreClient = _MockFirestoreClient();
    when(
      () => firestoreClient.addDoc(any(), any(), sourceTag: any(named: 'sourceTag')),
    ).thenAnswer((_) async => 'doc-id');

    final result = await submitWallRecord(
      isPremium: true,
      hasFreeQuota: () => true,
      consumeFreeQuota: () async {},
      firestoreClient: firestoreClient,
      record: const <String, dynamic>{'id': 'wall-id'},
      awardFirstUpload: () async => throw StateError('reward callable failed'),
    );

    verify(() => firestoreClient.addDoc(any(), any(), sourceTag: 'upload.createWall')).called(1);
    expect(result, WallSubmissionResult.submitted);
  });

  test('free quota is consumed only after the wall record is saved', () async {
    final calls = <String>[];
    final firestoreClient = _MockFirestoreClient();
    when(() => firestoreClient.addDoc(any(), any(), sourceTag: any(named: 'sourceTag'))).thenAnswer((_) async {
      calls.add('saved');
      return 'doc-id';
    });

    final result = await submitWallRecord(
      isPremium: false,
      hasFreeQuota: () => true,
      consumeFreeQuota: () async => calls.add('quota'),
      firestoreClient: firestoreClient,
      record: const <String, dynamic>{'id': 'wall-id'},
      awardFirstUpload: () async => calls.add('reward'),
    );

    expect(result, WallSubmissionResult.submitted);
    expect(calls, <String>['saved', 'quota', 'reward']);
  });

  test('async quota bookkeeping failure does not turn a saved wall into a failed submission', () async {
    final firestoreClient = _MockFirestoreClient();
    when(
      () => firestoreClient.addDoc(any(), any(), sourceTag: any(named: 'sourceTag')),
    ).thenAnswer((_) async => 'doc-id');

    final result = await submitWallRecord(
      isPremium: false,
      hasFreeQuota: () => true,
      consumeFreeQuota: () async {
        await Future<void>.value();
        throw StateError('local quota storage failed');
      },
      firestoreClient: firestoreClient,
      record: const <String, dynamic>{'id': 'wall-id'},
      awardFirstUpload: () async {},
    );

    expect(result, WallSubmissionResult.submitted);
  });

  test('concurrent free submissions cannot consume the same final quota slot', () async {
    var hasQuota = true;
    var consumedQuota = 0;
    var savedWalls = 0;
    final gate = Completer<void>();
    final firestoreClient = _MockFirestoreClient();
    when(() => firestoreClient.addDoc(any(), any(), sourceTag: any(named: 'sourceTag'))).thenAnswer((_) async {
      savedWalls++;
      await gate.future;
      return 'doc-id';
    });

    final first = submitWallRecord(
      isPremium: false,
      hasFreeQuota: () => hasQuota,
      consumeFreeQuota: () async {
        consumedQuota++;
        hasQuota = false;
      },
      firestoreClient: firestoreClient,
      record: const <String, dynamic>{'id': 'wall-1'},
      awardFirstUpload: () async {},
    );
    final second = submitWallRecord(
      isPremium: false,
      hasFreeQuota: () => hasQuota,
      consumeFreeQuota: () async {
        consumedQuota++;
        hasQuota = false;
      },
      firestoreClient: firestoreClient,
      record: const <String, dynamic>{'id': 'wall-2'},
      awardFirstUpload: () async {},
    );

    await Future<void>.delayed(Duration.zero);
    expect(savedWalls, 1);
    gate.complete();

    expect(await first, WallSubmissionResult.submitted);
    expect(await second, WallSubmissionResult.quotaExceeded);
    expect(savedWalls, 1);
    expect(consumedQuota, 1);
  });

  test('a deterministic docId writes the wall with setDoc so a retry cannot duplicate it', () async {
    final firestoreClient = _MockFirestoreClient();
    _stubExistingWall(firestoreClient, null);
    when(
      () => firestoreClient.setDoc(
        any(),
        any(),
        any(),
        merge: any(named: 'merge'),
        sourceTag: any(named: 'sourceTag'),
      ),
    ).thenAnswer((_) async {});

    final result = await submitWallRecord(
      isPremium: true,
      hasFreeQuota: () => true,
      consumeFreeQuota: () async {},
      firestoreClient: firestoreClient,
      record: const <String, dynamic>{'id': 'wall-id', 'email': 'a@b.c'},
      awardFirstUpload: () async {},
      docId: 'wall_user_1_pic.jpg',
    );

    expect(result, WallSubmissionResult.submitted);
    verify(
      () => firestoreClient.setDoc('walls', 'wall_user_1_pic.jpg', any(), sourceTag: 'upload.createWall'),
    ).called(1);
    verifyNever(() => firestoreClient.addDoc(any(), any(), sourceTag: any(named: 'sourceTag')));
  });

  test('a retry after a committed first write does not overwrite the reviewed wall', () async {
    final firestoreClient = _MockFirestoreClient();
    _stubExistingWall(firestoreClient, <String, dynamic>{'email': 'a@b.c', 'review': true, 'reviewedAt': 'x'});
    var awarded = false;

    final result = await submitWallRecord(
      isPremium: true,
      hasFreeQuota: () => true,
      consumeFreeQuota: () async {},
      firestoreClient: firestoreClient,
      record: const <String, dynamic>{'id': 'wall-id', 'email': 'a@b.c', 'review': false},
      awardFirstUpload: () async => awarded = true,
      docId: 'wall_user_1_pic.jpg',
    );

    expect(result, WallSubmissionResult.submitted);
    expect(awarded, isTrue);
    verifyNever(
      () => firestoreClient.setDoc(
        any(),
        any(),
        any(),
        merge: any(named: 'merge'),
        sourceTag: any(named: 'sourceTag'),
      ),
    );
  });

  test('a missing wall reads as permission-denied and is then created', () async {
    final firestoreClient = _MockFirestoreClient();
    when(
      () => firestoreClient.getById<Map<String, dynamic>>(
        any(),
        any(),
        any(),
        sourceTag: any(named: 'sourceTag'),
        preferCacheFirst: any(named: 'preferCacheFirst'),
      ),
    ).thenThrow(FirestoreError(message: 'denied', code: 'permission-denied'));
    when(
      () => firestoreClient.setDoc(
        any(),
        any(),
        any(),
        merge: any(named: 'merge'),
        sourceTag: any(named: 'sourceTag'),
      ),
    ).thenAnswer((_) async {});

    await submitWallRecord(
      isPremium: true,
      hasFreeQuota: () => true,
      consumeFreeQuota: () async {},
      firestoreClient: firestoreClient,
      record: const <String, dynamic>{'id': 'wall-id', 'email': 'a@b.c'},
      awardFirstUpload: () async {},
      docId: 'wall_x',
    );

    verify(() => firestoreClient.setDoc('walls', 'wall_x', any(), sourceTag: 'upload.createWall')).called(1);
  });
}

void _stubExistingWall(_MockFirestoreClient client, Map<String, dynamic>? existing) {
  when(
    () => client.getById<Map<String, dynamic>>(
      any(),
      any(),
      any(),
      sourceTag: any(named: 'sourceTag'),
      preferCacheFirst: any(named: 'preferCacheFirst'),
    ),
  ).thenAnswer((_) async => existing);
}
