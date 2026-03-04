import 'package:Prism/auth/userModel.dart';
import 'package:Prism/core/constants/app_constants.dart';
import 'package:Prism/core/persistence/local_store.dart';
import 'package:Prism/core/persistence/persistence_keys.dart';
import 'package:injectable/injectable.dart';

@lazySingleton
class SessionLocalDataSource {
  SessionLocalDataSource(this._store);

  final LocalStore _store;

  PrismUsersV2 readCurrentUser() {
    final dynamic raw = _store.get(PersistenceKeys.sessionCurrentUser);
    if (raw is Map) {
      final map = raw.map<String, dynamic>((key, value) => MapEntry(key.toString(), value));
      return PrismUsersV2.fromJson(map);
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
