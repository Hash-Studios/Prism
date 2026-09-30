import 'package:Prism/core/firestore/firestore_query_specs.dart';
import 'package:Prism/features/user_search/data/repositories/user_search_repository_impl.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_firestore_client.dart';

void main() {
  test('a blank query does not hit Firestore', () async {
    final firestore = FakeFirestoreClient();

    final result = await UserSearchRepositoryImpl(firestore).searchUsers('   ');

    expect(result.data, isEmpty);
    expect(firestore.querySpecs, isEmpty);
  });

  test('prefix-searches name and username, and lists a user found by both once', () async {
    final firestore = FakeFirestoreClient(
      onQuery: (spec) {
        final field = spec.filters.first.field;
        return <FakeDocRow>[
          (
            id: 'doc_kevin',
            data: <String, dynamic>{
              'name': 'Kevin',
              'username': 'kevin',
              'email': 'kevin@x.com',
              'followers': <String>['a@x.com', 'b@x.com'],
            },
          ),
          if (field == 'username') (id: 'doc_kev2', data: <String, dynamic>{'id': 'kev2', 'username': 'kev2'}),
        ];
      },
    );

    final result = await UserSearchRepositoryImpl(firestore).searchUsers(' kev ');

    expect(firestore.querySpecs.map((spec) => spec.filters.first.field), <String>['name', 'username']);
    for (final spec in firestore.querySpecs) {
      expect(spec.filters.map((f) => f.op), <FirestoreFilterOp>[
        FirestoreFilterOp.isGreaterThanOrEqualTo,
        FirestoreFilterOp.isLessThanOrEqualTo,
      ]);
      expect(spec.filters.first.value, 'kev');
    }
    final users = result.data!;
    expect(users.map((user) => user.id), <String>['doc_kevin', 'kev2']);
    expect(users.first.followerCount, 2);
    expect(users.first.email, 'kevin@x.com');
  });

  test('a failed query becomes a failure result', () async {
    final firestore = FakeFirestoreClient()..queryError = StateError('offline');

    final result = await UserSearchRepositoryImpl(firestore).searchUsers('kev');

    expect(result.isFailure, isTrue);
  });
}
