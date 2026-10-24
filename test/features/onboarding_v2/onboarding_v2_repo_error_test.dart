// ignore_for_file: subtype_of_sealed_class, avoid_implementing_value_types

import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/analytics/events/events.dart';
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
import '../../support/fake_app_analytics.dart';

import '../../support/in_memory_local_store.dart';

class _MockFirebaseFirestore extends Mock implements FirebaseFirestore {}

class _MockCollectionReference extends Mock implements CollectionReference<Map<String, dynamic>> {}

class _MockDocumentReference extends Mock implements DocumentReference<Map<String, dynamic>> {}

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
  late List<(String, bool)> followCalls;
  late List<Object> followErrors;
  late _FirestoreTelemetrySink telemetry;
  late _MockFirebaseRemoteConfig remoteConfig;
  late InMemoryLocalStore store;
  late OnboardingV2RepositoryImpl repository;

  setUp(() {
    AnalyticsRuntime.reset();
    firestore = _MockFirebaseFirestore();
    users = _MockCollectionReference();
    user = _MockDocumentReference();
    creator = _MockDocumentReference();
    followCalls = <(String, bool)>[];
    followErrors = <Object>[];
    telemetry = const _FirestoreTelemetrySink();
    remoteConfig = _MockFirebaseRemoteConfig();
    store = InMemoryLocalStore();

    when(() => firestore.collection('usersv2')).thenReturn(users);
    when(() => users.doc('user-1')).thenReturn(user);
    when(() => users.doc('creator-1')).thenReturn(creator);
    when(() => users.doc('missing-user')).thenReturn(user);
    when(() => remoteConfig.getString(any())).thenReturn('');

    repository = OnboardingV2RepositoryImpl(
      FirestoreTrackedClient(firestore, telemetry),
      SettingsLocalDataSource(store),
      remoteConfig: remoteConfig,
      setFollow: (String uid, bool following) async {
        followCalls.add((uid, following));
        if (followErrors.isNotEmpty) throw followErrors.removeAt(0);
      },
    );
  });

  tearDown(AnalyticsRuntime.reset);

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

  test('saveInterests returns an unmapped failure for an empty user id before writing', () async {
    when(() => users.doc('')).thenThrow(ArgumentError.value('', 'path', 'must be nonempty'));

    final result = await repository.saveInterests(userId: '', interests: const <String>['Nature']);

    expect(result.failure, isA<ServerFailure>().having((failure) => failure.code, 'code', isNull));
    expect(store.data, isEmpty);
    verifyNever(() => user.update(any()));
  });

  test('followCreators preserves the Firebase error code and writes no local completion', () async {
    followErrors.add(FirebaseException(plugin: 'cloud_functions', code: 'unauthenticated', message: 'auth required'));

    final result = await repository.followCreators(
      currentUserId: 'user-1',
      currentUserEmail: 'user@example.com',
      creators: <OnboardingStarterCreatorEntity>[_creator()],
    );

    expect(result.failure, isA<ServerFailure>().having((failure) => failure.code, 'code', 'unauthenticated'));
    expect(store.data, isEmpty);
    expect(followCalls, <(String, bool)>[('creator-1', true)]);
  });

  test('followCreators returns an unmapped failure for an empty user id before calling setFollow', () async {
    final result = await repository.followCreators(
      currentUserId: '',
      currentUserEmail: 'user@example.com',
      creators: <OnboardingStarterCreatorEntity>[_creator()],
    );

    expect(result.failure, isA<ServerFailure>().having((failure) => failure.code, 'code', isNull));
    expect(store.data, isEmpty);
    expect(followCalls, isEmpty);
  });

  test('a failed follow can be retried and only records local completion after success', () async {
    final FakeAppAnalytics recorder = FakeAppAnalytics();
    AnalyticsRuntime.instance = recorder;
    followErrors.add(FirebaseException(plugin: 'cloud_functions', code: 'unavailable', message: 'try again'));

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
    await AnalyticsRuntime.instance.flush();
    final List<FollowResultEvent> follows = recorder.events.whereType<FollowResultEvent>().toList();
    expect(follows.map((event) => event.result), <String>['failure', 'success']);
    expect(follows.map((event) => event.creatorId).toSet(), <String>{'creator-1'});
    expect(follows.map((event) => event.source).toSet(), <String>{'onboarding_starter_pack'});
    expect(follows.expand((event) => event.toWireParameters().values), isNot(contains('creator@example.com')));
    expect(store.data.values, contains('creator-1'));
    expect(followCalls, <(String, bool)>[('creator-1', true), ('creator-1', true)]);
  });

  test('an empty creator selection succeeds and stores an empty selection', () async {
    final result = await repository.followCreators(
      currentUserId: 'user-1',
      currentUserEmail: 'user@example.com',
      creators: const <OnboardingStarterCreatorEntity>[],
    );

    expect(result.isSuccess, isTrue);
    expect(store.data.values, contains(''));
    expect(followCalls, isEmpty);
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

  test('completeOnboarding returns an unmapped failure for an empty user id before writing', () async {
    when(() => users.doc('')).thenThrow(ArgumentError.value('', 'path', 'must be nonempty'));

    final Result<void> result = await repository.completeOnboarding(userId: '');

    expect(result.failure, isA<ServerFailure>().having((failure) => failure.code, 'code', isNull));
    expect(store.data, isEmpty);
    verifyNever(() => user.update(any()));
  });
}
