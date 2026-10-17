import 'dart:convert';

import 'package:Prism/features/user_blocks/domain/repositories/user_block_repository.dart';

class UserBlockSnapshotCodec {
  const UserBlockSnapshotCodec._();

  static Map<String, Object?> encodeEmails(Iterable<String> emails) => <String, Object?>{
    'emailsJson': jsonEncode(emails.toSet().toList()..sort()),
  };

  static Set<String> decodeEmails(Map<String, Object?> record) =>
      (jsonDecode(record['emailsJson']! as String) as List<Object?>).cast<String>().toSet();

  static Map<String, Object?> encodeRows(Iterable<BlockedUserListRow> rows) => <String, Object?>{
    'rowsJson': jsonEncode(
      rows
          .map(
            (row) => <String, Object?>{
              'blockedUid': row.blockedUid,
              'blockedEmail': row.blockedEmail,
              'blockedUsername': row.blockedUsername,
            },
          )
          .toList(growable: false),
    ),
  };

  static List<BlockedUserListRow> decodeRows(Map<String, Object?> record) =>
      (jsonDecode(record['rowsJson']! as String) as List<Object?>)
          .map((value) => Map<String, dynamic>.from(value as Map))
          .map(
            (row) => BlockedUserListRow(
              blockedUid: row['blockedUid'] as String,
              blockedEmail: row['blockedEmail'] as String,
              blockedUsername: row['blockedUsername'] as String?,
            ),
          )
          .toList(growable: false);
}
