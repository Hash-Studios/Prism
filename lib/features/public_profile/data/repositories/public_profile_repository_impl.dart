import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/constants/app_functions.dart';
import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/firestore/converters/firestore_json_converters.dart';
import 'package:Prism/core/firestore/dtos/public_user_doc_dto.dart';
import 'package:Prism/core/firestore/dtos/wall_doc_dto.dart';
import 'package:Prism/core/firestore/firestore_client.dart';
import 'package:Prism/core/firestore/firestore_collections.dart';
import 'package:Prism/core/firestore/firestore_query_specs.dart';
import 'package:Prism/core/offline/durable_json_store.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/features/public_profile/domain/entities/public_profile_entity.dart';
import 'package:Prism/features/public_profile/domain/entities/public_profile_wall_entity.dart';
import 'package:Prism/features/public_profile/domain/entities/user_relation_kind.dart';
import 'package:Prism/features/public_profile/domain/entities/user_summary_entity.dart';
import 'package:Prism/features/public_profile/domain/public_profile_snapshot_codec.dart';
import 'package:Prism/features/public_profile/domain/repositories/public_profile_repository.dart';
import 'package:Prism/features/user_blocks/domain/repositories/user_block_repository.dart';
import 'package:crypto/crypto.dart';
import 'package:injectable/injectable.dart';

@LazySingleton(as: PublicProfileRepository)
class PublicProfileRepositoryImpl implements PublicProfileRepository {
  PublicProfileRepositoryImpl(
    this._firestoreClient,
    this._userBlockRepository, {
    @ignoreParam Future<void> Function(String, bool)? setFollow,
  }) : _setFollow = setFollow ?? _callSetFollow;

  final FirestoreClient _firestoreClient;
  final UserBlockRepository _userBlockRepository;
  final Future<void> Function(String targetUid, bool following) _setFollow;
  final DurableJsonStore _profileSnapshots = DurableJsonStore('public_profiles');
  final Map<String, Future<void>> _snapshotWriteTails = <String, Future<void>>{};
  final Set<String> _clearingSnapshotOwners = <String>{};
  final Map<String, String> _wallCursorByUid = <String, String>{};
  final Map<String, int> _wallGenerationByUid = <String, int>{};
  int? _wallSession;
  static const int _profileReadDedupeMs = 30000;
  static const int _searchChunkSize = 30;
  static const int _summariesPageSize = 20;
  static const int _searchLimit = 5;

  @override
  Stream<PublicProfileEntity?> watchProfile(String identifier) {
    final String value = identifier.trim();
    return _watchProfileWithCache(value);
  }

  @override
  Future<void> clearForUser(String userId) async {
    final String owner = userId.trim();
    if (owner.isEmpty) return;
    _clearingSnapshotOwners.add(owner);
    await _serializeSnapshotWrite(owner, () async {
      final Map<String, Map<String, Object?>> records = await _profileSnapshots.readAll();
      for (final String key in records.keys.where(
        (key) => key.startsWith('$owner::') || key.startsWith('v2::$owner::') || key.startsWith('v3::$owner::'),
      )) {
        await _profileSnapshots.delete(key);
      }
    }, allowClearing: true);
  }

