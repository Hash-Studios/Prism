import 'package:Prism/core/firestore/firestore_query_specs.dart';
import 'package:Prism/features/public_profile/data/repositories/public_profile_repository_impl.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_firestore_client.dart';
import '../../../support/fake_user_block_repository.dart';

/// Applies whereIn, >=, <, orderBy and limit like Firestore does for these specs.
FakeFirestoreClient _fakeUsers(List<Map<String, dynamic>> users) => FakeFirestoreClient(
  onQuery: (spec) {
    Iterable<Map<String, dynamic>> rows = users;
    for (final f in spec.filters) {
      rows = rows.where((u) {
        final v = u[f.field] as String? ?? '';
        return switch (f.op) {
          FirestoreFilterOp.whereIn => (f.value! as List<Object?>).contains(v),
          FirestoreFilterOp.isGreaterThanOrEqualTo => v.compareTo(f.value! as String) >= 0,
          FirestoreFilterOp.isLessThan => v.compareTo(f.value! as String) < 0,
          _ => throw UnimplementedError(f.op.name),
        };
      });
    }
    final sorted = rows.toList()
      ..sort((a, b) => (a['usernameLower'] as String).compareTo(b['usernameLower'] as String));
    return sorted.take(spec.limit ?? sorted.length).map((u) => (id: u['email'] as String, data: u)).toList();
  },
);

Map<String, dynamic> _user(String username) => <String, dynamic>{
  'email': '${username.toLowerCase()}@x.com',
  'username': username,
  'usernameLower': username.toLowerCase(),
};

Future<List<String>> _search(FakeFirestoreClient client, String query, List<String> scope) async {
  final repo = PublicProfileRepositoryImpl(client, FakeUserBlockRepository.pending());
  final result = await repo.searchUsersByUsername(query: query, scopeEmails: scope);
  return result.fold(onSuccess: (list) => list.map((u) => u.username).toList(), onFailure: (f) => throw f);
}

