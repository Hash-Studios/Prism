import 'package:Prism/core/persistence/data_sources/session_local_data_source.dart';
import 'package:Prism/core/persistence/persistence_keys.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/in_memory_local_store.dart';

void main() {
  group('SessionLocalDataSource', () {
    test('returns guest user and archives payload when stored map is malformed', () async {
      final store = InMemoryLocalStore();
      store.data[PersistenceKeys.sessionCurrentUser] = <String, Object?>{
        'username': null,
        'email': null,
        'id': null,
        'followers': 'not-a-list',
      };
      final source = SessionLocalDataSource(store);

      final user = source.readCurrentUser();
      await Future<void>.delayed(Duration.zero);

      expect(user.loggedIn, isFalse);
      expect(user.id, isEmpty);
      expect(store.get(PersistenceKeys.sessionCurrentUser), isNull);
      expect(store.get('session.current_user.corrupt_payload'), isA<Map>());
    });

    test('keeps valid payload and rewrites normalized session record', () async {
      final store = InMemoryLocalStore();
      store.data[PersistenceKeys.sessionCurrentUser] = <String, Object?>{
        'username': 'alice',
        'email': 'alice@example.com',
        'id': 'user-1',
        'createdAt': '2026-03-12T00:00:00.000Z',
        'premium': false,
        'lastLoginAt': '2026-03-12T00:00:00.000Z',
        'links': <String, String>{},
        'followers': <String>[],
        'following': <String>[],
        'profilePhoto': '',
        'bio': '',
        'loggedIn': true,
        'badges': <Object?>[],
        'subPrisms': <String>[],
        'coins': 0,
        'transactions': <Object?>[],
        'name': 'Alice',
        'subscriptionTier': 'free',
      };
      final source = SessionLocalDataSource(store);

      final user = source.readCurrentUser();
      await Future<void>.delayed(Duration.zero);

      expect(user.id, 'user-1');
      expect(user.loggedIn, isTrue);
      expect(store.get(PersistenceKeys.sessionCurrentUser), isA<Map<String, dynamic>>());
      expect(store.get('session.current_user.corrupt_payload'), isNull);
    });
  });
}
