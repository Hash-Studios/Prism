import 'package:Prism/core/constants/app_functions.dart';
import 'package:Prism/core/user_blocks/blocked_creators.dart';
import 'package:Prism/core/user_blocks/blocked_creators_filter.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/features/wall_remix/data/wall_remix_repository.dart';
import 'package:Prism/features/weekly_challenges/biz/challenge_admission_tracker.dart';
import 'package:Prism/features/weekly_challenges/domain/entities/weekly_challenge.dart';
import 'package:Prism/features/weekly_challenges/domain/repositories/weekly_challenges_repository.dart';
import 'package:cloud_functions/cloud_functions.dart' as cf;
import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';

@LazySingleton(as: WeeklyChallengesRepository)
class WeeklyChallengesRepositoryImpl implements WeeklyChallengesRepository {
  WeeklyChallengesRepositoryImpl(this._walls, this._admission) : _call = _callable;
  @visibleForTesting
  WeeklyChallengesRepositoryImpl.withCaller(this._walls, this._admission, this._call);
  final WallRemixRepository _walls;
  final ChallengeAdmissionTracker _admission;
  final Future<Object?> Function(String, Map<String, Object?>) _call;
  static Future<Object?> _callable(String name, Map<String, Object?> data) async =>
      (await appFunctions
              .httpsCallable(name, options: cf.HttpsCallableOptions(timeout: const Duration(seconds: 20)))
              .call<Object?>(data))
          .data;
  Future<Map<String, Object?>> _invoke(String name, Map<String, Object?> args) async {
    try {
      return _map(await _call(name, args));
    } on cf.FirebaseFunctionsException catch (e) {
      throw ChallengeException(switch (e.code) {
        'unauthenticated' => ChallengeError.signedOut,
        'resource-exhausted' => ChallengeError.dailyLimit,
        'not-found' => ChallengeError.missing,
        'failed-precondition' when e.message == 'own-entry' => ChallengeError.ownEntry,
        'failed-precondition' when e.message == 'entry-limit' => ChallengeError.entryLimit,
        'failed-precondition' when e.message == 'challenge-closed' => ChallengeError.closed,
        _ => ChallengeError.unknown,
      });
    } on ChallengeException {
      rethrow;
    } catch (_) {
      throw const ChallengeException(ChallengeError.unknown);
    }
  }

  static Map<String, Object?> _map(Object? value) => Map<String, Object?>.from(value! as Map);
  Future<ChallengeEntry?> _hydrate(ChallengeEntry entry, BlockedCreators blocked) async {
    if (BlockedCreatorsFilter.hidesCreatorUid(entry.creatorUid, blocked)) return null;
    final PrismWallpaper? wall = await _walls.fetchApprovedWall(entry.wallId);
    if (wall == null ||
        wall.id != entry.wallLogicalId ||
        (wall.core.authorUid != null && wall.core.authorUid != entry.creatorUid) ||
        BlockedCreatorsFilter.hidesCreatorUid(wall.core.authorUid, blocked)) {
      return null;
    }
    return entry.copyWith(wall: wall);
  }

  Future<WeeklyChallenge> _challenge(Object? value, BlockedCreators blocked) async {
    final WeeklyChallenge challenge = WeeklyChallenge.fromMap(_map(value));
    return challenge.withWinner(challenge.winner == null ? null : await _hydrate(challenge.winner!, blocked));
  }

  @override
  Future<List<WeeklyChallenge>> list({required bool past}) async {
    final rows = <Object?>[];
    final cursors = <String>{};
    String? cursor;
    do {
      final body = await _invoke('listWeeklyChallenges', <String, Object?>{
        'kind': past ? 'past' : 'open',
        if (cursor != null) 'cursor': cursor,
      });
      rows.addAll(body['challenges']! as List);
      cursor = body['nextCursor'] as String?;
      if (cursor != null && !cursors.add(cursor)) throw const ChallengeException(ChallengeError.unknown);
    } while (cursor != null);
    final blocked = await _walls.loadBlockedCreators();
    return Future.wait(rows.map((Object? row) => _challenge(row, blocked)));
  }

  @override
  Future<ChallengeDetail> get(String challengeId, ChallengeSort sort) async {
    final allEntries = <Object?>[];
    final cursors = <String>{};
    Map<String, Object?> body;
    String? cursor;
    do {
      body = await _invoke('getWeeklyChallenge', <String, Object?>{
        'challengeId': challengeId,
        'sort': sort == ChallengeSort.top ? 'top' : 'new',
        if (cursor != null) 'cursor': cursor,
      });
      allEntries.addAll(body['entries']! as List);
      cursor = body['nextCursor'] as String?;
      if (cursor != null && !cursors.add(cursor)) throw const ChallengeException(ChallengeError.unknown);
    } while (cursor != null);
    final admitted = (body['myAdmittedWallIds'] as List?)?.whereType<String>().toList() ?? <String>[];
    try {
      await _admission.confirm(challengeId, admitted);
    } catch (_) {}
    final blocked = await _walls.loadBlockedCreators();
    final entries = await Future.wait(
      allEntries.map((Object? row) => _hydrate(ChallengeEntry.fromMap(_map(row)), blocked)),
    );
    return ChallengeDetail(
      challenge: await _challenge(body['challenge'], blocked),
      entries: {
        for (final entry in entries.whereType<ChallengeEntry>()) entry.id: entry,
      }.values.toList(growable: false),
      myEntryCount: (body['myEntryCount']! as num).toInt(),
      myAdmittedWallIds: admitted,
    );
  }

  @override
  Future<({bool voted, int voteCount})> setVote(String challengeId, String entryId, {required bool vote}) async {
    final body = await _invoke('setChallengeVote', <String, Object?>{
      'challengeId': challengeId,
      'entryId': entryId,
      'vote': vote,
    });
    return (voted: body['voted']! as bool, voteCount: (body['voteCount']! as num).toInt());
  }
}
