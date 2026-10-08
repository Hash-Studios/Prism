import 'package:Prism/core/persistence/local_store.dart';
import 'package:Prism/core/persistence/persistence_keys.dart';
import 'package:Prism/features/in_app_notifications/domain/entities/in_app_notification_entity.dart';
import 'package:injectable/injectable.dart';

const String _clearedAtKey = 'notifications.cleared_at_utc';

/// Remembers which inbox notifications the user removed, so a remote sync does not bring them back.
@lazySingleton
class NotificationTombstones {
  NotificationTombstones(this._store);

  static const int maxIds = 500;

  final LocalStore _store;

  Set<String> deletedIds() {
    final Object? raw = _store.get(PersistenceKeys.notificationsDeletedIds);
    if (raw is! List) {
      return <String>{};
    }
    return raw.whereType<String>().toSet();
  }

  /// When the user last cleared the whole inbox. Anything created before this stays gone.
  DateTime? clearedAtUtc() {
    final Object? raw = _store.get(_clearedAtKey);
    return raw is String ? DateTime.tryParse(raw)?.toUtc() : null;
  }

  Future<void> addDeleted(Iterable<String> ids) async {
    final Object? raw = _store.get(PersistenceKeys.notificationsDeletedIds);
    final List<String> merged = <String>[if (raw is List) ...raw.whereType<String>()];
    final Set<String> seen = merged.toSet();
    for (final String id in ids) {
      if (id.isNotEmpty && seen.add(id)) {
        merged.add(id);
      }
    }
    final List<String> capped = merged.length > maxIds ? merged.sublist(merged.length - maxIds) : merged;
    await _store.set(PersistenceKeys.notificationsDeletedIds, capped);
  }

  Future<void> removeDeleted(Iterable<String> ids) async {
    final Set<String> toRemove = ids.toSet();
    final List<String> kept = deletedIds().where((String id) => !toRemove.contains(id)).toList(growable: false);
    await _store.set(PersistenceKeys.notificationsDeletedIds, kept);
  }

  Future<void> markCleared(Iterable<String> currentIds, DateTime nowUtc) async {
    await addDeleted(currentIds);
    await _store.set(_clearedAtKey, nowUtc.toUtc().toIso8601String());
  }

  /// The earliest created-at a fetch may ask for: the backfill start, or the last clear when that is later.
  DateTime fetchFloor(DateTime backfillStartUtc) {
    final DateTime? clearedAt = clearedAtUtc();
    return clearedAt != null && clearedAt.isAfter(backfillStartUtc) ? clearedAt : backfillStartUtc;
  }

  List<InAppNotificationEntity> withoutRemoved(List<InAppNotificationEntity> items) {
    final Set<String> deleted = deletedIds();
    final DateTime? clearedAt = clearedAtUtc();
    return items
        .where(
          (InAppNotificationEntity item) =>
              !deleted.contains(item.id) && (clearedAt == null || item.createdAt.isAfter(clearedAt)),
        )
        .toList(growable: false);
  }
}
