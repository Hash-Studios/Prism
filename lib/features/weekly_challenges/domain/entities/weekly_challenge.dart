import 'package:Prism/core/wallpaper/wallpaper_variants.dart';

enum ChallengeState { scheduled, open, votingClosed, winnerPicked, archived }

enum ChallengeSort { top, newest }

enum ChallengeEntrySource {
  upload,
  ai;

  String get wireValue => name;
}

enum ChallengeError { signedOut, dailyLimit, ownEntry, closed, entryLimit, missing, unknown }

class ChallengeException implements Exception {
  const ChallengeException(this.error);
  final ChallengeError error;
}

class ChallengeSeed {
  const ChallengeSeed({required this.id, required this.theme});
  final String id;
  final String theme;
}

class ChallengeEntry {
  const ChallengeEntry({
    required this.id,
    required this.wallId,
    required this.wallLogicalId,
    required this.creatorUid,
    required this.creatorName,
    required this.thumbUrl,
    required this.title,
    required this.voteCount,
    required this.approvedAt,
    required this.voted,
    required this.mine,
    this.wall,
  });
  factory ChallengeEntry.fromMap(Map<String, Object?> map) => ChallengeEntry(
    id: map['id']! as String,
    wallId: map['wallId']! as String,
    wallLogicalId: map['wallLogicalId']! as String,
    creatorUid: map['creatorUid']! as String,
    creatorName: map['creatorName']! as String,
    thumbUrl: map['thumbUrl']! as String,
    title: map['title']! as String,
    voteCount: (map['voteCount']! as num).toInt(),
    approvedAt: DateTime.fromMillisecondsSinceEpoch((map['approvedAtMs']! as num).toInt(), isUtc: true),
    voted: map['voted'] == true,
    mine: map['mine'] == true,
  );
  final String id;
  final String wallId;
  final String wallLogicalId;
  final String creatorUid;
  final String creatorName;
  final String thumbUrl;
  final String title;
  final int voteCount;
  final DateTime approvedAt;
  final bool voted;
  final bool mine;
  final PrismWallpaper? wall;
  ChallengeEntry copyWith({bool? voted, int? voteCount, PrismWallpaper? wall}) => ChallengeEntry(
    id: id,
    wallId: wallId,
    wallLogicalId: wallLogicalId,
    creatorUid: creatorUid,
    creatorName: creatorName,
    thumbUrl: thumbUrl,
    title: title,
    voteCount: voteCount ?? this.voteCount,
    approvedAt: approvedAt,
    voted: voted ?? this.voted,
    mine: mine,
    wall: wall ?? this.wall,
  );
}

class WeeklyChallenge {
  const WeeklyChallenge({
    required this.id,
    required this.theme,
    required this.state,
    required this.opensAt,
    required this.closesAt,
    this.winner,
    this.reservedDate,
    this.noWinner = false,
  });
  factory WeeklyChallenge.fromMap(Map<String, Object?> map) => WeeklyChallenge(
    id: map['id']! as String,
    theme: map['theme']! as String,
    state: switch (map['state']) {
      'open' => ChallengeState.open,
      'voting_closed' => ChallengeState.votingClosed,
      'winner_picked' => ChallengeState.winnerPicked,
      'archived' => ChallengeState.archived,
      'scheduled' => ChallengeState.scheduled,
      _ => throw const ChallengeException(ChallengeError.unknown),
    },
    opensAt: DateTime.fromMillisecondsSinceEpoch((map['opensAtMs']! as num).toInt(), isUtc: true),
    closesAt: DateTime.fromMillisecondsSinceEpoch((map['closesAtMs']! as num).toInt(), isUtc: true),
    winner: map['winner'] is Map ? ChallengeEntry.fromMap(Map<String, Object?>.from(map['winner']! as Map)) : null,
    reservedDate: map['reservedDate'] as String?,
    noWinner: map['noWinner'] == true,
  );
  final String id;
  final String theme;
  final ChallengeState state;
  final DateTime opensAt;
  final DateTime closesAt;
  final ChallengeEntry? winner;
  final String? reservedDate;
  final bool noWinner;
  bool isOpenAt(DateTime now) => state == ChallengeState.open && !now.isBefore(opensAt) && now.isBefore(closesAt);
  ChallengeSeed get seed => ChallengeSeed(id: id, theme: theme);
  WeeklyChallenge withWinner(ChallengeEntry? value) => WeeklyChallenge(
    id: id,
    theme: theme,
    state: state,
    opensAt: opensAt,
    closesAt: closesAt,
    winner: value,
    reservedDate: reservedDate,
    noWinner: noWinner,
  );
}

class ChallengeDetail {
  const ChallengeDetail({
    required this.challenge,
    required this.entries,
    required this.myEntryCount,
    this.myAdmittedWallIds = const [],
  });
  final WeeklyChallenge challenge;
  final List<ChallengeEntry> entries;
  final int myEntryCount;
  final List<String> myAdmittedWallIds;
}