  Stream<PublicProfileEntity?> _watchProfileWithCache(String value) {
    final String owner = _snapshotOwner;
    final String key = 'v2::$owner::$value';
    if (value.contains('@')) return Stream<PublicProfileEntity?>.value(null);
    return Stream<PublicProfileEntity?>.multi((controller) {
      var cancelled = false;
      StreamSubscription<List<_UserRow>>? subscription;
      StreamSubscription<bool>? followSubscription;
      bool isFollowed = false;
      PublicProfileEntity? baseProfile;

      void publishProfile() {
        final PublicProfileEntity? base = baseProfile;
        if (base == null || cancelled || _snapshotOwner != owner) return;
        controller.add(
          PublicProfileEntity(
            id: base.id,
            name: base.name,
            email: '',
            username: base.username,
            profilePhoto: base.profilePhoto,
            bio: base.bio,
            links: base.links,
            coverPhoto: base.coverPhoto,
            followerCount: base.followerCount,
            followingCount: base.followingCount,
            isFollowedByCurrentUser: isFollowed,
            badges: base.badges,
            frameId: base.frameId,
            nameGlowId: base.nameGlowId,
            xp: base.xp,
          ),
        );
      }

      controller.onCancel = () async {
        cancelled = true;
        await Future.wait<void>(<Future<void>>[
          if (subscription != null) subscription!.cancel(),
          if (followSubscription != null) followSubscription!.cancel(),
        ]);
      };

      unawaited(() async {
        try {
          final String? uid = await _resolveProfileUid(value);
          if (cancelled) return;
          if (uid == null) {
            await _deleteSnapshot(owner, key);
            controller.add(null);
            return;
          }
          final Map<String, Object?>? cached = await _profileSnapshots.read(key);
          if (cancelled || _snapshotOwner != owner) return;
          if (cached != null) {
            final PublicProfileEntity candidate = _profileFromMap(cached);
            if (candidate.id == uid && candidate.name.trim().isNotEmpty && candidate.username.trim().isNotEmpty) {
              baseProfile = candidate;
              publishProfile();
            } else {
              await _deleteSnapshot(owner, key);
            }
          }
          final String viewerUid = app_state.prismUser.loggedIn ? app_state.prismUser.id.trim() : '';
          if (viewerUid.isNotEmpty && viewerUid != uid) {
            followSubscription = _watchFollowingEdge(viewerUid, uid).listen((value) {
              isFollowed = value;
              publishProfile();
            }, onError: controller.addError);
          }
          subscription = _firestoreClient
              .watchQuery<_UserRow>(
                FirestoreQuerySpec(
                  collection: FirebaseCollections.profiles,
                  sourceTag: 'profile.stream.public_projection',
                  filters: <FirestoreFilter>[
                    FirestoreFilter(field: firestoreDocumentIdField, op: FirestoreFilterOp.isEqualTo, value: uid),
                  ],
                  limit: 1,
                  isStream: true,
                ),
                (data, docId) => _UserRow(docId: docId, doc: PublicUserDocDto.fromJson(data)),
              )
              .listen((rows) async {
                if (cancelled || _snapshotOwner != owner) return;
                if (rows.isEmpty) {
                  baseProfile = null;
                  unawaited(_deleteSnapshot(owner, key));
                  controller.add(null);
                  return;
                }
                final PublicUserDocDto doc = rows.first.doc;
                if (doc.name.trim().isEmpty || doc.username.trim().isEmpty) {
                  baseProfile = null;
                  unawaited(_deleteSnapshot(owner, key));
                  controller.add(null);
                  return;
                }
                baseProfile = PublicProfileEntity(
                  id: rows.first.docId,
                  name: doc.name,
                  email: '',
                  username: doc.username,
                  profilePhoto: doc.profilePhoto,
                  bio: doc.bio,
                  links: doc.links,
                  coverPhoto: doc.coverPhoto,
                  followerCount: doc.followerCount,
                  followingCount: doc.followingCount,
                  badges: doc.badges,
                  frameId: _cosmeticId(doc.cosmetics['frame']),
                  nameGlowId: _cosmeticId(doc.cosmetics['nameGlow']),
                  xp: doc.xp,
                );
                try {
                  await _writeSnapshot(owner, key, _profileToMap(baseProfile!));
                } catch (_) {}
                publishProfile();
              }, onError: controller.addError);
          await Future.wait<void>(<Future<void>>[
            subscription!.asFuture<void>(),
            if (followSubscription != null) followSubscription!.asFuture<void>(),
          ]);
        } catch (error, stackTrace) {
          if (!cancelled) controller.addError(error, stackTrace);
        } finally {
          if (!cancelled) controller.close();
        }
      }());
    });
  }

