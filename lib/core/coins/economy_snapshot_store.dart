import 'package:Prism/core/offline/durable_json_store.dart';

class EconomySnapshotStore {
  EconomySnapshotStore({DurableJsonStore? store}) : _store = store ?? DurableJsonStore('private_economy');

  static const List<String> _privateFields = <String>[
    'quests',
    'inventory',
    'drops',
    'passes',
    'graceDownloadsUsed',
    'spinWheel',
  ];

  final DurableJsonStore _store;
  Future<void> _writeTail = Future<void>.value();
  final Map<String, int> _generations = <String, int>{};

  Future<EconomySnapshot?> read(String ownerId) async {
    if (ownerId.isEmpty) return null;
    final Map<String, Object?>? record = await _store.read(ownerId);
    if (record == null || record['ownerId'] != ownerId || record['rev'] is! int || record['data'] is! Map) {
      return null;
    }
    final Map<String, dynamic> data = _jsonMap(record['data']);
    return EconomySnapshot(ownerId: ownerId, revision: record['rev'] as int, data: data);
  }

  Future<Map<String, dynamic>?> readRoot(String ownerId) async {
    if (ownerId.isEmpty) return null;
    final Map<String, Object?>? record = await _store.read(_rootKey(ownerId));
    if (record == null || record['ownerId'] != ownerId || record['data'] is! Map) return null;
    return _jsonMap(record['data']);
  }

  Future<void> writeRoot(String ownerId, Map<String, dynamic> data, {bool merge = false}) {
    if (ownerId.isEmpty) return Future<void>.value();
    final int generation = _generations[ownerId] ?? 0;
    final Map<String, dynamic> safeData = <String, dynamic>{
      for (final String field in const <String>['xp', 'xpWeek', 'cosmetics'])
        if (data.containsKey(field)) field: data[field],
    };
    return _serialize(() async {
      if ((_generations[ownerId] ?? 0) != generation) return;
      final Map<String, dynamic>? previous = merge ? await readRoot(ownerId) : null;
      if ((_generations[ownerId] ?? 0) != generation) return;
      await _store.write(_rootKey(ownerId), <String, Object?>{
        'ownerId': ownerId,
        'data': <String, dynamic>{...?previous, ...safeData},
      });
    });
  }

  Future<void> write(String ownerId, int revision, Map<String, dynamic> data) {
    if (ownerId.isEmpty || revision < 0) return Future<void>.value();
    final Map<String, dynamic> safeData = <String, dynamic>{};
    for (final String field in _privateFields) {
      if (data.containsKey(field)) safeData[field] = data[field];
    }
    final int generation = _generations[ownerId] ?? 0;
    return _serialize(() => _writeMerged(ownerId, revision, generation, safeData));
  }

  Future<void> _writeMerged(String ownerId, int revision, int generation, Map<String, dynamic> data) async {
    final EconomySnapshot? previous = await read(ownerId);
    if ((_generations[ownerId] ?? 0) != generation) return;
    if (previous != null && previous.revision > revision) return;
    final Map<String, dynamic> safeData = <String, dynamic>{...?previous?.data, ...data, 'rev': revision};
    await _store.write(ownerId, <String, Object?>{'ownerId': ownerId, 'rev': revision, 'data': safeData});
  }

  Future<void> replace(String ownerId, int revision, Map<String, dynamic> data) {
    if (ownerId.isEmpty || revision < 0) return Future<void>.value();
    final int generation = _generations[ownerId] ?? 0;
    final Map<String, dynamic> safeData = <String, dynamic>{
      for (final String field in _privateFields)
        if (data.containsKey(field)) field: data[field],
      'rev': revision,
    };
    return _serialize(() async {
      if ((_generations[ownerId] ?? 0) != generation) return;
      final EconomySnapshot? previous = await read(ownerId);
      if ((_generations[ownerId] ?? 0) != generation || (previous != null && previous.revision > revision)) return;
      await _store.write(ownerId, <String, Object?>{'ownerId': ownerId, 'rev': revision, 'data': safeData});
    });
  }

  Future<void> clearForUser(String ownerId) {
    if (ownerId.isEmpty) return Future<void>.value();
    _generations[ownerId] = (_generations[ownerId] ?? 0) + 1;
    return _serialize(() async {
      try {
        await _store.delete(ownerId);
      } finally {
        await _store.delete(_rootKey(ownerId));
      }
    });
  }

  Future<void> invalidateForUser(String ownerId) {
    if (ownerId.isEmpty) return Future<void>.value();
    _generations[ownerId] = (_generations[ownerId] ?? 0) + 1;
    return _serialize(() => _store.delete(ownerId));
  }

  Future<void> _serialize(Future<void> Function() operation) {
    final Future<void> result = _writeTail.then((_) => operation());
    _writeTail = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  static Map<String, dynamic> _jsonMap(Object? value) => <String, dynamic>{
    for (final MapEntry<Object?, Object?> entry in (value as Map).entries) entry.key.toString(): entry.value,
  };

  static String _rootKey(String ownerId) => 'root:$ownerId';
}

class EconomySnapshot {
  const EconomySnapshot({required this.ownerId, required this.revision, required this.data});

  final String ownerId;
  final int revision;
  final Map<String, dynamic> data;
}
