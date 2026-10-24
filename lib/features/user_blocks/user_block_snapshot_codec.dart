import 'dart:convert';

import 'package:Prism/features/user_blocks/domain/repositories/user_block_repository.dart';

class UserBlockSnapshotCodec {
  const UserBlockSnapshotCodec._();

  static Map<String, Object?> encodeUids(Iterable<String> uids) => <String, Object?>{
    'version': 2,
    'uidsJson': jsonEncode(uids.toSet().toList()..sort()),
  };

  static Set<String> decodeUids(Map<String, Object?> record) {
    if (record['version'] != 2) return <String>{};
    return (jsonDecode(record['uidsJson']! as String) as List<Object?>).cast<String>().toSet();
  }

  static Map<String, Object?> encodeRows(Iterable<BlockedUserListRow> rows) => <String, Object?>{
    'rowsJson': jsonEncode(
      rows
          .map((row) => <String, Object?>{'blockedUid': row.blockedUid, 'blockedUsername': row.blockedUsername})
          .toList(growable: false),
    ),
  };

  static List<BlockedUserListRow> decodeRows(Map<String, Object?> record) =>
      (jsonDecode(record['rowsJson']! as String) as List<Object?>)
          .map((value) => Map<String, dynamic>.from(value as Map))
          .map(
            (row) => BlockedUserListRow(
              blockedUid: row['blockedUid'] as String,
              blockedUsername: row['blockedUsername'] as String?,
            ),
          )
          .toList(growable: false);
}