  Stream<bool> _watchFollowingEdge(String currentUserId, String targetUserId) => _firestoreClient
      .watchQuery<String>(
        FirestoreQuerySpec(
          collection: FirebaseCollections.profileFollowing(currentUserId),
          sourceTag: 'profile.following_edge',
          filters: <FirestoreFilter>[
            FirestoreFilter(field: firestoreDocumentIdField, op: FirestoreFilterOp.isEqualTo, value: targetUserId),
          ],
          limit: 1,
          isStream: true,
        ),
        (_, docId) => docId,
      )
      .map((rows) => rows.isNotEmpty);

  Future<String?> _resolveProfileUid(String identifier) async {
    final Map<String, dynamic>? directProfile = await _firestoreClient.getById<Map<String, dynamic>>(
      FirebaseCollections.profiles,
      identifier,
      (data, _) => data,
      sourceTag: 'profile.resolve_by_uid',
    );
    if (directProfile != null &&
        directProfile['name'] is String &&
        (directProfile['name'] as String).trim().isNotEmpty) {
      return identifier;
    }
    final String? registeredUid = await _firestoreClient
        .getById<String>(
          FirebaseCollections.usernames,
          identifier.toLowerCase(),
          (data, _) => data['uid'] is String ? data['uid'] as String : '',
          sourceTag: 'profile.resolve_username',
        )
        .then((uid) => uid?.isNotEmpty == true ? uid : null);
    if (registeredUid != null) return registeredUid;

    // Older public profiles predate the username registry. Only resolve when the allowlisted projection
    // has one unambiguous exact username match.
    final Set<String> matches = <String>{};
    for (final String username in <String>{identifier, identifier.toLowerCase()}) {
      final List<_UserRow> rows = await _firestoreClient.query<_UserRow>(
        FirestoreQuerySpec(
          collection: FirebaseCollections.profiles,
          sourceTag: 'profile.resolve_legacy_username',
          filters: <FirestoreFilter>[
            FirestoreFilter(field: 'username', op: FirestoreFilterOp.isEqualTo, value: username),
          ],
          limit: 2,
        ),
        (data, docId) => _UserRow(docId: docId, doc: PublicUserDocDto.fromJson(data)),
      );
      matches.addAll(rows.map((row) => row.docId));
    }
    return matches.length == 1 ? matches.single : null;
  }

  PublicProfileEntity _profileFromMap(Map<String, Object?> data) => PublicProfileEntity(
    id: data['id']?.toString() ?? '',
    name: data['name']?.toString() ?? '',
    email: '',
    username: data['username']?.toString() ?? '',
    profilePhoto: data['profilePhoto']?.toString() ?? '',
    bio: data['bio']?.toString() ?? '',
    links: Map<String, String>.from(data['links'] as Map? ?? const <String, String>{}),
    coverPhoto: data['coverPhoto']?.toString() ?? '',
    followerCount: data['followerCount'] is int ? data['followerCount']! as int : 0,
    followingCount: data['followingCount'] is int ? data['followingCount']! as int : 0,
    badges: const FirestoreStringListConverter().fromJson(data['badges']),
    frameId: _cosmeticId(data['frameId']?.toString()),
    nameGlowId: _cosmeticId(data['nameGlowId']?.toString()),
    xp: data['xp'] is int ? data['xp']! as int : 0,
  );

  String? _cosmeticId(String? id) => id == null || id.isEmpty ? null : id;

  Map<String, Object?> _profileToMap(PublicProfileEntity profile) => <String, Object?>{
    'id': profile.id,
    'name': profile.name,
    'username': profile.username,
    'profilePhoto': profile.profilePhoto,
    'bio': profile.bio,
    'links': profile.links,
    'followerCount': profile.followerCount,
    'followingCount': profile.followingCount,
    'coverPhoto': profile.coverPhoto,
    'badges': profile.badges,
    'frameId': profile.frameId,
    'nameGlowId': profile.nameGlowId,
    'xp': profile.xp,
  };

