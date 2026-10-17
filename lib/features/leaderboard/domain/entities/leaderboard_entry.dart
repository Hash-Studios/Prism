import 'package:freezed_annotation/freezed_annotation.dart';

part 'leaderboard_entry.freezed.dart';

@freezed
abstract class LeaderboardEntry with _$LeaderboardEntry {
  const factory LeaderboardEntry({
    required String uid,
    required String name,
    required String username,
    required String photo,
    required int xp,
    required String rank,
    String? frameId,

    /// A Pro frame draws only for a premium profile.
    @Default(false) bool premium,
    @Default(false) bool isMe,
  }) = _LeaderboardEntry;
}
