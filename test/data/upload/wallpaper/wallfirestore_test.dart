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
      hasFreeQuota: false,
      consumeFreeQuota: () => consumedQuota = true,
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
    when(() => firestoreClient.addDoc(any(), any(), sourceTag: any(named: 'sourceTag'))).thenThrow(saveError);

    await expectLater(
      submitWallRecord(
        isPremium: false,
        hasFreeQuota: true,
        consumeFreeQuota: () => consumedQuota = true,
        firestoreClient: firestoreClient,
        record: const <String, dynamic>{'id': 'wall-id'},
        awardFirstUpload: () async => awardedUpload = true,
      ),
      throwsA(same(saveError)),
    );

    expect(consumedQuota, isFalse);
    expect(awardedUpload, isFalse);
  });

  test('reward failures do not change a saved submission outcome', () async {
    final firestoreClient = _MockFirestoreClient();
    when(
      () => firestoreClient.addDoc(any(), any(), sourceTag: any(named: 'sourceTag')),
    ).thenAnswer((_) async => 'doc-id');

    final result = await submitWallRecord(
      isPremium: true,
      hasFreeQuota: true,
      consumeFreeQuota: () {},
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
      hasFreeQuota: true,
      consumeFreeQuota: () => calls.add('quota'),
      firestoreClient: firestoreClient,
      record: const <String, dynamic>{'id': 'wall-id'},
      awardFirstUpload: () async => calls.add('reward'),
    );

    expect(result, WallSubmissionResult.submitted);
    expect(calls, <String>['saved', 'quota', 'reward']);
  });
}
