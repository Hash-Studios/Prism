import 'package:Prism/core/persistence/local_store.dart';
import 'package:Prism/core/persistence/persistence_keys.dart';
import 'package:Prism/features/in_app_notifications/domain/entities/in_app_notification_entity.dart';
import 'package:injectable/injectable.dart';

String buildInAppNotificationId({
  required String title,
  required String body,
  required String pageName,
  required String url,
  required DateTime createdAt,
}) {
  return '${title.trim()}|${body.trim()}|${pageName.trim()}|${url.trim()}|${createdAt.toUtc().toIso8601String()}';
}

@lazySingleton
class NotificationsLocalDataSource {
  NotificationsLocalDataSource(this._store);

  final LocalStore _store;

  List<InAppNotificationEntity> readAll() {
    final raw = _store.get(PersistenceKeys.notificationsItems);
    if (raw is! List) {
      return const <InAppNotificationEntity>[];
    }
    return raw
        .whereType<Map>()
        .map((entry) {
          final map = entry.map<String, dynamic>((key, value) => MapEntry(key.toString(), value));
          return InAppNotificationEntity(
            id:
                (map['id'] as String?) ??
                buildInAppNotificationId(
                  title: (map['title'] as String?) ?? '',
                  body: (map['body'] as String?) ?? '',
                  pageName: (map['pageName'] as String?) ?? '',
                  url: (map['url'] as String?) ?? '',
                  createdAt: DateTime.tryParse((map['createdAt'] as String?) ?? '')?.toUtc() ?? DateTime.now().toUtc(),
                ),
            title: (map['title'] as String?) ?? '',
            pageName: (map['pageName'] as String?) ?? '',
            body: (map['body'] as String?) ?? '',
            imageUrl: (map['imageUrl'] as String?) ?? '',
            arguments: ((map['arguments'] as List?) ?? const <Object>[]).whereType<Object>().toList(growable: false),
            url: (map['url'] as String?) ?? '',
            createdAt: DateTime.tryParse((map['createdAt'] as String?) ?? '')?.toUtc() ?? DateTime.now().toUtc(),
            read: (map['read'] as bool?) ?? false,
            route: map['route']?.toString(),
            wallId: map['wallId']?.toString(),
          );
        })
        .toList(growable: false);
  }

  Future<void> writeAll(List<InAppNotificationEntity> items) {
    final payload = items
        .map(
          (item) => <String, Object?>{
            'id': item.id,
            'title': item.title,
            'pageName': item.pageName,
            'body': item.body,
            'imageUrl': item.imageUrl,
            'arguments': item.arguments,
            'url': item.url,
            'createdAt': item.createdAt.toUtc().toIso8601String(),
            'read': item.read,
            'route': item.route,
            'wallId': item.wallId,
          },
        )
        .toList(growable: false);
    return _store.set(PersistenceKeys.notificationsItems, payload);
  }

  Future<void> upsertAll(List<InAppNotificationEntity> incoming) async {
    final existing = readAll();
    final byId = <String, InAppNotificationEntity>{for (final item in existing) item.id: item};
    for (final item in incoming) {
      final prev = byId[item.id];
      if (prev != null && prev.read) {
        byId[item.id] = item.copyWith(read: true);
      } else {
        byId[item.id] = item;
      }
    }
    final merged = byId.values.toList(growable: false)..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    await writeAll(merged);
  }

  Future<void> markAsRead(String id) async {
    final updated = readAll().map((item) => item.id == id ? item.copyWith(read: true) : item).toList(growable: false);
    await writeAll(updated);
  }

  Future<void> deleteById(String id) async {
    final updated = readAll().where((item) => item.id != id).toList(growable: false);
    await writeAll(updated);
  }

  Future<void> clearAll() {
    return _store.delete(PersistenceKeys.notificationsItems);
  }

  DateTime? lastFetchAtUtc() {
    final raw = _store.get(PersistenceKeys.notificationsLastFetchUtc);
    if (raw is! String || raw.trim().isEmpty) {
      return null;
    }
    return DateTime.tryParse(raw)?.toUtc();
  }

  Future<void> setLastFetchAtUtc(DateTime value) {
    return _store.set(PersistenceKeys.notificationsLastFetchUtc, value.toUtc().toIso8601String());
  }

  Future<void> clearLastFetchAtUtc() {
    return _store.delete(PersistenceKeys.notificationsLastFetchUtc);
  }
}
