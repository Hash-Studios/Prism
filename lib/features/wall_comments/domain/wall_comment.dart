import 'package:Prism/core/wallpaper/parse_helpers.dart';

/// One visible comment under a wall. The server owns every field.
final class WallComment {
  const WallComment({
    required this.id,
    required this.authorUid,
    required this.authorName,
    required this.authorPhoto,
    required this.text,
    required this.createdAt,
    this.pending = false,
  });

  factory WallComment.fromMap(Map<String, dynamic> data, String id) => WallComment(
    id: id,
    authorUid: data['authorUid'] is String ? data['authorUid']! as String : '',
    authorName: data['authorName'] is String ? data['authorName']! as String : '',
    authorPhoto: data['authorPhoto'] is String ? data['authorPhoto']! as String : '',
    text: data['text'] is String ? data['text']! as String : '',
    createdAt: switch (data['createdAtMs']) {
      final num ms => DateTime.fromMillisecondsSinceEpoch(ms.toInt()),
      _ => parseDateTime(data['createdAt']) ?? DateTime.fromMillisecondsSinceEpoch(0),
    },
  );

  final String id;
  final String authorUid;
  final String authorName;
  final String authorPhoto;
  final String text;
  final DateTime createdAt;

  /// True while the add call runs. The row shows at once and leaves again if the server refuses it.
  final bool pending;
}

/// Why the server refused a comment. Each wire value is a reason code from `functions/src/comments.ts`.
enum CommentRefusal {
  disabled('comments_disabled'),
  guest('comment_guest'),
  tooNew('comment_too_new'),
  wallUnavailable('comment_wall_unavailable'),
  empty('comment_empty'),
  tooLong('comment_too_long'),
  hiddenCharacters('comment_hidden_characters'),
  blockedWord('comment_blocked_word'),
  blocked('comment_blocked'),
  tooFast('comment_too_fast'),
  dailyLimit('comment_daily_limit'),

  /// The call failed: no network, a timeout, or an answer the app does not know.
  failed('');

  const CommentRefusal(this.wire);

  final String wire;

  static CommentRefusal fromWire(Object? wire) =>
      values.firstWhere((CommentRefusal r) => r.wire == wire && r != failed, orElse: () => failed);
}

/// Same limit as the server, counted in characters a person sees (grapheme clusters).
const int kCommentMaxLength = 500;
