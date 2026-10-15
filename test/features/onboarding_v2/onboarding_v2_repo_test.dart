import 'package:Prism/core/firestore/firestore_collections.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/features/onboarding_v2/src/common/onboarding_v2_keys.dart';
import 'package:Prism/features/onboarding_v2/src/data/repo/onboarding_v2_repo_impl.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../support/fake_firestore_client.dart';
import '../../support/in_memory_local_store.dart';

class _MockRemoteConfig extends Mock implements FirebaseRemoteConfig {}

void main() {
  late FakeFirestoreClient firestore;
  late OnboardingV2RepositoryImpl repository;
  late SettingsLocalDataSource settings;

  setUp(() {
    firestore = FakeFirestoreClient();
    settings = SettingsLocalDataSource(InMemoryLocalStore());
    repository = OnboardingV2RepositoryImpl(_MockRemoteConfig(), firestore, settings);
  });

  test('a user doc with onboardingV2.completed true is reported as completed', () async {
    firestore.docs[FirebaseCollections.usersV2] = <String, Map<String, dynamic>>{
      'u1': <String, dynamic>{
        'onboardingV2': <String, dynamic>{'completed': true},
      },
    };

    final status = (await repository.fetchUserCompletionStatus(userId: 'u1')).data!;

    expect(status.completed, isTrue);
    expect(status.hasInterests, isFalse);
    expect(status.hasFollows, isFalse);
  });

  test('a user doc without the onboarding map is not completed', () async {
    firestore.docs[FirebaseCollections.usersV2] = <String, Map<String, dynamic>>{
      'u1': <String, dynamic>{
        'interestCategories': <String>['a', 'b', 'c'],
      },
    };

    final status = (await repository.fetchUserCompletionStatus(userId: 'u1')).data!;

    expect(status.completed, isFalse);
    expect(status.hasInterests, isTrue);
  });

  group('syncLocalInterests', () {
    test('guest picks go to an account that has fewer than the minimum interests', () async {
      await settings.set(OnboardingV2Keys.selectedInterests, 'Nature,Anime,Minimal');
      firestore.docs[FirebaseCollections.usersV2] = <String, Map<String, dynamic>>{
        'u1': <String, dynamic>{
          'interestCategories': <String>['Space'],
        },
      };

      final result = await repository.syncLocalInterests(userId: 'u1');

      expect(result.isSuccess, isTrue);
      final write = firestore.writes.single;
      expect(write.id, 'u1');
      expect(write.data?['interestCategories'], <String>['Nature', 'Anime', 'Minimal']);
      expect(write.data?['onboardingV2.selectedInterests'], <String>['Nature', 'Anime', 'Minimal']);
    });

    test('a new account gets the guest picks', () async {
      await settings.set(OnboardingV2Keys.selectedInterests, 'Nature,Anime,Minimal');
      firestore.docs[FirebaseCollections.usersV2] = <String, Map<String, dynamic>>{'u1': <String, dynamic>{}};

      await repository.syncLocalInterests(userId: 'u1');

      expect(firestore.docs[FirebaseCollections.usersV2]!['u1']!['interestCategories'], <String>[
        'Nature',
        'Anime',
        'Minimal',
      ]);
    });

    test('an account with enough interests wins and the device copy follows it', () async {
      await settings.set(OnboardingV2Keys.selectedInterests, 'Nature,Anime,Minimal');
      firestore.docs[FirebaseCollections.usersV2] = <String, Map<String, dynamic>>{
        'u1': <String, dynamic>{
          'interestCategories': <String>['Space', 'Cars', 'Art'],
        },
      };

      await repository.syncLocalInterests(userId: 'u1');

      expect(firestore.writes, isEmpty);
      expect(settings.get<String>(OnboardingV2Keys.selectedInterests, defaultValue: ''), 'Space,Cars,Art');
    });

    test('nothing is written when the device has no picks', () async {
      firestore.docs[FirebaseCollections.usersV2] = <String, Map<String, dynamic>>{'u1': <String, dynamic>{}};

      final result = await repository.syncLocalInterests(userId: 'u1');

      expect(result.isSuccess, isTrue);
      expect(firestore.writes, isEmpty);
    });

    test('a failed read is reported as an error instead of throwing', () async {
      await settings.set(OnboardingV2Keys.selectedInterests, 'Nature,Anime,Minimal');
      final failing = OnboardingV2RepositoryImpl(_MockRemoteConfig(), _ThrowingFirestoreClient(), settings);

      final result = await failing.syncLocalInterests(userId: 'u1');

      expect(result.isFailure, isTrue);
    });
  });
}

class _ThrowingFirestoreClient extends FakeFirestoreClient {
  @override
  Future<T?> getById<T>(
    String collection,
    String id,
    T Function(Map<String, dynamic> data, String docId) map, {
    required String sourceTag,
    bool preferCacheFirst = false,
  }) => throw StateError('offline');
}
