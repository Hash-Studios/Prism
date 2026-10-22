import 'dart:async';

import 'package:Prism/auth/user_model.dart';
import 'package:Prism/core/constants/app_constants.dart';
import 'package:Prism/core/persistence/local_store.dart';
import 'package:Prism/core/persistence/persistence_keys.dart';
import 'package:Prism/core/utils/json_utils.dart';
import 'package:injectable/injectable.dart';

@lazySingleton
class SessionLocalDataSource {
  SessionLocalDataSource(this._store);

  final LocalStore _store;
  Future<void> _writeTail = Future<void>.value();
  int _revision = 0;
  static const String _corruptSessionPayloadKey = 'session.current_user.corrupt_payload';

  PrismUsersV2 readCurrentUser() {
    final int revision = _revision;
    final Object? raw = _store.get(PersistenceKeys.sessionCurrentUser);
    if (raw is Map) {
      final map = toJsonMap(raw);
      try {
        final PrismUsersV2 user = PrismUsersV2.fromJson(map);
        // Self-heal any stale or partially malformed payloads by rewriting
        // a normalized representation once decode succeeds.
        final normalized = user.toJson();
        unawaited(_repair(revision, () => _store.set(PersistenceKeys.sessionCurrentUser, normalized)));
        return user;
      } catch (_) {
        unawaited(
          _repair(revision, () async {
            await _store.set(_corruptSessionPayloadKey, map);
            if (revision != _revision) return;
            await _store.delete(PersistenceKeys.sessionCurrentUser);
          }),
        );
        return createGuestPrismUser();
      }
    }
    return createGuestPrismUser();
  }

  Future<void> writeCurrentUser(PrismUsersV2 user) {
    final payload = user.toJson();
    return _mutate(() => _store.set(PersistenceKeys.sessionCurrentUser, payload));
  }

  Future<void> _repair(int revision, Future<void> Function() repair) async {
    try {
      await _serialize(() async {
        if (revision == _revision) await repair();
      });
    } catch (_) {
      // Read repair is best-effort. Keep the saved session if persistence fails.
    }
  }

  Future<void> clearCurrentUser() {
    return _mutate(() => _store.delete(PersistenceKeys.sessionCurrentUser));
  }

  Future<void> _mutate(Future<void> Function() mutation) {
    _revision++;
    return _serialize(() async {
      try {
        await mutation();
      } finally {
        // A read made while this mutation was pending saw the old session.
        _revision++;
      }
    });
  }

  Future<void> _serialize(Future<void> Function() operation) {
    final Future<void> result = _writeTail.then((_) => operation());
    _writeTail = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }
}
