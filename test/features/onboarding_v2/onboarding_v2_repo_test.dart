import 'package:Prism/core/firestore/firestore_collections.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
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

  setUp(() {
    firestore = FakeFirestoreClient();
    repository = OnboardingV2RepositoryImpl(
      _MockRemoteConfig(),
      firestore,
      SettingsLocalDataSource(InMemoryLocalStore()),
    );
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
}