  Future<void> _writeSnapshot(String owner, String key, Map<String, Object?> value) =>
      _serializeSnapshotWrite(owner, () => _profileSnapshots.write(key, value));

  Future<void> _deleteSnapshot(String owner, String key) async {
    try {
      await _serializeSnapshotWrite(owner, () => _profileSnapshots.delete(key));
    } catch (_) {}
  }

  Future<void> _serializeSnapshotWrite(String owner, Future<void> Function() action, {bool allowClearing = false}) {
    final Future<void> previous = _snapshotWriteTails[owner] ?? Future<void>.value();
    final Future<void> next = previous.catchError((Object _) {}).then((_) async {
      if (!allowClearing && _clearingSnapshotOwners.contains(owner)) return;
      await action();
    });
    final Future<void> tail = next.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    _snapshotWriteTails[owner] = tail;
    return next.whenComplete(() {
      if (identical(_snapshotWriteTails[owner], tail)) _snapshotWriteTails.remove(owner);
    });
  }

  @override
  Future<Result<({List<PublicProfileWallEntity> items, bool hasMore})>> fetchWalls({
    required String userId,
    required bool refresh,
  }) async {
    final String owner = _snapshotOwner;
    final int session = CoinsService.instance.economySession;
    if (_wallSession != session) {
      _wallSession = session;
      _wallCursorByUid.clear();
      _wallGenerationByUid.clear();
    }
    final String uid = userId.trim();
    if (uid.isEmpty || uid.contains('@')) {
      return Result.success((items: const <PublicProfileWallEntity>[], hasMore: false));
    }
    final String cursorKey = '$owner::$uid';
    final int generation = (_wallGenerationByUid[cursorKey] ?? 0) + (refresh ? 1 : 0);
    _wallGenerationByUid[cursorKey] = generation;
    if (refresh) _wallCursorByUid.remove(cursorKey);
    bool isCurrent() =>
        _snapshotOwner == owner &&
        CoinsService.instance.economySession == session &&
        _wallGenerationByUid[cursorKey] == generation;
    final String snapshotKey = 'v2::$owner::walls:$uid';
    final blockedResult = await _userBlockRepository.fetchBlockedUsersList();
    final Set<String> blocked = blockedResult.data?.map((row) => row.blockedUid).toSet() ?? <String>{};
    if (blockedResult.isFailure) {
      return Result.error(const ServerFailure('Unable to load blocked creators.'));
    }
    if (!isCurrent()) {
      return Result.error(const ServerFailure('Profile wall request was superseded.'));
    }
    if (blocked.contains(uid)) {
      return Result.success((items: const <PublicProfileWallEntity>[], hasMore: false));
    }
    try {
      final rows = await _firestoreClient.query<_WallRow>(
        FirestoreQuerySpec(
          collection: FirebaseCollections.walls,
          sourceTag: 'public_profile.fetch_walls',
          filters: <FirestoreFilter>[
            const FirestoreFilter(field: 'review', op: FirestoreFilterOp.isEqualTo, value: true),
            FirestoreFilter(field: 'creatorUid', op: FirestoreFilterOp.isEqualTo, value: uid),
          ],
          orderBy: const <FirestoreOrderBy>[FirestoreOrderBy(field: 'createdAt', descending: true)],
          limit: 12,
          startAfterDocId: refresh ? null : _wallCursorByUid[cursorKey],
          cachePolicy: refresh ? FirestoreCachePolicy.networkOnly : FirestoreCachePolicy.memoryFirst,
          dedupeWindowMs: refresh ? 0 : _profileReadDedupeMs,
        ),
        (data, docId) => _WallRow(docId: docId, doc: WallDocDto.fromJson(data)),
      );
      if (!isCurrent()) {
        return Result.error(const ServerFailure('Profile wall request was superseded.'));
      }

      final items = rows
          .map((row) => PublicProfileSnapshotCodec.wallFromDto(row.doc, row.docId, firestoreDocumentId: row.docId))
          .toList(growable: false);
      try {
        await _serializeSnapshotWrite(owner, () async {
          if (!isCurrent()) return;
          Map<String, Object?>? previous;
          if (!refresh) {
            try {
              previous = await _profileSnapshots.read(snapshotKey);
            } catch (_) {}
          }
          if (!isCurrent()) return;
          final Map<String, PublicProfileSnapshotWall> uniqueRows = <String, PublicProfileSnapshotWall>{
            if (previous != null)
              for (final wall in PublicProfileSnapshotCodec.decodeWalls(previous)) wall.doc.id: wall,
            for (final row in rows)
              (row.doc.id.isNotEmpty ? row.doc.id : row.docId): (doc: row.doc, documentId: row.docId),
          };
          await _profileSnapshots.write(
            snapshotKey,
            PublicProfileSnapshotCodec.encodeWalls(
              uniqueRows.entries.map(
                (entry) => entry.value.doc.id.isEmpty
                    ? (doc: entry.value.doc.copyWith(id: entry.key), documentId: entry.value.documentId)
                    : entry.value,
              ),
              hasMore: rows.length == 12,
            ),
          );
        });
      } catch (_) {}
      if (!isCurrent()) {
        return Result.error(const ServerFailure('Profile wall request was superseded.'));
      }
      if (rows.isNotEmpty) _wallCursorByUid[cursorKey] = rows.last.docId;

      return Result.success((items: items, hasMore: rows.length == 12));
    } catch (error) {
      if (isCurrent()) {
        try {
          final cached = await _profileSnapshots.read(snapshotKey);
          if (cached != null && isCurrent()) {
            final items = PublicProfileSnapshotCodec.decodeWalls(cached)
                .map(
                  (wall) => PublicProfileSnapshotCodec.wallFromDto(
                    wall.doc,
                    wall.doc.id,
                    firestoreDocumentId: wall.documentId,
                  ),
                )
                .toList(growable: false);
            return Result.success((items: items, hasMore: cached['hasMore'] as bool? ?? false));
          }
        } catch (_) {}
      }
      return Result.error(ServerFailure('Unable to fetch profile walls: $error'));
    }
  }

