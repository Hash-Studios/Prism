import 'package:Prism/core/firestore/firestore_query_specs.dart';
import 'package:Prism/features/user_search/data/repositories/user_search_repository_impl.dart';
import 'package:Prism/features/user_search/domain/entities/user_search_user.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_firestore_client.dart';
import '../../support/fake_user_block_repository.dart';

UserSearchRepositoryImpl _repo(FakeFirestoreClient firestore, {Set<String> blocked = const <String>{}}) =>
    UserSearchRepositoryImpl(firestore, FakeUserBlockRepository.pending()..completeInitial(blocked));

void main() {
  test('a blank query does not hit Firestore', () async {
    final firestore = FakeFirestoreClient();

    final result = await _repo(firestore).searchUsers('   ');

    expect(result.data, isEmpty);
    expect(firestore.querySpecs, isEmpty);
  });

  test('prefix-searches both name fields and the lowercase username, and lists a user found by all once', () async {
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
          if (field == 'usernameLower') (id: 'doc_kev2', data: <String, dynamic>{'id': 'kev2', 'username': 'kev2'}),
        ];
      },
    );

    final result = await _repo(firestore).searchUsers(' kev ');

    expect(firestore.querySpecs.map((spec) => spec.filters.first.field), <String>[
      'nameLower',
      'name',
      'usernameLower',
    ]);
    for (final spec in firestore.querySpecs) {
      expect(spec.filters.map((f) => f.op), <FirestoreFilterOp>[
        FirestoreFilterOp.isGreaterThanOrEqualTo,
        FirestoreFilterOp.isLessThanOrEqualTo,
      ]);
    }
    expect(firestore.querySpecs.map((spec) => spec.filters.first.value), <String>['kev', 'kev', 'kev']);
    final users = result.data!;
    expect(users.map((user) => user.id), <String>['doc_kevin', 'kev2']);
    expect(users.first.followerCount, 2);
    expect(users.first.email, 'kevin@x.com');
  });

  test('a failed query becomes a failure result', () async {
    final firestore = FakeFirestoreClient()..queryError = StateError('offline');

    final result = await _repo(firestore).searchUsers('kev');

    expect(result.isFailure, isTrue);
  });

  test(
    'a mixed-case query searches the lowercase fields with lowercased text and keeps the typed case for name',
    () async {
      final firestore = FakeFirestoreClient();

      await _repo(firestore).searchUsers('KeViN');

      final byField = {for (final spec in firestore.querySpecs) spec.filters.first.field: spec.filters.first.value};
      expect(byField, <String, Object?>{'nameLower': 'kevin', 'name': 'KeViN', 'usernameLower': 'kevin'});
    },
  );

  test('"john" finds a creator saved as "John", through nameLower', () async {
    final firestore = FakeFirestoreClient(
      onQuery: (spec) => spec.filters.first.field == 'nameLower'
          ? <FakeDocRow>[
              (id: 'd1', data: <String, dynamic>{'name': 'John', 'nameLower': 'john'}),
            ]
          : const <FakeDocRow>[],
    );

    final result = await _repo(firestore).searchUsers('john');

    expect(result.data!.map((UserSearchUser u) => u.name), <String>['John']);
  });

  test('creators the user blocked never show up in the results', () async {
    final firestore = FakeFirestoreClient(
      onQuery: (spec) => <FakeDocRow>[
        (id: 'd1', data: <String, dynamic>{'name': 'Kev', 'username': 'kev', 'email': 'Blocked@X.com'}),
        (id: 'd2', data: <String, dynamic>{'name': 'Kevin', 'username': 'kevin', 'email': 'ok@x.com'}),
      ],
    );

    final result = await _repo(firestore, blocked: <String>{'blocked@x.com'}).searchUsers('kev');

    expect(result.data!.map((UserSearchUser u) => u.id), <String>['d2']);
  });
}
