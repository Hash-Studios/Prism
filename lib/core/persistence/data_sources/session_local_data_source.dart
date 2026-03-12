import 'dart:async';

import 'package:Prism/auth/userModel.dart';
import 'package:Prism/core/constants/app_constants.dart';
import 'package:Prism/core/persistence/local_store.dart';
import 'package:Prism/core/persistence/persistence_keys.dart';
import 'package:injectable/injectable.dart';

@lazySingleton
class SessionLocalDataSource {
  SessionLocalDataSource(this._store);

  final LocalStore _store;
  static const String _corruptSessionPayloadKey = 'session.current_user.corrupt_payload';

  PrismUsersV2 readCurrentUser() {
    final dynamic raw = _store.get(PersistenceKeys.sessionCurrentUser);
    if (raw is Map) {
      final map = raw.map<String, dynamic>((key, value) => MapEntry(key.toString(), value));
      try {
        final PrismUsersV2 user = PrismUsersV2.fromJson(map);
        // Self-heal any stale or partially malformed payloads by rewriting
        // a normalized representation once decode succeeds.
        unawaited(_store.set(PersistenceKeys.sessionCurrentUser, user.toJson()));
        return user;
      } catch (_) {
        unawaited(_store.set(_corruptSessionPayloadKey, map));
        unawaited(_store.delete(PersistenceKeys.sessionCurrentUser));
        return createGuestPrismUser();
      }
    }
    return createGuestPrismUser();
  }

  Future<void> writeCurrentUser(PrismUsersV2 user) {
    return _store.set(PersistenceKeys.sessionCurrentUser, user.toJson());
  }

  Future<void> clearCurrentUser() {
    return _store.delete(PersistenceKeys.sessionCurrentUser);
  }
}
