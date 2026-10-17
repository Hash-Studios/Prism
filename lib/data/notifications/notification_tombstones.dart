import 'dart:async';
import 'dart:convert';

import 'package:Prism/core/offline/durable_json_store.dart';
import 'package:Prism/core/persistence/local_store.dart';
import 'package:Prism/features/in_app_notifications/domain/entities/in_app_notification_entity.dart';
import 'package:injectable/injectable.dart';

@lazySingleton
class NotificationTombstones {
  NotificationTombstones([@ignoreParam LocalStore? _]) : this._(DurableJsonStore('notification_tombstones'));

  NotificationTombstones.withStore(DurableJsonStore store) : this._(store);

  NotificationTombstones._(this._store);

  static const int maxIds = 500;

  final DurableJsonStore _store;
  String _ownerId = 'guest';
  int _ownerGeneration = 0;
  Future<void> _writeTail = Future<void>.value();

  String get ownerId => _ownerId;
  int get ownerGeneration => _ownerGeneration;

  void setOwner(String ownerId) {
    final normalized = ownerId.trim().isEmpty ? 'guest' : ownerId.trim();
    if (_ownerId == normalized) return;
    _ownerId = normalized;
    _ownerGeneration++;
  }

  Future<Set<String>> deletedIds() async {
    final String owner = _ownerId;
    final int generation = _ownerGeneration;
    final record = await _store.read(_keyFor(owner));
    if (!_isCurrent(owner, generation)) return <String>{};
    final Object? raw = record?['deletedIds'];
    return raw is List ? raw.whereType<String>().toSet() : <String>{};
  }

  Future<DateTime?> clearedAtUtc() async {
    final String owner = _ownerId;
    final int generation = _ownerGeneration;
    final record = await _store.read(_keyFor(owner));
    if (!_isCurrent(owner, generation)) return null;
    final Object? raw = record?['clearedAtUtc'];
    return raw is String ? DateTime.tryParse(raw)?.toUtc() : null;
  }

  Future<void> addDeleted(Iterable<String> ids) => _update((record) {
    final raw = record['deletedIds'];
    final List<String> merged = raw is List ? raw.whereType<String>().toList() : <String>[];
    final Set<String> seen = merged.toSet();
    for (final String id in ids) {
      if (id.isNotEmpty && seen.add(id)) merged.add(id);
    }
    record['deletedIds'] = merged.length > maxIds ? merged.sublist(merged.length - maxIds) : merged;
  });

  Future<void> removeDeleted(Iterable<String> ids) async {
    final Set<String> toRemove = ids.toSet();
    await _update((record) {
      final raw = record['deletedIds'];
      final kept = raw is List ? raw.whereType<String>().where((id) => !toRemove.contains(id)).toList() : <String>[];
      record['deletedIds'] = kept;
    });
  }

  Future<void> restore(Iterable<InAppNotificationEntity> items) async {
    final String owner = _ownerId;
    final int generation = _ownerGeneration;
    final restored = items.toList(growable: false);
    await removeDeleted(restored.map((item) => item.id));
    if (!_isCurrent(owner, generation)) return;
    final DateTime? clearedAt = await clearedAtUtc();
    if (!_isCurrent(owner, generation)) return;
    if (clearedAt == null || restored.isEmpty) return;
    final DateTime oldest = restored
        .map((item) => item.createdAt.toUtc())
        .reduce((DateTime a, DateTime b) => a.isBefore(b) ? a : b);
    if (!oldest.isAfter(clearedAt)) {
      await _update((record) {
        record['clearedAtUtc'] = oldest.subtract(const Duration(microseconds: 1)).toIso8601String();
      });
    }
  }

  Future<void> markCleared(Iterable<String> currentIds, DateTime nowUtc) async {
    final String owner = _ownerId;
    final int generation = _ownerGeneration;
    await addDeleted(currentIds);
    if (!_isCurrent(owner, generation)) return;
    await _update((record) => record['clearedAtUtc'] = nowUtc.toUtc().toIso8601String());
  }

  /// The earliest created-at a fetch may ask for: the backfill start, or the last clear when that is later.
  Future<DateTime> fetchFloor(DateTime backfillStartUtc) async {
    final String owner = _ownerId;
    final int generation = _ownerGeneration;
    final DateTime? clearedAt = await clearedAtUtc();
    if (!_isCurrent(owner, generation)) return backfillStartUtc;
    return clearedAt != null && clearedAt.isAfter(backfillStartUtc) ? clearedAt : backfillStartUtc;
  }

  Future<List<InAppNotificationEntity>> withoutRemoved(List<InAppNotificationEntity> items) async {
    final String owner = _ownerId;
    final int generation = _ownerGeneration;
    final Set<String> deleted = await deletedIds();
    if (!_isCurrent(owner, generation)) return const <InAppNotificationEntity>[];
    final DateTime? clearedAt = await clearedAtUtc();
    if (!_isCurrent(owner, generation)) return const <InAppNotificationEntity>[];
    return items
        .where((item) => !deleted.contains(item.id) && (clearedAt == null || item.createdAt.isAfter(clearedAt)))
        .toList(growable: false);
  }

  Future<void> clearForUser(String userId) {
    final normalized = userId.trim();
    if (normalized.isEmpty) return Future<void>.value();
    if (_ownerId == normalized) _ownerGeneration++;
    return _serialize(() => _store.delete(_keyFor(normalized)));
  }

  Future<void> _update(void Function(Map<String, Object?> record) update) {
    final String owner = _ownerId;
    final int generation = _ownerGeneration;
    return _serialize(() async {
      final String key = _keyFor(owner);
      final Map<String, Object?> record = await _store.read(key) ?? <String, Object?>{'schemaVersion': 1};
      update(record);
      if (owner != _ownerId || generation != _ownerGeneration) return;
      await _store.write(key, record);
    });
  }

  bool _isCurrent(String owner, int generation) => owner == _ownerId && generation == _ownerGeneration;

  Future<void> _serialize(Future<void> Function() operation) {
    final Future<void> result = _writeTail.then((_) => operation());
    _writeTail = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  String _keyFor(String ownerId) => 'owner:${base64Url.encode(utf8.encode(ownerId))}';
}
