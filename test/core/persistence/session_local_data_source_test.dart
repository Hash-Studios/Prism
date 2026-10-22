import 'dart:async';

import 'package:Prism/core/constants/app_constants.dart';
import 'package:Prism/core/persistence/data_sources/session_local_data_source.dart';
import 'package:Prism/core/persistence/persistence_keys.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/in_memory_local_store.dart';

class _RepairStore extends InMemoryLocalStore {
  bool failSet = false;
  bool failDelete = false;
  Completer<void>? archiveGate;
  final Completer<void> archiveStarted = Completer<void>();
  Completer<void>? normalizationGate;
  final Completer<void> normalizationStarted = Completer<void>();
  final List<String> deletes = <String>[];

  @override
  Future<void> set(String key, Object? value) async {
    if (key == 'session.current_user.corrupt_payload') {
      archiveStarted.complete();
      await archiveGate?.future;
    } else if (key == PersistenceKeys.sessionCurrentUser && !normalizationStarted.isCompleted) {
      normalizationStarted.complete();
      await normalizationGate?.future;
    }
    if (failSet) throw StateError('write rejected');
    await super.set(key, value);
  }

  @override
  Future<void> delete(String key) async {
    deletes.add(key);
    if (failDelete) throw StateError('delete rejected');
    await super.delete(key);
  }
}

Future<List<Object>> _repairErrors(void Function() read) async {
  final errors = <Object>[];
  await runZonedGuarded(() async {
    read();
    await Future<void>.delayed(Duration.zero);
  }, (error, _) => errors.add(error));
  return errors;
}

void main() {
  group('SessionLocalDataSource', () {
    test('an old corrupt-session repair cannot delete a newer saved user', () async {
      final store = _RepairStore()..archiveGate = Completer<void>();
      store.data[PersistenceKeys.sessionCurrentUser] = <String, Object?>{'followers': 'not-a-list'};
      final source = SessionLocalDataSource(store);
      source.readCurrentUser();
      await store.archiveStarted.future;

      final user = createGuestPrismUser()..id = 'new-owner';
      final saving = source.writeCurrentUser(user);
      store.archiveGate!.complete();
      await saving;
      await Future<void>.delayed(Duration.zero);

      expect((store.get(PersistenceKeys.sessionCurrentUser)! as Map)['id'], 'new-owner');
      expect(store.deletes, isEmpty);
    });

    for (final bool clear in <bool>[false, true]) {
      test('a delayed normalization cannot overwrite a later ${clear ? 'clear' : 'write'}', () async {
        final store = _RepairStore()..normalizationGate = Completer<void>();
        store.data[PersistenceKeys.sessionCurrentUser] = createGuestPrismUser().toJson();
        final source = SessionLocalDataSource(store);
        final oldUser = source.readCurrentUser();
        await store.normalizationStarted.future;

        oldUser.id = 'new-owner';
        final saving = clear ? source.clearCurrentUser() : source.writeCurrentUser(oldUser);
        store.normalizationGate!.complete();
        await saving;
        await Future<void>.delayed(Duration.zero);

        if (clear) {
          expect(store.get(PersistenceKeys.sessionCurrentUser), isNull);
        } else {
          expect((store.get(PersistenceKeys.sessionCurrentUser)! as Map)['id'], 'new-owner');
        }
      });
    }

    test('a read during a pending user write cannot queue the previous user back into storage', () async {
      final store = _RepairStore()..normalizationGate = Completer<void>();
      store.data[PersistenceKeys.sessionCurrentUser] = createGuestPrismUser().toJson();
      final source = SessionLocalDataSource(store);
      final user = createGuestPrismUser()..id = 'new-owner';
      final saving = source.writeCurrentUser(user);
      await store.normalizationStarted.future;

      expect(source.readCurrentUser().id, isEmpty);
      store.normalizationGate!.complete();
      await saving;
      await Future<void>.delayed(Duration.zero);

      expect((store.get(PersistenceKeys.sessionCurrentUser)! as Map)['id'], 'new-owner');
    });

    test('a failed asynchronous normalization keeps the decoded user without uncaught errors', () async {
      final store = _RepairStore()..failSet = true;
      final payload = createGuestPrismUser().toJson();
      store.data[PersistenceKeys.sessionCurrentUser] = payload;

      final errors = await _repairErrors(() {
        expect(SessionLocalDataSource(store).readCurrentUser().loggedIn, isFalse);
      });

      expect(errors, isEmpty);
      expect(store.get(PersistenceKeys.sessionCurrentUser), same(payload));
    });

    test('a failed corrupt-payload archive leaves the original and does not attempt deletion', () async {
      final store = _RepairStore()..failSet = true;
      final payload = <String, Object?>{'followers': 'not-a-list'};
      store.data[PersistenceKeys.sessionCurrentUser] = payload;

      final errors = await _repairErrors(() {
        expect(SessionLocalDataSource(store).readCurrentUser().loggedIn, isFalse);
      });

      expect(errors, isEmpty);
      expect(store.deletes, isEmpty);
      expect(store.get(PersistenceKeys.sessionCurrentUser), same(payload));
    });

    test('corrupt-session deletion waits for the archive to finish', () async {
      final store = _RepairStore()..archiveGate = Completer<void>();
      final payload = <String, Object?>{'followers': 'not-a-list'};
      store.data[PersistenceKeys.sessionCurrentUser] = payload;

      SessionLocalDataSource(store).readCurrentUser();
      await store.archiveStarted.future;
      expect(store.deletes, isEmpty);
      expect(store.get(PersistenceKeys.sessionCurrentUser), same(payload));
      store.archiveGate!.complete();
      await Future<void>.delayed(Duration.zero);

      expect(store.get('session.current_user.corrupt_payload'), payload);
      expect(store.get(PersistenceKeys.sessionCurrentUser), isNull);
    });

    test('a failed corrupt-session deletion preserves both records without uncaught errors', () async {
      final store = _RepairStore()..failDelete = true;
      final payload = <String, Object?>{'followers': 'not-a-list'};
      store.data[PersistenceKeys.sessionCurrentUser] = payload;

      final errors = await _repairErrors(() {
        expect(SessionLocalDataSource(store).readCurrentUser().loggedIn, isFalse);
      });

      expect(errors, isEmpty);
      expect(store.get('session.current_user.corrupt_payload'), payload);
      expect(store.get(PersistenceKeys.sessionCurrentUser), same(payload));
    });

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
