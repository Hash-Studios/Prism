import 'dart:convert';
import 'dart:math';

/// One paid download whose file is not confirmed yet. [txId] names the debit, so a refund always targets this
/// payment and no other. [saved] turns true when the native save reported success. A saved entry is never refunded.
class PendingDownload {
  const PendingDownload({
    required this.txId,
    required this.userId,
    required this.link,
    required this.action,
    required this.at,
    this.saved = false,
  });

  final String txId;
  final String userId;
  final String link;
  final String action;

  /// When the payment started, in milliseconds since epoch. Zero when the stored value was missing or invalid.
  final int at;
  final bool saved;

  PendingDownload asSaved() =>
      PendingDownload(txId: txId, userId: userId, link: link, action: action, at: at, saved: true);

  /// How long to wait before this entry counts as abandoned. Zero for an entry of age, or one stamped more than
  /// [grace] ahead of the clock, which a clock set back or a missing time produces. An entry slightly ahead waits
  /// as if it were new.
  Duration remaining(int nowMs, Duration grace) {
    final int ageMs = nowMs - at;
    final int graceMs = grace.inMilliseconds;
    if (ageMs >= graceMs || ageMs < -graceMs) return Duration.zero;
    return Duration(milliseconds: graceMs - max(ageMs, 0));
  }

  Map<String, Object> toJson() => <String, Object>{
    'txId': txId,
    'userId': userId,
    'link': link,
    'action': action,
    'at': at,
    'saved': saved,
  };

  /// Null when [raw] is not a map or lacks a txId, userId or link.
  static PendingDownload? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final Object? txId = raw['txId'];
    final Object? userId = raw['userId'];
    final Object? link = raw['link'];
    if (txId is! String || txId.isEmpty || userId is! String || userId.isEmpty || link is! String || link.isEmpty) {
      return null;
    }
    final Object? action = raw['action'];
    final Object? at = raw['at'];
    return PendingDownload(
      txId: txId,
      userId: userId,
      link: link,
      action: action is String ? action : '',
      at: at is num ? at.toInt() : 0,
      saved: raw['saved'] == true,
    );
  }

  /// Entries in stored order, which is creation order. Unreadable input gives an empty list.
  static List<PendingDownload> decodeList(String raw) {
    if (raw.isEmpty) return <PendingDownload>[];
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is! List) return <PendingDownload>[];
      return <PendingDownload>[
        for (final Object? item in decoded)
          if (fromJson(item) case final PendingDownload entry) entry,
      ];
    } on FormatException {
      return <PendingDownload>[];
    }
  }

  static String encodeList(Iterable<PendingDownload> entries) =>
      jsonEncode(entries.map((PendingDownload entry) => entry.toJson()).toList());
}
