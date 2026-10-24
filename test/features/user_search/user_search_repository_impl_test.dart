import 'package:Prism/core/firestore/firestore_query_specs.dart';
import 'package:Prism/features/user_search/data/repositories/user_search_repository_impl.dart';
import 'package:Prism/features/user_search/domain/entities/user_search_user.dart';
import 'package:Prism/features/user_blocks/domain/repositories/user_block_repository.dart';
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

  test('searches public names and usernames, then resolves registered usernames through profiles', () async {
    final firestore = FakeFirestoreClient(
      docs: <String, Map<String, Map<String, dynamic>>>{
        'profiles': <String, Map<String, dynamic>>{
          'kev2': <String, dynamic>{'name': 'Kev', 'username': 'kev2', 'followerCount': 0},
        },
      },
      onQuery: (spec) {
        if (spec.collection == 'usernames') {
          return <FakeDocRow>[
            (id: 'kev2', data: <String, dynamic>{'uid': 'kev2'}),
          ];
        }
        return <FakeDocRow>[
          (id: 'doc_kevin', data: <String, dynamic>{'name': 'Kevin', 'username': 'kevin', 'followerCount': 2}),
        ];
      },
    );

    final result = await _repo(firestore).searchUsers(' kev ');

    expect(firestore.querySpecs.map((spec) => spec.collection), <String>['profiles', 'profiles', 'usernames']);
    expect(firestore.querySpecs.first.filters.map((f) => f.field), <String>['name', 'name']);
    expect(firestore.querySpecs.last.filters.map((f) => f.field), <String>['__name__', '__name__']);
    expect(firestore.querySpecs.last.filters.map((f) => f.op), <FirestoreFilterOp>[
      FirestoreFilterOp.isGreaterThanOrEqualTo,
      FirestoreFilterOp.isLessThan,
    ]);
    expect(firestore.querySpecs.last.filters.map((f) => f.value), <String>['kev', 'kev\uf8ff']);
    final users = result.data!;
    expect(users.map((user) => user.id), <String>['doc_kevin', 'kev2']);
    expect(users.first.followerCount, 2);
    expect(users.first.id, 'doc_kevin');
  });

  test('a failed query becomes a failure result', () async {
    final firestore = FakeFirestoreClient()..queryError = StateError('offline');

    final result = await _repo(firestore).searchUsers('kev');

    expect(result.isFailure, isTrue);
  });

  test('a mixed-case query uses the exact projection fields without hidden lowercase keys', () async {
    final firestore = FakeFirestoreClient();

    await _repo(firestore).searchUsers('KeViN');

    final namePrefix = firestore.querySpecs.firstWhere(
      (spec) => spec.sourceTag == 'user_search.search_profiles_by_name',
    );
    final legacyUsernamePrefix = firestore.querySpecs.firstWhere(
      (spec) => spec.sourceTag == 'user_search.search_legacy_usernames',
    );
    final usernamePrefix = firestore.querySpecs.singleWhere((spec) => spec.collection == 'usernames');
    expect(namePrefix.filters.first.value, 'KeViN');
    expect(legacyUsernamePrefix.filters.first.value, 'KeViN');
    expect(usernamePrefix.filters.first.value, 'kevin');
  });

  test('finds an older public profile username without a registry document', () async {
    final firestore = FakeFirestoreClient(
      onQuery: (spec) => spec.sourceTag == 'user_search.search_legacy_usernames'
          ? <FakeDocRow>[
              (id: 'legacy-uid', data: <String, dynamic>{'name': 'Legacy', 'username': 'kev_old', 'followerCount': 0}),
            ]
          : const <FakeDocRow>[],
    );

    final result = await _repo(firestore).searchUsers('kev');

    expect(result.data!.map((user) => (user.id, user.username)), <(String, String)>[('legacy-uid', 'kev_old')]);
    expect(firestore.querySpecs.every((spec) => spec.collection != 'usersv2'), isTrue);
  });

  test('a name prefix is read from the public projection', () async {
    final firestore = FakeFirestoreClient(
      onQuery: (spec) => spec.collection == 'profiles'
          ? <FakeDocRow>[
              (id: 'd1', data: <String, dynamic>{'name': 'John'}),
            ]
          : const <FakeDocRow>[],
    );

    final result = await _repo(firestore).searchUsers('john');

    expect(result.data!.map((UserSearchUser u) => u.name), <String>['John']);
  });

  test('creators the user blocked never show up in the results', () async {
    final firestore = FakeFirestoreClient(
      onQuery: (spec) => spec.collection == 'profiles'
          ? <FakeDocRow>[
              (id: 'd1', data: <String, dynamic>{'name': 'Kev', 'username': 'kev', 'email': 'Blocked@X.com'}),
              (id: 'd2', data: <String, dynamic>{'name': 'Kevin', 'username': 'kevin', 'email': 'ok@x.com'}),
            ]
          : const <FakeDocRow>[],
    );

    final blocks = FakeUserBlockRepository.pending()..completeInitial(<String>{});
    blocks.blockedRows = const <BlockedUserListRow>[BlockedUserListRow(blockedUid: 'd1')];
    final result = await UserSearchRepositoryImpl(firestore, blocks).searchUsers('kev');

    expect(result.data!.map((UserSearchUser u) => u.id), <String>['d2']);
  });
}
