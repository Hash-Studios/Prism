import 'dart:async';

import 'package:Prism/core/firestore/firestore_client.dart';
import 'package:Prism/data/upload/wallpaper/wall_submission.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockFirestoreClient extends Mock implements FirestoreClient {}

void main() {
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
}
