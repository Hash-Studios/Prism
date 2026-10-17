import 'dart:convert';

import 'package:Prism/core/persistence/data_sources/feed_cache_local_data_source.dart';
import 'package:Prism/core/utils/json_utils.dart';

class CachedCollectionWalls {
  const CachedCollectionWalls({required this.items, required this.lastDocId, required this.hasMore});

  final List<Map<String, dynamic>> items;
  final String? lastDocId;
  final bool hasMore;
}

class OfflineSnapshotCodec {
  static const int maxCollectionRecords = 100;
  static const int maxCollectionWalls = 240;
  static const int maxSnapshotBytes = FeedCacheLocalDataSource.maxSnapshotBytes;

  static List<Map<String, dynamic>> decodeCollectionIndex(FeedSnapshot? snapshot) {
    final Object? raw = toJsonMap(snapshot?.payload)['items'];
    if (raw is! List) return <Map<String, dynamic>>[];
    return raw.whereType<Map>().map((entry) => toJsonMap(entry)).toList(growable: false);
  }

  static Map<String, Object?> encodeCollectionIndex(List<Map<String, dynamic>> items) {
    final List<Map<String, dynamic>> bounded = items.take(maxCollectionRecords).toList(growable: true);
    while (bounded.length > 1 && !_fitsSnapshot(<String, Object?>{'items': bounded}, ttlHours: 24)) {
      bounded.removeLast();
    }
    return <String, Object?>{'items': bounded};
  }

  static CachedCollectionWalls? decodeCollectionWalls(FeedSnapshot? snapshot) {
    final Map<String, dynamic> payload = toJsonMap(snapshot?.payload);
    final Object? raw = payload['items'];
    if (raw is! List) return null;
    return CachedCollectionWalls(
      items: raw.whereType<Map>().map((entry) => toJsonMap(entry)).toList(growable: false),
      lastDocId: payload['lastDocId']?.toString(),
      hasMore: payload['hasMore'] == true,
    );
  }

  static Map<String, Object?> encodeCollectionWalls({
    required List<Map<String, dynamic>> items,
    required String? lastDocId,
    required bool hasMore,
    int preserveLastItemsCount = 0,
  }) {
    final List<Map<String, dynamic>> bounded = items.toList(growable: true);
    final int preservedCount = preserveLastItemsCount.clamp(0, bounded.length).toInt();
    while (bounded.length > maxCollectionWalls ||
        !_fitsSnapshot(<String, Object?>{'items': bounded, 'lastDocId': lastDocId, 'hasMore': hasMore}, ttlHours: 24)) {
      if (bounded.length <= preservedCount) break;
      bounded.removeAt(0);
    }
    return <String, Object?>{'items': bounded, 'lastDocId': lastDocId, 'hasMore': hasMore};
  }

  static Map<String, Object?> encodePrismFeed({
    required FeedSnapshot? previous,
    required List<Map<String, Object?>> rows,
    required bool append,
    required bool hasMore,
    required String? lastDocId,
  }) {
    final List<Map<String, Object?>> merged = <Map<String, Object?>>[];
    final Object? previousRows = toJsonMap(previous?.payload)['rows'];
    if (append && previousRows is List) {
      merged.addAll(previousRows.whereType<Map>().map((row) => Map<String, Object?>.from(row)));
    }
    final Map<String, Map<String, Object?>> unique = <String, Map<String, Object?>>{
      for (final Map<String, Object?> row in merged) row['docId']?.toString() ?? '': row,
      for (final Map<String, Object?> row in rows) row['docId']?.toString() ?? '': row,
    };
    final List<Map<String, Object?>> bounded = unique.values.toList(growable: true);
    while (bounded.length > maxCollectionWalls ||
        !_fitsSnapshot(<String, Object?>{'rows': bounded, 'hasMore': hasMore, 'lastDocId': lastDocId}, ttlHours: 6)) {
      if (bounded.length <= rows.length) break;
      bounded.removeAt(0);
    }
    return <String, Object?>{'rows': bounded, 'hasMore': hasMore, 'lastDocId': lastDocId};
  }

  static bool _fitsSnapshot(Map<String, Object?> payload, {required int ttlHours}) =>
      utf8
          .encode(
            jsonEncode(<String, Object?>{
              'cachedAtUtc': DateTime.now().toUtc().toIso8601String(),
              'ttlHours': ttlHours,
              'payload': payload,
            }),
          )
          .length <=
      maxSnapshotBytes;
}