  @override
  Future<Result<List<String>>> fetchRelationIds({required String profileUid, required UserRelationKind kind}) async {
    final String uid = profileUid.trim();
    if (uid.isEmpty) return Result.success(const <String>[]);
    final bool followers = kind == UserRelationKind.followers;
    try {
      final List<String> ids = await _firestoreClient.query<String>(
        FirestoreQuerySpec(
          collection: followers ? FirebaseCollections.profileFollowers(uid) : FirebaseCollections.profileFollowing(uid),
          sourceTag: followers ? 'public_profile.relation_ids.followers' : 'public_profile.relation_ids.following',
          orderBy: const <FirestoreOrderBy>[FirestoreOrderBy(field: 'createdAt', descending: true)],
          limit: PublicProfileRepository.relationIdsLimit,
        ),
        (_, docId) => docId,
      );
      return Result.success(ids);
    } catch (_) {
      return Result.error(const ServerFailure('Unable to load relation list.'));
    }
  }

  @override
  Future<Result<void>> follow({
    required String currentUserId,
    required String currentUserEmail,
    required String targetUserId,
    required String targetUserEmail,
  }) {
    return _setFollowing(
      follow: true,
      currentUserId: currentUserId,
      currentUserEmail: currentUserEmail,
      targetUserId: targetUserId,
      targetUserEmail: targetUserEmail,
    );
  }

  @override
  Future<Result<void>> unfollow({
    required String currentUserId,
    required String currentUserEmail,
    required String targetUserId,
    required String targetUserEmail,
  }) {
    return _setFollowing(
      follow: false,
      currentUserId: currentUserId,
      currentUserEmail: currentUserEmail,
      targetUserId: targetUserId,
      targetUserEmail: targetUserEmail,
    );
  }

