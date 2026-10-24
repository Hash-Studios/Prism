import 'package:Prism/core/firestore/firestore_query_specs.dart';
import 'package:Prism/features/public_profile/data/repositories/public_profile_repository_impl.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_firestore_client.dart';
import '../../../support/fake_user_block_repository.dart';

FakeDocRow _profile(String uid, String username) =>
    (id: uid, data: <String, dynamic>{'name': username, 'username': username, 'email': '$uid@private.test'});

void main() {
  test('searches only scoped profile UIDs and never returns private email fields', () async {
    final client = FakeFirestoreClient(
      onQuery: (spec) {
        final ids = spec.filters.first.value! as List<Object?>;
        return <FakeDocRow>[
          for (final profile in <FakeDocRow>[
            _profile('uid-1', 'Kevin'),
            _profile('uid-2', 'kevin2'),
            _profile('stranger', 'kevin3'),
          ])
            if (ids.contains(profile.id)) profile,
        ];
      },
    );
    final repo = PublicProfileRepositoryImpl(client, FakeUserBlockRepository.pending());

    final result = await repo.searchUsersByUsername(
      query: 'kev',
      scopeUserIds: const <String>['uid-2', 'uid-1', 'uid-2', 'someone@example.test'],
    );

    expect(result.isSuccess, isTrue);
    expect(result.data!.map((user) => user.id), <String>['uid-1', 'uid-2']);
    expect(result.data!.every((user) => user.email.isEmpty), isTrue);
    final profileQuery = client.querySpecs.singleWhere((spec) => spec.collection == 'profiles');
    expect(profileQuery.filters.first.field, firestoreDocumentIdField);
    expect(profileQuery.filters.first.value, <String>['uid-2', 'uid-1']);
  });

  test('large UID scopes are queried in chunks of 30 and merged into username order', () async {
    final ids = <String>[for (int i = 0; i < 65; i++) 'uid-$i'];
    final client = FakeFirestoreClient(
      onQuery: (spec) => <FakeDocRow>[
        for (final id in spec.filters.first.value! as List<Object?>)
          _profile(id! as String, 'kev${int.parse((id as String).substring(4)).toString().padLeft(2, '0')}'),
      ],
    );
    final repo = PublicProfileRepositoryImpl(client, FakeUserBlockRepository.pending());

    final result = await repo.searchUsersByUsername(query: 'kev', scopeUserIds: ids);

    expect(client.querySpecs, hasLength(3));
    expect(client.querySpecs.map((spec) => (spec.filters.first.value! as List<Object?>).length), <int>[30, 30, 5]);
    expect(result.data!.map((user) => user.username), <String>['kev00', 'kev01', 'kev02', 'kev03', 'kev04']);
    expect(result.data!.every((user) => user.email.isEmpty), isTrue);
  });

  test('a blank query or email-only scope does not query Firestore', () async {
    final client = FakeFirestoreClient();
    final repo = PublicProfileRepositoryImpl(client, FakeUserBlockRepository.pending());

    expect((await repo.searchUsersByUsername(query: '  ', scopeUserIds: const <String>['uid-1'])).data, isEmpty);
    expect(
      (await repo.searchUsersByUsername(query: 'kev', scopeUserIds: const <String>['ana@example.test'])).data,
      isEmpty,
    );
    expect(client.querySpecs, isEmpty);
  });
}
