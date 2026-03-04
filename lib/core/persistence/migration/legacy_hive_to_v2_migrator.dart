import 'package:Prism/auth/userModel.dart';
import 'package:Prism/core/persistence/data_sources/favorites_local_data_source.dart';
import 'package:Prism/core/persistence/data_sources/notifications_local_data_source.dart';
import 'package:Prism/core/persistence/local_store.dart';
import 'package:Prism/core/persistence/persistence_keys.dart';
import 'package:Prism/data/notifications/model/inAppNotifModel.dart';
import 'package:hive_io/hive_io.dart';

class LegacyHiveToV2Migrator {
  LegacyHiveToV2Migrator(this._store);

  final LocalStore _store;

  static const String _legacyUserKey = 'prismUserV2-1';

  Future<void> migrateIfRequired() async {
    final int currentVersion = (_store.get(PersistenceKeys.schemaVersion) as int?) ?? 0;
    if (currentVersion >= PersistenceKeys.currentSchemaVersion) {
      return;
    }

    final Box<dynamic> prefsBox = Hive.isBoxOpen('prefs') ? Hive.box('prefs') : await Hive.openBox('prefs');
    final Box<dynamic> localFavBox = Hive.isBoxOpen('localFav') ? Hive.box('localFav') : await Hive.openBox('localFav');
    final Box<dynamic> appsCacheBox = Hive.isBoxOpen('appsCache')
        ? Hive.box('appsCache')
        : await Hive.openBox('appsCache');
    final Box<InAppNotif> inAppNotifsBox = Hive.isBoxOpen('inAppNotifs')
        ? Hive.box<InAppNotif>('inAppNotifs')
        : await Hive.openBox<InAppNotif>('inAppNotifs');

    PrismUsersV2? migratedUser;
    if (prefsBox.containsKey(_legacyUserKey)) {
      final Object? rawUser = prefsBox.get(_legacyUserKey);
      migratedUser = _decodeLegacyUser(rawUser);
      if (migratedUser == null) {
        throw StateError('Critical migration failure: unable to decode legacy session user.');
      }
      await _store.set(PersistenceKeys.sessionCurrentUser, migratedUser.toJson());
    }

    final userScope = (migratedUser?.id.trim().isNotEmpty == true)
        ? migratedUser!.id.trim()
        : FavoritesLocalDataSource.defaultUserScope;

    for (final Object? rawKey in prefsBox.keys) {
      final String key = rawKey?.toString() ?? '';
      if (key.isEmpty || key == _legacyUserKey) {
        continue;
      }
      final Object? value = prefsBox.get(rawKey);
      await _store.set(PersistenceKeys.settings(key), _jsonSafeValue(value));
    }

    for (final Object? rawKey in localFavBox.keys) {
      final String key = rawKey?.toString() ?? '';
      if (key.isEmpty) {
        continue;
      }
      final Object? value = localFavBox.get(rawKey);
      if (key == 'dataSaved') {
        await _store.set(PersistenceKeys.favoritesSeeded(userScope), value == true);
        continue;
      }
      if (value == true) {
        await _store.set(PersistenceKeys.favoriteWall(userScope, key), true);
        await _store.set(PersistenceKeys.favoriteSetup(userScope, key), true);
      }
    }

    final List<Map<String, Object?>> notifPayload = inAppNotifsBox.values
        .map((notif) {
          final DateTime createdAt = notif.createdAt?.toUtc() ?? DateTime.now().toUtc();
          final String title = notif.title ?? '';
          final String body = notif.body ?? '';
          final String pageName = notif.pageName ?? '';
          final String url = notif.url ?? '';
          return <String, Object?>{
            'id': buildInAppNotificationId(
              title: title,
              body: body,
              pageName: pageName,
              url: url,
              createdAt: createdAt,
            ),
            'title': title,
            'pageName': pageName,
            'body': body,
            'imageUrl': notif.imageUrl ?? '',
            'arguments': (notif.arguments ?? const <Object>[]).whereType<Object>().toList(growable: false),
            'url': url,
            'createdAt': createdAt.toIso8601String(),
            'read': notif.read ?? false,
            'route': notif.route,
            'wallId': notif.wallId,
          };
        })
        .toList(growable: false);
    await _store.set(PersistenceKeys.notificationsItems, notifPayload);

    final Object? iconPayload = appsCacheBox.get('icons');
    if (iconPayload != null) {
      await _store.set(PersistenceKeys.cacheIconsAppsPayload, _jsonSafeValue(iconPayload));
      await _store.set(PersistenceKeys.cacheIconsAppsUpdatedAtUtc, DateTime.now().toUtc().toIso8601String());
    }

    await _store.set(PersistenceKeys.schemaVersion, PersistenceKeys.currentSchemaVersion);
    await _store.set(PersistenceKeys.schemaMigratedAtUtc, DateTime.now().toUtc().toIso8601String());
  }

  PrismUsersV2? _decodeLegacyUser(Object? raw) {
    if (raw is PrismUsersV2) {
      return raw;
    }
    if (raw is Map<String, dynamic>) {
      return PrismUsersV2.fromJson(raw);
    }
    if (raw is Map) {
      return PrismUsersV2.fromJson(raw.map<String, dynamic>((key, value) => MapEntry(key.toString(), value)));
    }
    return null;
  }

  Object? _jsonSafeValue(Object? value) {
    if (value == null || value is bool || value is num || value is String) {
      return value;
    }
    if (value is DateTime) {
      return value.toUtc().toIso8601String();
    }
    if (value is PrismUsersV2) {
      return value.toJson();
    }
    if (value is List) {
      return value.map(_jsonSafeValue).toList(growable: false);
    }
    if (value is Map) {
      return value.map<String, Object?>((key, val) => MapEntry(key.toString(), _jsonSafeValue(val)));
    }
    return value.toString();
  }
}
