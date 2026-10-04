// ignore_for_file: subtype_of_sealed_class, avoid_implementing_value_types

import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/firestore/firestore_error.dart';
import 'package:Prism/core/firestore/firestore_telemetry.dart';
import 'package:Prism/core/firestore/firestore_tracked_client.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/features/onboarding_v2/src/data/repo/onboarding_v2_repo_impl.dart';
import 'package:Prism/features/onboarding_v2/src/domain/entities/onboarding_starter_creator_entity.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../support/in_memory_local_store.dart';

class _MockFirebaseFirestore extends Mock implements FirebaseFirestore {}

class _MockCollectionReference extends Mock implements CollectionReference<Map<String, dynamic>> {}

class _MockDocumentReference extends Mock implements DocumentReference<Map<String, dynamic>> {}

class _MockWriteBatch extends Mock implements WriteBatch {
  final List<(Object, Object)> updates = <(Object, Object)>[];

  @override
  void update<T>(DocumentReference<T> documentReference, T data) {
    updates.add((documentReference as Object, data as Object));
  }
}

class _FirestoreTelemetrySink implements FirestoreTelemetrySink {
  const _FirestoreTelemetrySink();

  @override
  Future<void> emit(FirestoreTelemetryEvent event) async {}
}

class _MockFirebaseRemoteConfig extends Mock implements FirebaseRemoteConfig {}

OnboardingStarterCreatorEntity _creator() => const OnboardingStarterCreatorEntity(
  userId: 'creator-1',
  email: 'creator@example.com',
  name: 'Creator',
  photoUrl: '',
  previewUrls: <String>[],
  rank: 0,
  followerCount: 0,
);

void main() {
  late _MockFirebaseFirestore firestore;
  late _MockCollectionReference users;
  late _MockDocumentReference user;
  late _MockDocumentReference creator;
  late _MockWriteBatch batch;
  late _FirestoreTelemetrySink telemetry;
  late _MockFirebaseRemoteConfig remoteConfig;
  late InMemoryLocalStore store;
  late OnboardingV2RepositoryImpl repository;

  setUp(() {
    firestore = _MockFirebaseFirestore();
    users = _MockCollectionReference();
    user = _MockDocumentReference();
    creator = _MockDocumentReference();
    batch = _MockWriteBatch();
    telemetry = const _FirestoreTelemetrySink();
    remoteConfig = _MockFirebaseRemoteConfig();
    store = InMemoryLocalStore();

    when(() => firestore.collection('usersv2')).thenReturn(users);
    when(() => users.doc('user-1')).thenReturn(user);
    when(() => users.doc('creator-1')).thenReturn(creator);
    when(() => users.doc('missing-user')).thenReturn(user);
    when(() => firestore.batch()).thenReturn(batch);
    when(() => batch.commit()).thenAnswer((_) async {});
    when(() => remoteConfig.getString(any())).thenReturn('');

    repository = OnboardingV2RepositoryImpl(
      remoteConfig,
      FirestoreTrackedClient(firestore, telemetry),
      SettingsLocalDataSource(store),
    );
  });

  test('saveInterests preserves the Firebase update error code', () async {
    when(
      () => user.update(any()),
    ).thenThrow(FirebaseException(plugin: 'cloud_firestore', code: 'permission-denied', message: 'write denied'));

    final result = await repository.saveInterests(userId: 'user-1', interests: const <String>['Nature']);

    expect(result.failure, isA<ServerFailure>().having((failure) => failure.code, 'code', 'permission-denied'));
    expect(store.data, isEmpty);
    verify(() => firestore.collection(any())).called(1);
  });

  test('saveInterests preserves an already-mapped Firestore error code', () async {
    when(() => user.update(any())).thenThrow(FirestoreError(code: 'not-found', message: 'user missing'));

    final result = await repository.saveInterests(userId: 'user-1', interests: const <String>['Nature']);

    expect(result.failure, isA<ServerFailure>().having((failure) => failure.code, 'code', 'not-found'));
    expect(store.data, isEmpty);
  });

  test('followCreators preserves the Firebase batch commit error code', () async {
    when(
      () => batch.commit(),
    ).thenThrow(FirebaseException(plugin: 'cloud_firestore', code: 'unauthenticated', message: 'auth required'));

    final result = await repository.followCreators(
      currentUserId: 'user-1',
      currentUserEmail: 'user@example.com',
      creators: <OnboardingStarterCreatorEntity>[_creator()],
    );

    expect(result.failure, isA<ServerFailure>().having((failure) => failure.code, 'code', 'unauthenticated'));
    expect(store.data, isEmpty);
    verify(() => batch.commit()).called(1);
  });

  test('a failed batch can be retried and only records local completion after success', () async {
    int commitAttempts = 0;
    when(() => batch.commit()).thenAnswer((_) async {
      commitAttempts++;
      if (commitAttempts == 1) {
        throw FirebaseException(plugin: 'cloud_firestore', code: 'unavailable', message: 'try again');
      }
    });

    final firstAttempt = await repository.followCreators(
      currentUserId: 'user-1',
      currentUserEmail: 'user@example.com',
      creators: <OnboardingStarterCreatorEntity>[_creator()],
    );
    expect(firstAttempt.failure, isA<ServerFailure>().having((failure) => failure.code, 'code', 'unavailable'));
    expect(store.data, isEmpty);

    final retry = await repository.followCreators(
      currentUserId: 'user-1',
      currentUserEmail: 'user@example.com',
      creators: <OnboardingStarterCreatorEntity>[_creator()],
    );

    expect(retry.isSuccess, isTrue);
    expect(store.data.values, contains('creator@example.com'));
    verify(() => batch.commit()).called(2);
    expect(batch.updates, hasLength(4));
    expect(batch.updates.map((update) => update.$1), <Object>[user, creator, user, creator]);
    expect(batch.updates.map((update) => (update.$2 as Map<String, dynamic>).keys.toList()), <List<String>>[
      <String>['following'],
      <String>['followers'],
      <String>['following'],
      <String>['followers'],
    ]);
    expect((batch.updates[0].$2 as Map<String, dynamic>)['following'], isA<FieldValue>());
    expect((batch.updates[2].$2 as Map<String, dynamic>)['following'], isA<FieldValue>());
  });

  test('an empty creator selection succeeds and stores an empty selection', () async {
    final result = await repository.followCreators(
      currentUserId: 'user-1',
      currentUserEmail: 'user@example.com',
      creators: const <OnboardingStarterCreatorEntity>[],
    );

    expect(result.isSuccess, isTrue);
    expect(store.data.values, contains(''));
    verify(() => batch.commit()).called(1);
    expect(batch.updates, hasLength(1));
  });

  test('completeOnboarding preserves the Firebase update error code', () async {
    when(
      () => user.update(any()),
    ).thenThrow(FirebaseException(plugin: 'cloud_firestore', code: 'not-found', message: 'user missing'));

    final Result<void> result = await repository.completeOnboarding(userId: 'missing-user');

    expect(result.failure, isA<ServerFailure>().having((failure) => failure.code, 'code', 'not-found'));
    expect(store.data, isEmpty);
    expect(mapFirestoreError(FirebaseException(plugin: 'cloud_firestore', code: 'not-found')).code, 'not-found');
  });
}