  Future<Result<void>> _setFollowing({
    required bool follow,
    required String currentUserId,
    required String currentUserEmail,
    required String targetUserId,
    required String targetUserEmail,
  }) async {
    final String verb = follow ? 'follow' : 'unfollow';
    if (currentUserId.trim().isEmpty || targetUserId.trim().isEmpty || currentUserId == targetUserId) {
      return Result.error(ServerFailure('Unable to $verb user: invalid profile id.'));
    }
    try {
      await _setFollow(targetUserId.trim(), follow);
      return Result.success<void>(null);
    } catch (error) {
      return Result.error(ServerFailure('Unable to $verb user: $error'));
    }
  }

  static Future<void> _callSetFollow(String targetUid, bool following) async {
    await appFunctions.httpsCallable('setFollow').call<Object?>(<String, Object?>{
      'targetUid': targetUid,
      'following': following,
    });
  }

  List<String> _uniqueUserIds(List<String> ids) =>
      ids.map((id) => id.trim()).where((id) => id.isNotEmpty && !id.contains('@')).toSet().toList();

  Future<Set<String>> _followingIds(List<String> ids) async {
    final String currentUserId = app_state.prismUser.loggedIn ? app_state.prismUser.id.trim() : '';
    if (currentUserId.isEmpty || ids.isEmpty) return <String>{};
    final List<String> found = <String>[];
    for (int i = 0; i < ids.length; i += 30) {
      final List<String> chunk = ids.sublist(i, math.min(i + 30, ids.length));
      found.addAll(
        await _firestoreClient.query<String>(
          FirestoreQuerySpec(
            collection: FirebaseCollections.profileFollowing(currentUserId),
            sourceTag: 'public_profile.following_ids',
            filters: <FirestoreFilter>[
              FirestoreFilter(field: firestoreDocumentIdField, op: FirestoreFilterOp.whereIn, value: chunk),
            ],
            limit: chunk.length,
          ),
          (_, docId) => docId,
        ),
      );
    }
    return found.toSet();
  }

  UserSummaryEntity _toSummary(_UserRow row, Set<String> followingSet) => UserSummaryEntity(
    id: row.docId,
    name: row.doc.name,
    email: '',
    username: row.doc.username,
    profilePhoto: row.doc.profilePhoto,
    isFollowedByCurrentUser: followingSet.contains(row.docId),
  );