void main() {
  test('search ignores case', () async {
    final client = _fakeUsers(<Map<String, dynamic>>[_user('KevinDoran')]);

    expect(await _search(client, 'kevin', <String>['kevindoran@x.com']), <String>['KevinDoran']);
  });

  test('search only looks inside the list, so other users cannot crowd a member out', () async {
    final strangers = <Map<String, dynamic>>[for (int i = 0; i < 25; i++) _user('kevina$i')];
    final client = _fakeUsers(<Map<String, dynamic>>[...strangers, _user('kevinz')]);

    expect(await _search(client, 'kevin', <String>['kevinz@x.com']), <String>['kevinz']);
  });

  test('large lists are queried in chunks of 30 and merged in order', () async {
    final members = <Map<String, dynamic>>[for (int i = 0; i < 65; i++) _user('kev${i.toString().padLeft(2, '0')}')];
    final client = _fakeUsers(members);

    final names = await _search(client, 'KEV', members.map((u) => u['email'] as String).toList());

    expect(client.querySpecs, hasLength(3));
    for (final spec in client.querySpecs) {
      final inFilter = spec.filters.firstWhere((f) => f.op == FirestoreFilterOp.whereIn);
      expect((inFilter.value! as List<Object?>).length, lessThanOrEqualTo(30));
    }
    expect(names, <String>['kev00', 'kev01', 'kev02', 'kev03', 'kev04']);
  });

  test('search finds a member stored with a mixed-case email once (#541)', () async {
    final alice = <String, dynamic>{'email': 'Alice@Example.com', 'username': 'Alice', 'usernameLower': 'alice'};
    final client = _fakeUsers(<Map<String, dynamic>>[alice]);

    expect(await _search(client, 'ali', <String>['Alice@Example.com', 'alice@example.com']), <String>['Alice']);
  });

  Map<String, dynamic> stored(String email, String username) => <String, dynamic>{
    'email': email,
    'username': username,
    'usernameLower': username.toLowerCase(),
  };

  test('search keeps the relation spelling when a lowercase duplicate sorts first', () async {
    final client = _fakeUsers(<Map<String, dynamic>>[
      stored('alice@example.com', 'alia_lower'),
      stored('Alice@Example.com', 'alib_exact'),
    ]);

    expect(await _search(client, 'ali', <String>['Alice@Example.com']), <String>['alib_exact']);
    // A lowercase relation does not invent a mixed-case variant, so it keeps the lowercase account.
    expect(await _search(client, 'ali', <String>['alice@example.com']), <String>['alia_lower']);
  });

  test('a case duplicate in a chunk does not push a distinct member out of the top five', () async {
    final members = <Map<String, dynamic>>[
      for (final n in <String>['alic', 'alid', 'alie', 'alif', 'alig']) _user(n),
    ];
    final client = _fakeUsers(<Map<String, dynamic>>[
      stored('Alice@Example.com', 'alia'),
      stored('alice@example.com', 'alib'),
      ...members,
    ]);
    final scope = <String>['Alice@Example.com', ...members.map((u) => u['email'] as String)];

    expect(await _search(client, 'ali', scope), <String>['alia', 'alic', 'alid', 'alie', 'alif']);
  });

  test('a lowercase duplicate does not stand in for a relation user who sorts below the top five', () async {
    final members = <Map<String, dynamic>>[for (int i = 1; i <= 5; i++) _user('ab$i')];
    final client = _fakeUsers(<Map<String, dynamic>>[
      stored('alice@example.com', 'aa0'),
      stored('Alice@Example.com', 'az'),
      ...members,
    ]);
    final scope = <String>['Alice@Example.com', ...members.map((u) => u['email'] as String)];

    expect(await _search(client, 'a', scope), <String>['ab1', 'ab2', 'ab3', 'ab4', 'ab5']);
  });

  test('a lowercase duplicate does not match for a relation user whose own name does not match', () async {
    final client = _fakeUsers(<Map<String, dynamic>>[
      stored('alice@example.com', 'alice_lower'),
      stored('Alice@Example.com', 'Zed'),
    ]);

    expect(await _search(client, 'ali', <String>['Alice@Example.com']), isEmpty);
  });

  test('a mixed-case relation still finds a member stored only in lowercase', () async {
    final client = _fakeUsers(<Map<String, dynamic>>[stored('carol@example.com', 'Carol')]);

    expect(await _search(client, 'car', <String>['Carol@Example.com']), <String>['Carol']);
  });

  test('both spellings of one address go in the same chunk of at most 30', () async {
    final members = <Map<String, dynamic>>[for (int i = 0; i < 29; i++) _user('m${i.toString().padLeft(2, '0')}')];
    final client = _fakeUsers(<Map<String, dynamic>>[
      ...members,
      stored('alice@example.com', 'm_lower'),
      stored('Alice@Example.com', 'm_exact'),
    ]);
    final scope = <String>[...members.map((u) => u['email'] as String), 'Alice@Example.com'];

    final names = await _search(client, 'm', scope);

    final inFilters = <List<Object?>>[
      for (final spec in client.querySpecs)
        spec.filters.firstWhere((f) => f.op == FirestoreFilterOp.whereIn).value! as List<Object?>,
    ];
    expect(inFilters.every((values) => values.length <= 30), isTrue);
    expect(inFilters.where((v) => v.contains('Alice@Example.com') || v.contains('alice@example.com')), [
      <Object?>['Alice@Example.com', 'alice@example.com'],
    ]);
    expect(names, <String>['m00', 'm01', 'm02', 'm03', 'm04']);
    expect(await _search(client, 'm_', scope), <String>['m_exact']);
  });

  test('a spelling group split across chunks does not hide a fifth member', () async {
    // 31 casings of abcdef@x.com: casing n uppercases letter i when bit i of n is set.
    final variants = <String>[
      for (int n = 0; n <= 30; n++)
        '${String.fromCharCodes(<int>[for (int i = 0; i < 6; i++) 'abcdef'.codeUnitAt(i) - ((n >> i & 1) * 32)])}@x.com',
    ];
    final members = <String>[for (int i = 0; i < 5; i++) 'u$i@x.com'];
    final client = _fakeUsers(<Map<String, dynamic>>[
      stored(variants.first, 'zed'),
      stored(variants.last, 'aa0'),
      for (int i = 0; i < 5; i++) stored(members[i], 'ab$i'),
    ]);

    expect(variants.last, 'aBCDEf@x.com');
    expect(await _search(client, 'a', <String>[...variants, ...members]), <String>['ab0', 'ab1', 'ab2', 'ab3', 'ab4']);
  });

  test('a blank query does not hit Firestore', () async {
    final client = _fakeUsers(<Map<String, dynamic>>[_user('KevinDoran')]);

    expect(await _search(client, '  ', <String>['kevindoran@x.com']), isEmpty);
    expect(client.querySpecs, isEmpty);
  });
}
