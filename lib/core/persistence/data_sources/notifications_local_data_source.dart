import 'dart:convert';

import 'package:Prism/core/offline/durable_json_store.dart';
import 'package:Prism/core/utils/json_utils.dart';
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
  NotificationsLocalDataSource() : this._(DurableJsonStore('notification_inbox'));

  NotificationsLocalDataSource.withStore(DurableJsonStore store) : this._(store);

  NotificationsLocalDataSource._(this._store);

  static const int _schemaVersion = 1;
  static const int _maxItems = 500;
  static const int _maxEncodedRecordBytes = 900 * 1024;

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

  Future<void> clearForUser(String userId) {
    final normalized = userId.trim();
    if (normalized.isEmpty) return Future<void>.value();
    if (_ownerId == normalized) _ownerGeneration++;
    return _serialize(() => _store.delete(_keyFor(normalized)));
  }

  String _keyFor(String ownerId) => 'owner:${base64Url.encode(utf8.encode(ownerId))}';

  Future<List<InAppNotificationEntity>> readAll() async {
    final String owner = _ownerId;
    final int generation = _ownerGeneration;
    final String key = _keyFor(owner);
    final record = await _store.read(key);
    if (!_isCurrent(owner, generation)) return const <InAppNotificationEntity>[];
    final Object? raw = record?['items'];
    if (raw is! List) return const <InAppNotificationEntity>[];
    return raw.whereType<Map>().map(_decode).toList(growable: false);
  }

  Future<void> writeAll(List<InAppNotificationEntity> items) {
    final String owner = _ownerId;
    final int generation = _ownerGeneration;
    final String key = _keyFor(owner);
    return _serialize(() async {
      if (!_isCurrent(owner, generation)) return;
      final record = await _store.read(key) ?? <String, Object?>{'schemaVersion': _schemaVersion};
      if (!_isCurrent(owner, generation)) return;
      record['items'] = _boundedItems(items, key, record);
      await _store.write(key, record);
    });
  }

  Future<void> upsertAll(List<InAppNotificationEntity> incoming) {
    final String owner = _ownerId;
    final int generation = _ownerGeneration;
    final String key = _keyFor(owner);
    return _serialize(() async {
      if (!_isCurrent(owner, generation)) return;
      final record = await _store.read(key) ?? <String, Object?>{'schemaVersion': _schemaVersion};
      if (!_isCurrent(owner, generation)) return;
      final existing = _decodeItems(record['items']);
      final byId = <String, InAppNotificationEntity>{for (final item in existing) item.id: item};
      for (final item in incoming) {
        final previous = byId[item.id];
        byId[item.id] = previous != null && previous.read ? item.copyWith(read: true) : item;
      }
      final merged = byId.values.toList(growable: false)..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      record['items'] = _boundedItems(merged, key, record);
      await _store.write(key, record);
    });
  }

  Future<void> markAsRead(String id) => _updateItems(
    (items) => items.map((item) => item.id == id ? item.copyWith(read: true) : item).toList(growable: false),
  );

  Future<void> deleteById(String id) =>
      _updateItems((items) => items.where((item) => item.id != id).toList(growable: false));

  Future<void> removeWhere(bool Function(InAppNotificationEntity item) predicate) =>
      _updateItems((items) => items.where((item) => !predicate(item)).toList(growable: false));

  Future<void> deleteByIds(List<String> ids) {
    if (ids.isEmpty) return Future<void>.value();
    final Set<String> idSet = ids.toSet();
    return _updateItems((items) => items.where((item) => !idSet.contains(item.id)).toList(growable: false));
  }

  Future<void> _updateItems(List<InAppNotificationEntity> Function(List<InAppNotificationEntity>) update) {
    final String owner = _ownerId;
    final int generation = _ownerGeneration;
    final String key = _keyFor(owner);
    return _serialize(() async {
      if (!_isCurrent(owner, generation)) return;
      final record = await _store.read(key) ?? <String, Object?>{'schemaVersion': _schemaVersion};
      if (!_isCurrent(owner, generation)) return;
      record['items'] = _boundedItems(update(_decodeItems(record['items'])), key, record);
      await _store.write(key, record);
    });
  }

  Future<void> clearAll() {
    final String owner = _ownerId;
    final int generation = _ownerGeneration;
    final String key = _keyFor(owner);
    return _serialize(() async {
      if (_isCurrent(owner, generation)) await _store.delete(key);
    });
  }

  Future<DateTime?> lastFetchAtUtc() async {
    final String owner = _ownerId;
    final int generation = _ownerGeneration;
    final record = await _store.read(_keyFor(owner));
    if (!_isCurrent(owner, generation)) return null;
    final raw = record?['lastFetchAtUtc'];
    return raw is String ? DateTime.tryParse(raw)?.toUtc() : null;
  }

  Future<void> setLastFetchAtUtc(DateTime value) {
    final String owner = _ownerId;
    final int generation = _ownerGeneration;
    final String key = _keyFor(owner);
    return _serialize(() async {
      if (!_isCurrent(owner, generation)) return;
      final record = await _store.read(key) ?? <String, Object?>{'schemaVersion': _schemaVersion};
      if (!_isCurrent(owner, generation)) return;
      record['lastFetchAtUtc'] = value.toUtc().toIso8601String();
      record['items'] = _boundedItems(_decodeItems(record['items']), key, record);
      await _store.write(key, record);
    });
  }

  bool _isCurrent(String owner, int generation) => owner == _ownerId && generation == _ownerGeneration;

  Future<void> _serialize(Future<void> Function() operation) {
    final Future<void> result = _writeTail.then((_) => operation());
    _writeTail = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  List<InAppNotificationEntity> _decodeItems(Object? raw) =>
      raw is List ? raw.whereType<Map>().map(_decode).toList(growable: false) : <InAppNotificationEntity>[];

  List<Map<String, Object?>> _boundedItems(
    List<InAppNotificationEntity> items,
    String key,
    Map<String, Object?> record,
  ) {
    final List<InAppNotificationEntity> newestFirst = items.toList(growable: false)
      ..sort((left, right) => right.createdAt.compareTo(left.createdAt));
    final Map<String, Object?> baselineRecord = <String, Object?>{...record, 'items': <Object?>[]};
    final int baselineBytes = utf8.encode(jsonEncode(<String, Object?>{'key': key, 'value': baselineRecord})).length;
    var retainedBytes = baselineBytes;
    final List<Map<String, Object?>> retained = <Map<String, Object?>>[];
    for (final InAppNotificationEntity item in newestFirst) {
      if (retained.length >= _maxItems) break;
      final Map<String, Object?> encoded = _encode(item);
      final String encodedItem = jsonEncode(encoded);
      final int itemBytes = utf8.encode(encodedItem).length;
      final int candidateBytes = retainedBytes + itemBytes + (retained.isEmpty ? 0 : 1);
      if (candidateBytes <= _maxEncodedRecordBytes) {
        retained.add(encoded);
        retainedBytes = candidateBytes;
      }
    }
    return retained;
  }

  Map<String, Object?> _encode(InAppNotificationEntity item) => <String, Object?>{
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
    'followerUid': item.followerUid,
    'kind': item.kind?.name,
    'copyKind': item.copyKind,
    'copyArgs': item.copyArgs,
  };

  InAppNotificationEntity _decode(Map raw) {
    final map = raw.map<String, dynamic>((key, value) => MapEntry(key.toString(), value));
    final createdAt = DateTime.tryParse((map['createdAt'] as String?) ?? '')?.toUtc() ?? DateTime.now().toUtc();
    return InAppNotificationEntity(
      id:
          (map['id'] as String?) ??
          buildInAppNotificationId(
            title: (map['title'] as String?) ?? '',
            body: (map['body'] as String?) ?? '',
            pageName: (map['pageName'] as String?) ?? '',
            url: (map['url'] as String?) ?? '',
            createdAt: createdAt,
          ),
      title: (map['title'] as String?) ?? '',
      pageName: (map['pageName'] as String?) ?? '',
      body: (map['body'] as String?) ?? '',
      imageUrl: (map['imageUrl'] as String?) ?? '',
      arguments: ((map['arguments'] as List?) ?? const <Object>[]).whereType<Object>().toList(growable: false),
      url: (map['url'] as String?) ?? '',
      createdAt: createdAt,
      read: (map['read'] as bool?) ?? false,
      route: map['route']?.toString(),
      wallId: map['wallId']?.toString(),
      followerUid: map['followerUid']?.toString(),
      kind: InAppNotificationKind.values.where((kind) => kind.name == map['kind']).firstOrNull,
      copyKind: map['copyKind']?.toString(),
      copyArgs: toJsonMap(map['copyArgs']).cast<String, Object?>(),
    );
  }
}
