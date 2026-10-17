import 'dart:math';

import 'package:Prism/auth/user_model.dart';
import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/coins/economy_config.dart';
import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/firestore/firestore_client.dart';
import 'package:Prism/core/firestore/firestore_collections.dart';
import 'package:Prism/core/firestore/firestore_query_specs.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/utils/json_utils.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/core/wallpaper/parse_helpers.dart';
import 'package:Prism/features/leaderboard/domain/entities/leaderboard_entry.dart';
import 'package:Prism/features/leaderboard/domain/repositories/leaderboard_repository.dart';
import 'package:injectable/injectable.dart';

@LazySingleton(as: LeaderboardRepository)
class LeaderboardRepositoryImpl implements LeaderboardRepository {
  LeaderboardRepositoryImpl(this._firestoreClient);

  final FirestoreClient _firestoreClient;

  static const int _maxEmails = 90;
  static const int _chunkSize = 30;

  @override
  Future<Result<List<LeaderboardEntry>>> fetchGlobal() async {
    try {
      final String myId = app_state.prismUser.id;
      final List<LeaderboardEntry> entries =
          await _firestoreClient.getById<List<LeaderboardEntry>>(FirebaseCollections.leaderboards, 'current', (
            data,
            _,
          ) {
            final Object? raw = data['entries'];
            return raw is List
                ? raw.map((Object? e) => _fromBoardEntry(toJsonMap(e), myId)).toList(growable: false)
                : const <LeaderboardEntry>[];
          }, sourceTag: 'leaderboard.global') ??
          const <LeaderboardEntry>[];
      return Result.success(entries);
    } catch (e) {
      return Result.error(ServerFailure("Couldn't load the leaderboard: $e"));
    }
  }

  @override
  Future<Result<List<LeaderboardEntry>>> fetchFriends(List<String> followingEmails, String currentWeekKey) async {
    try {
      final List<String> emails = followingEmails
          .map((String e) => e.trim())
          .where((String e) => e.isNotEmpty)
          .toSet()
          .take(_maxEmails)
          .toList(growable: false);
      final String myId = app_state.prismUser.id;
      final List<List<LeaderboardEntry>> chunks = await Future.wait(<Future<List<LeaderboardEntry>>>[
        for (int i = 0; i < emails.length; i += _chunkSize)
          _firestoreClient
              .query<LeaderboardEntry?>(
                FirestoreQuerySpec(
                  collection: FirebaseCollections.usersV2,
                  sourceTag: 'leaderboard.friends',
                  filters: <FirestoreFilter>[
                    FirestoreFilter(
                      field: 'email',
                      op: FirestoreFilterOp.whereIn,
                      value: emails.sublist(i, min(i + _chunkSize, emails.length)),
                    ),
                  ],
                ),
                (data, docId) => _fromUserDoc(data, docId, currentWeekKey, myId),
              )
              .then((List<LeaderboardEntry?> rows) => rows.nonNulls.toList(growable: false)),
      ]);
      final List<LeaderboardEntry> friends = <LeaderboardEntry>[
        for (final List<LeaderboardEntry> chunk in chunks) ...chunk.where((LeaderboardEntry e) => !e.isMe),
        if (myId.isNotEmpty) _myEntry(myId),
      ]..sort(_byXpThenUid);
      return Result.success(friends);
    } catch (e) {
      return Result.error(ServerFailure("Couldn't load your friends' ranks: $e"));
    }
  }

  static int _byXpThenUid(LeaderboardEntry a, LeaderboardEntry b) {
    final int byXp = b.xp.compareTo(a.xp);
    return byXp != 0 ? byXp : a.uid.compareTo(b.uid);
  }

  static LeaderboardEntry _fromBoardEntry(Map<String, dynamic> raw, String myId) {
    final String uid = raw['uid']?.toString() ?? '';
    return LeaderboardEntry(
      uid: uid,
      name: raw['name']?.toString() ?? '',
      username: raw['username']?.toString() ?? '',
      photo: raw['photo']?.toString() ?? '',
      xp: parseIntOr(raw['xp']),
      rank: raw['rank']?.toString() ?? '',
      frameId: _nonEmpty(raw['frame']),
      isMe: uid.isNotEmpty && uid == myId,
    );
  }

  static LeaderboardEntry? _fromUserDoc(Map<String, dynamic> data, String uid, String currentWeekKey, String myId) {
    if (data['deleted'] == true) return null;
    final Map<String, dynamic> week = toJsonMap(data['xpWeek']);
    return LeaderboardEntry(
      uid: uid,
      name: data['name']?.toString() ?? '',
      username: data['username']?.toString() ?? '',
      photo: data['profilePhoto']?.toString() ?? '',
      xp: week['weekKey'] == currentWeekKey ? parseIntOr(week['xp']) : 0,
      rank: EconomyConfig.current.rankFor(parseIntOr(data['xp'])).id,
      frameId: _nonEmpty(toJsonMap(data['cosmetics'])['frame']),
      isMe: uid == myId,
    );
  }

  static LeaderboardEntry _myEntry(String myId) {
    final CoinsService coins = CoinsService.instance;
    final PrismUsersV2 me = app_state.prismUser;
    return LeaderboardEntry(
      uid: myId,
      name: me.name,
      username: me.username,
      photo: me.profilePhoto,
      xp: coins.xpNotifier.value.weekXp,
      rank: coins.xpNotifier.value.rank.id,
      frameId: coins.inventoryNotifier.value.frame,
      isMe: true,
    );
  }

  static String? _nonEmpty(Object? value) {
    final String text = value?.toString().trim() ?? '';
    return text.isEmpty ? null : text;
  }
}