  @override
  Future<Result<({List<UserSummaryEntity> items, bool hasMore})>> fetchUserSummariesPage({
    required List<String> userIds,
    required int page,
  }) async {
    final String owner = _snapshotOwner;
    final List<String> unique = _uniqueUserIds(userIds);
    try {
      final start = page * _summariesPageSize;
      if (start >= unique.length) {
        return Result.success((items: const <UserSummaryEntity>[], hasMore: false));
      }
      final end = math.min(start + _summariesPageSize, unique.length);
      final pageUserIds = unique.sublist(start, end);
      final String pageIdentity = sha256.convert(utf8.encode(pageUserIds.join(','))).toString();
      final String cacheKey = 'v3::$owner::summaries:$page:$pageIdentity';

      final chunkedResults = await Future.wait(<Future<List<_UserRow>>>[
        for (int i = 0; i < pageUserIds.length; i += 30)
          _firestoreClient.query<_UserRow>(
            FirestoreQuerySpec(
              collection: FirebaseCollections.profiles,
              sourceTag: 'public_profile.fetch_user_summaries',
              filters: <FirestoreFilter>[
                FirestoreFilter(
                  field: firestoreDocumentIdField,
                  op: FirestoreFilterOp.whereIn,
                  value: pageUserIds.sublist(i, math.min(i + 30, pageUserIds.length)),
                ),
              ],
              limit: math.min(30, pageUserIds.length - i),
              cachePolicy: FirestoreCachePolicy.memoryFirst,
              dedupeWindowMs: _profileReadDedupeMs,
            ),
            (data, docId) => _UserRow(docId: docId, doc: PublicUserDocDto.fromJson(data)),
          ),
      ]);

      final Set<String> followingSet = await _followingIds(pageUserIds);
      final Map<String, _UserRow> byId = <String, _UserRow>{
        for (final row in chunkedResults.expand((rows) => rows)) row.docId: row,
      };
      // Preserve the original ordering of the input UID list.
      final ordered = pageUserIds
          .map((id) => byId[id])
          .whereType<_UserRow>()
          .map((row) => _toSummary(row, followingSet))
          .toList(growable: false);
      if (_snapshotOwner == owner) {
        try {
          await _writeSnapshot(
            owner,
            cacheKey,
            PublicProfileSnapshotCodec.encodeSummaries(ordered, hasMore: end < unique.length),
          );
        } catch (_) {}
      }
      return Result.success((items: ordered, hasMore: end < unique.length));
    } catch (error) {
      if (_snapshotOwner == owner) {
        try {
          final start = page * _summariesPageSize;
          final end = math.min(start + _summariesPageSize, unique.length);
          final pageIdentity = sha256.convert(utf8.encode(unique.sublist(start, end).join(','))).toString();
          final cacheKey = 'v3::$owner::summaries:$page:$pageIdentity';
          final cached = await _profileSnapshots.read(cacheKey);
          if (cached != null && _snapshotOwner == owner) {
            final List<UserSummaryEntity> items = PublicProfileSnapshotCodec.decodeSummaries(cached);
            return Result.success((items: items, hasMore: cached['hasMore'] as bool? ?? false));
          }
        } catch (_) {}
      }
      return Result.error(ServerFailure('Unable to fetch user summaries page: $error'));
    }
  }

  String get _snapshotOwner => app_state.prismUser.loggedIn ? app_state.prismUser.id.trim() : '__guest';

  @override
  Future<Result<List<UserSummaryEntity>>> searchUsersByUsername({
    required String query,
    required List<String> scopeUserIds,
  }) async {
    final String q = query.trim();
    if (q.isEmpty || scopeUserIds.isEmpty) {
      return Result.success(const <UserSummaryEntity>[]);
    }

    try {
      final List<String> ids = _uniqueUserIds(scopeUserIds);
      final List<List<_UserRow>> results = await Future.wait(<Future<List<_UserRow>>>[
        for (int i = 0; i < ids.length; i += _searchChunkSize)
          _firestoreClient.query<_UserRow>(
            FirestoreQuerySpec(
              collection: FirebaseCollections.profiles,
              sourceTag: 'public_profile.search_by_username',
              filters: <FirestoreFilter>[
                FirestoreFilter(
                  field: firestoreDocumentIdField,
                  op: FirestoreFilterOp.whereIn,
                  value: ids.sublist(i, math.min(i + _searchChunkSize, ids.length)),
                ),
              ],
            ),
            (data, docId) => _UserRow(docId: docId, doc: PublicUserDocDto.fromJson(data)),
          ),
      ]);
      final Set<String> followingSet = await _followingIds(ids);
      final Map<String, _UserRow> byId = <String, _UserRow>{
        for (final row in results.expand((rows) => rows)) row.docId: row,
      };
      final List<_UserRow> rows =
          byId.values.where((row) => row.doc.username.toLowerCase().startsWith(q.toLowerCase())).toList()
            ..sort((a, b) => a.doc.username.toLowerCase().compareTo(b.doc.username.toLowerCase()));
      return Result.success(
        rows.take(_searchLimit).map((row) => _toSummary(row, followingSet)).toList(growable: false),
      );
    } catch (error) {
      return Result.error(ServerFailure('Unable to search users: $error'));
    }
  }
}

class _UserRow {
  const _UserRow({required this.docId, required this.doc});

  final String docId;
  final PublicUserDocDto doc;
}

class _WallRow {
  const _WallRow({required this.docId, required this.doc});

  final String docId;
  final WallDocDto doc;
}
