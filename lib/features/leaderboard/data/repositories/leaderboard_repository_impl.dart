import 'dart:async';
import 'dart:math';

import 'package:Prism/auth/user_model.dart';
import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/coins/economy_config.dart';
import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/firestore/firestore_client.dart';
import 'package:Prism/core/firestore/firestore_collections.dart';
import 'package:Prism/core/firestore/firestore_error.dart';
import 'package:Prism/core/firestore/firestore_query_specs.dart';
import 'package:Prism/core/firestore/firestore_server_read.dart';
import 'package:Prism/core/offline/durable_json_store.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/utils/json_utils.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/core/wallpaper/parse_helpers.dart';
import 'package:Prism/features/leaderboard/domain/entities/leaderboard_entry.dart';
import 'package:Prism/features/leaderboard/domain/repositories/leaderboard_repository.dart';
import 'package:injectable/injectable.dart';

@LazySingleton(as: LeaderboardRepository)
class LeaderboardRepositoryImpl implements LeaderboardRepository {
  LeaderboardRepositoryImpl(
    this._firestoreClient, {
    @ignoreParam DurableJsonStore? store,
    @ignoreParam Duration readTimeout = _sdkReadTimeout,
  }) : _store = store ?? DurableJsonStore('leaderboard_read_snapshots'),
       _readTimeout = readTimeout;

  final FirestoreClient _firestoreClient;
  final DurableJsonStore _store;
  final Duration _readTimeout;

  static const int _maxEmails = 90;
  static const int _chunkSize = 30;
  static const Duration _sdkReadTimeout = Duration(seconds: 5);
  static const String _globalKey = 'global';
  static const int _maxEntries = 100;
  static final Map<String, int> _friendGenerations = <String, int>{};
  static final Map<String, Future<void>> _friendPersistenceTails = <String, Future<void>>{};

  @override
  Future<Result<List<LeaderboardEntry>>> fetchGlobal() async {
    final String ownerAtStart = app_state.prismUser.id;
    try {
      final String myId = ownerAtStart;
      final List<LeaderboardEntry> entries =
          await _firestoreClient
              .getFromServer<List<LeaderboardEntry>>(
                FirebaseCollections.leaderboards,
                'current',
                (data, _) {
                  final Object? raw = data['entries'];
                  return raw is List
                      ? raw.map((Object? e) => _fromBoardEntry(toJsonMap(e), myId)).toList(growable: false)
                      : const <LeaderboardEntry>[];
                },
                sourceTag: 'leaderboard.global',
                timeout: _readTimeout,
              )
              .timeout(_readTimeout) ??
          const <LeaderboardEntry>[];
      if (app_state.prismUser.id != ownerAtStart) {
        return Result.error(const ServerFailure("Couldn't load the leaderboard: account changed during the request."));
      }
      try {
        await _store.write(_globalKey, <String, Object?>{
          'entries': entries.take(_maxEntries).map(_toMap).toList(growable: false),
        });
      } on Object {}
      if (app_state.prismUser.id != ownerAtStart) {
        return Result.error(const ServerFailure("Couldn't load the leaderboard: account changed during the request."));
      }
      return Result.success(entries);
    } catch (e) {
      Object? raw;
      try {
        raw = (await _store.read(_globalKey))?['entries'];
      } on Object {
        return Result.error(ServerFailure("Couldn't load the leaderboard: $e"));
      }
      if (_isTransient(e) && raw is List) {
        final String myId = app_state.prismUser.id;
        return Result.success(
          raw.whereType<Map>().take(_maxEntries).map((Map item) => _fromStored(item, myId)).toList(),
        );
      }
      if (_isPermissionDenied(e)) {
        try {
          await _store.delete(_globalKey);
        } on Object {}
      }
      return Result.error(ServerFailure("Couldn't load the leaderboard: $e"));
    }
  }

