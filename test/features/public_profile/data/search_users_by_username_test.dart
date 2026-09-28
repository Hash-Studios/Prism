import 'package:Prism/core/firestore/firestore_client.dart';
import 'package:Prism/core/firestore/firestore_query_specs.dart';
import 'package:Prism/features/public_profile/data/repositories/public_profile_repository_impl.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_user_block_repository.dart';

/// Applies whereIn, >=, <, orderBy and limit like Firestore does for these specs.
class _FakeUsers implements FirestoreClient {
  _FakeUsers(this.users);

  final List<Map<String, dynamic>> users;
  final List<FirestoreQuerySpec> specs = <FirestoreQuerySpec>[];

  @override
  Future<List<T>> query<T>(FirestoreQuerySpec spec, T Function(Map<String, dynamic> data, String docId) map) async {
    specs.add(spec);
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
    return sorted.take(spec.limit ?? sorted.length).map((u) => map(u, u['email'] as String)).toList();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

Map<String, dynamic> _user(String username) => <String, dynamic>{
  'email': '${username.toLowerCase()}@x.com',
  'username': username,
  'usernameLower': username.toLowerCase(),
};

Future<List<String>> _search(_FakeUsers client, String query, List<String> scope) async {
  final repo = PublicProfileRepositoryImpl(client, FakeUserBlockRepository.pending());
  final result = await repo.searchUsersByUsername(query: query, scopeEmails: scope, currentUserEmail: 'me@x.com');
  return result.fold(onSuccess: (list) => list.map((u) => u.username).toList(), onFailure: (f) => throw f);
}

void main() {
  test('search ignores case', () async {
    final client = _FakeUsers(<Map<String, dynamic>>[_user('KevinDoran')]);

    expect(await _search(client, 'kevin', <String>['kevindoran@x.com']), <String>['KevinDoran']);
  });

  test('search only looks inside the list, so other users cannot crowd a member out', () async {
    final strangers = <Map<String, dynamic>>[for (int i = 0; i < 25; i++) _user('kevina$i')];
    final client = _FakeUsers(<Map<String, dynamic>>[...strangers, _user('kevinz')]);

    expect(await _search(client, 'kevin', <String>['kevinz@x.com']), <String>['kevinz']);
  });

  test('large lists are queried in chunks of 30 and merged in order', () async {
    final members = <Map<String, dynamic>>[for (int i = 0; i < 65; i++) _user('kev${i.toString().padLeft(2, '0')}')];
    final client = _FakeUsers(members);

    final names = await _search(client, 'KEV', members.map((u) => u['email'] as String).toList());

    expect(client.specs, hasLength(3));
    for (final spec in client.specs) {
      final inFilter = spec.filters.firstWhere((f) => f.op == FirestoreFilterOp.whereIn);
      expect((inFilter.value! as List<Object?>).length, lessThanOrEqualTo(30));
    }
    expect(names, <String>['kev00', 'kev01', 'kev02', 'kev03', 'kev04']);
  });

  test('a blank query does not hit Firestore', () async {
    final client = _FakeUsers(<Map<String, dynamic>>[_user('KevinDoran')]);

    expect(await _search(client, '  ', <String>['kevindoran@x.com']), isEmpty);
    expect(client.specs, isEmpty);
  });
}