  @override
  Future<Result<List<LeaderboardEntry>>> fetchFriends(List<String> followingEmails, String currentWeekKey) async {
    final String ownerAtStart = app_state.prismUser.loggedIn ? app_state.prismUser.id : '';
    final int generationAtStart = _friendGenerations[ownerAtStart] ?? 0;
    try {
      final List<String> emails = _normalizeEmails(followingEmails);
      final String myId = ownerAtStart;
      if (!app_state.prismUser.loggedIn || myId.isEmpty) {
        return Result.error(const ServerFailure("Couldn't load your friends' ranks: account is not signed in."));
      }
      final List<List<LeaderboardEntry>> chunks = await Future.wait(<Future<List<LeaderboardEntry>>>[
        for (int i = 0; i < emails.length; i += _chunkSize)
          _firestoreClient
              .queryFromServer<LeaderboardEntry?>(
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
                timeout: _readTimeout,
              )
              .then((List<LeaderboardEntry?> rows) => rows.nonNulls.toList(growable: false)),
      ]).timeout(_readTimeout);
      if (!app_state.prismUser.loggedIn ||
          app_state.prismUser.id != myId ||
          (_friendGenerations[myId] ?? 0) != generationAtStart) {
        return Result.error(
          const ServerFailure("Couldn't load your friends' ranks: account changed during the request."),
        );
      }
      final List<LeaderboardEntry> friends = <LeaderboardEntry>[
        for (final List<LeaderboardEntry> chunk in chunks) ...chunk.where((LeaderboardEntry e) => !e.isMe),
        if (myId.isNotEmpty) _myEntry(myId),
      ]..sort(_byXpThenUid);
      if (!app_state.prismUser.loggedIn ||
          app_state.prismUser.id != myId ||
          (_friendGenerations[myId] ?? 0) != generationAtStart) {
        return Result.error(
          const ServerFailure("Couldn't load your friends' ranks: account changed during the request."),
        );
      }
      try {
        await _serializeFriendPersistence(myId, () async {
          if (!_isFriendRequestCurrent(myId, generationAtStart)) return;
          await _store.write('friends:$myId', <String, Object?>{
            'weekKey': currentWeekKey,
            'emails': emails,
            'entries': friends.take(_maxEntries).map(_toMap).toList(growable: false),
          });
        });
      } on Object {}
      if (!app_state.prismUser.loggedIn ||
          app_state.prismUser.id != myId ||
          (_friendGenerations[myId] ?? 0) != generationAtStart) {
        return Result.error(
          const ServerFailure("Couldn't load your friends' ranks: account changed during the request."),
        );
      }
      return Result.success(friends);
    } catch (e) {
      final String activeUid = ownerAtStart;
      if (activeUid.isEmpty) {
        return Result.error(ServerFailure("Couldn't load your friends' ranks: $e"));
      }
      if (!app_state.prismUser.loggedIn ||
          app_state.prismUser.id != activeUid ||
          (_friendGenerations[activeUid] ?? 0) != generationAtStart) {
        return Result.error(
          const ServerFailure("Couldn't load your friends' ranks: account changed during the request."),
        );
      }
      Object? raw;
      try {
        raw = await _store.read('friends:$activeUid');
      } on Object {
        return Result.error(ServerFailure("Couldn't load your friends' ranks: $e"));
      }
      if (!app_state.prismUser.loggedIn ||
          app_state.prismUser.id != activeUid ||
          (_friendGenerations[activeUid] ?? 0) != generationAtStart) {
        return Result.error(
          const ServerFailure("Couldn't load your friends' ranks: account changed during the request."),
        );
      }
      if (_isTransient(e) &&
          raw is Map &&
          raw['weekKey'] == currentWeekKey &&
          _sameEmails(raw['emails'], _normalizeEmails(followingEmails))) {
        final Object? rows = raw['entries'];
        if (rows is List) {
          return Result.success(
            rows.whereType<Map>().take(_maxEntries).map((Map item) => _fromStored(item, activeUid)).toList(),
          );
        }
      }
      if (_isPermissionDenied(e)) {
        try {
          await _serializeFriendPersistence(activeUid, () async {
            if (_isFriendRequestCurrent(activeUid, generationAtStart)) {
              await _store.delete('friends:$activeUid');
            }
          });
        } on Object {}
      }
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
      premium: raw['premium'] == true,
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
      premium: data['premium'] == true,
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
      premium: me.premium,
      isMe: true,
    );
  }

  static String? _nonEmpty(Object? value) {
    final String text = value?.toString().trim() ?? '';
    return text.isEmpty ? null : text;
  }

  static Future<void> clearForUser(String uid, {DurableJsonStore? store}) async {
    _friendGenerations[uid] = (_friendGenerations[uid] ?? 0) + 1;
    final int generation = _friendGenerations[uid]!;
    await _serializeFriendPersistence(uid, () async {
      if ((_friendGenerations[uid] ?? 0) == generation) {
        await (store ?? DurableJsonStore('leaderboard_read_snapshots')).delete('friends:$uid');
      }
    });
  }

  static Future<void> _serializeFriendPersistence(String uid, Future<void> Function() operation) {
    final Future<void> result = (_friendPersistenceTails[uid] ?? Future<void>.value()).then((_) => operation());
    _friendPersistenceTails[uid] = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  static bool _isFriendRequestCurrent(String uid, int generation) =>
      app_state.prismUser.loggedIn && app_state.prismUser.id == uid && (_friendGenerations[uid] ?? 0) == generation;

  static Map<String, Object?> _toMap(LeaderboardEntry entry) => <String, Object?>{
    'uid': entry.uid,
    'name': entry.name,
    'username': entry.username,
    'photo': entry.photo,
    'xp': entry.xp,
    'rank': entry.rank,
    'frameId': entry.frameId,
    'premium': entry.premium,
  };

  static LeaderboardEntry _fromStored(Map raw, String myId) => LeaderboardEntry(
    uid: raw['uid']?.toString() ?? '',
    name: raw['name']?.toString() ?? '',
    username: raw['username']?.toString() ?? '',
    photo: raw['photo']?.toString() ?? '',
    xp: parseIntOr(raw['xp']),
    rank: raw['rank']?.toString() ?? '',
    frameId: _nonEmpty(raw['frameId']),
    premium: raw['premium'] == true,
    isMe: raw['uid'] == myId && myId.isNotEmpty,
  );

  static bool _sameEmails(Object? saved, List<String> requested) =>
      saved is List &&
      saved.length == requested.length &&
      saved.asMap().entries.every((e) => e.value == requested[e.key]);

  static List<String> _normalizeEmails(List<String> emails) => emails
      .map((String email) => email.trim())
      .where((String email) => email.isNotEmpty)
      .toSet()
      .take(_maxEmails)
      .toList(growable: false);

  static bool _isTransient(Object error) =>
      error is TimeoutException ||
      const <String>{
        'unavailable',
        'deadline-exceeded',
        'network-request-failed',
        'internal',
        'resource-exhausted',
      }.contains(error is FirestoreError ? error.code : null);

  static bool _isPermissionDenied(Object error) => error is FirestoreError && error.code == 'permission-denied';
}
