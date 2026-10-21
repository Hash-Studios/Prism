import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:crypto/crypto.dart';
import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/firestore/dtos/public_user_doc_dto.dart';
import 'package:Prism/core/firestore/dtos/wall_doc_dto.dart';
import 'package:Prism/core/firestore/firestore_client.dart';
import 'package:Prism/core/firestore/firestore_collections.dart';
import 'package:Prism/core/firestore/firestore_query_specs.dart';
import 'package:Prism/core/firestore/firestore_sentinels.dart';
import 'package:Prism/core/offline/durable_json_store.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/user_blocks/blocked_creators_filter.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/core/wallpaper/wall_depth.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/features/public_profile/domain/entities/public_profile_entity.dart';
import 'package:Prism/features/public_profile/domain/entities/public_profile_wall_entity.dart';
import 'package:Prism/features/public_profile/domain/entities/user_summary_entity.dart';
import 'package:Prism/features/public_profile/domain/public_profile_snapshot_codec.dart';
import 'package:Prism/features/public_profile/domain/repositories/public_profile_repository.dart';
import 'package:Prism/features/user_blocks/domain/repositories/user_block_repository.dart';
import 'package:injectable/injectable.dart';

@LazySingleton(as: PublicProfileRepository)
class PublicProfileRepositoryImpl implements PublicProfileRepository {
  PublicProfileRepositoryImpl(this._firestoreClient, this._userBlockRepository);

  final FirestoreClient _firestoreClient;
  final UserBlockRepository _userBlockRepository;
  final DurableJsonStore _profileSnapshots = DurableJsonStore('public_profiles');
  final Map<String, Future<void>> _snapshotWriteTails = <String, Future<void>>{};
  final Set<String> _clearingSnapshotOwners = <String>{};
  final Map<String, String> _wallCursorByEmail = <String, String>{};
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
      for (final String key in records.keys.where((key) => key.startsWith('$owner::'))) {
        await _profileSnapshots.delete(key);
      }
    }, allowClearing: true);
  }

  Stream<PublicProfileEntity?> _watchProfileWithCache(String value) {
    final String owner = _snapshotOwner;
    final String key = '$owner::${value.toLowerCase()}';
    return Stream<PublicProfileEntity?>.multi((controller) {
      final remote = StreamController<PublicProfileEntity?>();
      final subscription = _firestoreClient
          .watchQuery<_UserRow>(
            FirestoreQuerySpec(
              collection: FirebaseCollections.usersV2,
              sourceTag: 'profile.stream.v2',
              filters: <FirestoreFilter>[
                FirestoreFilter(
                  field: value.contains('@') ? 'email' : 'username',
                  op: FirestoreFilterOp.isEqualTo,
                  value: value,
                ),
              ],
              limit: 1,
              isStream: true,
            ),
            (data, docId) => _UserRow(docId: docId, doc: PublicUserDocDto.fromJson(data)),
          )
          .map((rows) {
            if (rows.isEmpty) {
              return null;
            }
            final PublicUserDocDto doc = rows.first.doc;
            return PublicProfileEntity(
              id: rows.first.docId,
              name: doc.name,
              email: doc.email,
              username: doc.username,
              profilePhoto: doc.profilePhoto,
              bio: doc.bio,
              followers: doc.followers,
              following: doc.following,
              links: doc.links,
              coverPhoto: doc.coverPhoto,
              badges: doc.badges,
              frameId: doc.cosmetics['frame'],
              nameGlowId: doc.cosmetics['nameGlow'],
              xp: doc.xp,
              premium: doc.premium,
            );
          })
          .listen(remote.add, onError: remote.addError, onDone: remote.close);
      var cancelled = false;
      controller.onCancel = () async {
        cancelled = true;
        await subscription.cancel();
        if (remote.hasListener) await remote.close();
      };

      unawaited(() async {
        try {
          Map<String, Object?>? saved;
          try {
            saved = await _profileSnapshots.read(key);
          } catch (_) {}
          if (cancelled) return;
          if (saved != null && _snapshotOwner == owner) {
            controller.add(_profileFromMap(saved));
            if (cancelled) return;
          }
          await for (final profile in remote.stream) {
            if (cancelled || _snapshotOwner != owner) return;
            if (profile != null) {
              try {
                await _writeSnapshot(owner, key, _profileToMap(profile));
              } catch (_) {}
              if (cancelled || _snapshotOwner != owner) return;
            }
            controller.add(profile);
          }
        } catch (error, stackTrace) {
          if (!cancelled) controller.addError(error, stackTrace);
        } finally {
          if (!cancelled) controller.close();
        }
      }());
    });
  }

  PublicProfileEntity _profileFromMap(Map<String, Object?> data) => PublicProfileEntity(
    id: data['id']?.toString() ?? '',
    name: data['name']?.toString() ?? '',
    email: data['email']?.toString() ?? '',
    username: data['username']?.toString() ?? '',
    profilePhoto: data['profilePhoto']?.toString() ?? '',
    bio: data['bio']?.toString() ?? '',
    followers: (data['followers'] as List? ?? const <Object?>[]).map((value) => value.toString()).toList(),
    following: (data['following'] as List? ?? const <Object?>[]).map((value) => value.toString()).toList(),
    links: Map<String, String>.from(data['links'] as Map? ?? const <String, String>{}),
    coverPhoto: data['coverPhoto']?.toString() ?? '',
    badges: (data['badges'] as List? ?? const <Object?>[]).map((value) => value.toString()).toList(),
    frameId: data['frameId']?.toString(),
    nameGlowId: data['nameGlowId']?.toString(),
    xp: data['xp'] is int ? data['xp']! as int : 0,
    premium: data['premium'] is bool ? data['premium']! as bool : false,
  );

  Map<String, Object?> _profileToMap(PublicProfileEntity profile) => <String, Object?>{
    'id': profile.id,
    'name': profile.name,
    'email': profile.email,
    'username': profile.username,
    'profilePhoto': profile.profilePhoto,
    'bio': profile.bio,
    'followers': profile.followers,
    'following': profile.following,
    'links': profile.links,
    'coverPhoto': profile.coverPhoto,
    'badges': profile.badges,
    'frameId': profile.frameId,
    'nameGlowId': profile.nameGlowId,
    'xp': profile.xp,
    'premium': profile.premium,
  };

  Future<void> _writeSnapshot(String owner, String key, Map<String, Object?> value) =>
      _serializeSnapshotWrite(owner, () => _profileSnapshots.write(key, value));

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
    required String email,
    required bool refresh,
  }) async {
    final String owner = _snapshotOwner;
    final String snapshotKey = '$owner::walls:${email.trim().toLowerCase()}';
    final Set<String> blocked = await _userBlockRepository.getBlockedCreatorEmails(waitForInitialLoad: true);
    if (_snapshotOwner != owner) {
      return Result.error(const ServerFailure('Account changed while loading profile walls.'));
    }
    if (BlockedCreatorsFilter.hidesCreatorEmail(email, blocked)) {
      return Result.success((items: const <PublicProfileWallEntity>[], hasMore: false));
    }
    try {
      final rows = await _firestoreClient.query<_WallRow>(
        FirestoreQuerySpec(
          collection: FirebaseCollections.walls,
          sourceTag: 'public_profile.fetch_walls',
          filters: <FirestoreFilter>[
            const FirestoreFilter(field: 'review', op: FirestoreFilterOp.isEqualTo, value: true),
            FirestoreFilter(field: 'email', op: FirestoreFilterOp.isEqualTo, value: email),
          ],
          orderBy: const <FirestoreOrderBy>[FirestoreOrderBy(field: 'createdAt', descending: true)],
          limit: 12,
          startAfterDocId: refresh ? null : _wallCursorByEmail[email],
          cachePolicy: refresh ? FirestoreCachePolicy.networkOnly : FirestoreCachePolicy.memoryFirst,
          dedupeWindowMs: refresh ? 0 : _profileReadDedupeMs,
        ),
        (data, docId) => _WallRow(docId: docId, doc: WallDocDto.fromJson(data)),
      );
      if (_snapshotOwner != owner) {
        return Result.error(const ServerFailure('Account changed while loading profile walls.'));
      }
      if (rows.isNotEmpty) {
        _wallCursorByEmail[email] = rows.last.docId;
      }

      final items = rows.map((row) => _mapWall(row.doc, row.docId)).toList(growable: false);
      Map<String, Object?>? previous;
      if (!refresh) {
        try {
          previous = await _profileSnapshots.read(snapshotKey);
        } catch (_) {}
      }
      final Map<String, WallDocDto> uniqueRows = <String, WallDocDto>{
        if (previous != null)
          for (final row in PublicProfileSnapshotCodec.decodeWalls(previous)) row.id: row,
        for (final row in rows) (row.doc.id.isNotEmpty ? row.doc.id : row.docId): row.doc,
      };
      try {
        await _writeSnapshot(
          owner,
          snapshotKey,
          PublicProfileSnapshotCodec.encodeWalls(
            uniqueRows.entries.map(
              (entry) => entry.value.id.isEmpty ? entry.value.copyWith(id: entry.key) : entry.value,
            ),
            hasMore: rows.length == 12,
          ),
        );
      } catch (_) {}
      if (_snapshotOwner != owner) {
        return Result.error(const ServerFailure('Account changed while loading profile walls.'));
      }

      return Result.success((items: items, hasMore: rows.length == 12));
    } catch (error) {
      if (_snapshotOwner == owner) {
        try {
          final cached = await _profileSnapshots.read(snapshotKey);
          if (cached != null && _snapshotOwner == owner) {
            final List<WallDocDto> docs = PublicProfileSnapshotCodec.decodeWalls(cached);
            final items = docs
                .map((doc) => PublicProfileSnapshotCodec.wallFromDto(doc, doc.id))
                .toList(growable: false);
            return Result.success((items: items, hasMore: cached['hasMore'] as bool? ?? false));
          }
        } catch (_) {}
      }
      return Result.error(ServerFailure('Unable to fetch profile walls: $error'));
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
    final Object Function(List<Object?>) change = follow
        ? FirestoreSentinels.arrayUnion
        : FirestoreSentinels.arrayRemove;
    try {
      await _firestoreClient.runTransaction<void>(
        (FirestoreTransaction transaction) async {
          transaction.updateDoc(FirebaseCollections.usersV2, currentUserId, <String, dynamic>{
            'following': change(<Object?>[targetUserEmail]),
          });
          transaction.updateDoc(FirebaseCollections.usersV2, targetUserId, <String, dynamic>{
            'followers': change(<Object?>[currentUserEmail]),
          });
        },
        sourceTag: 'public_profile.$verb',
        collection: FirebaseCollections.usersV2,
        docId: currentUserId,
      );
      return Result.success<void>(null);
    } catch (error) {
      return Result.error(ServerFailure('Unable to $verb user: $error'));
    }
  }

  List<String> _uniqueEmails(List<String> emails) =>
      emails.map((e) => e.trim().toLowerCase()).where((e) => e.isNotEmpty).toSet().toList(growable: false);

  /// The `email` values to query for [keys]. Firestore compares strings exactly and
  /// legacy users keep their mixed-case address, so query each relation spelling as
  /// well as the lowercase key, the same way `findUserByEmail` does on the server.
  List<String> _lookupEmails(List<String> keys, List<String> allEmails) {
    final Set<String> wanted = keys.toSet();
    return <String>{
      for (final email in allEmails.map((e) => e.trim()))
        if (wanted.contains(email.toLowerCase())) email,
      ...keys,
    }.toList(growable: false);
  }

  UserSummaryEntity _toSummary(_UserRow row, Set<String> followingSet) {
    final doc = row.doc;
    final email = doc.email.trim();
    return UserSummaryEntity(
      id: doc.id.isNotEmpty ? doc.id : row.docId,
      email: email,
      name: doc.name,
      username: doc.username,
      profilePhoto: doc.profilePhoto,
      isFollowedByCurrentUser: followingSet.contains(email.toLowerCase()),
    );
  }

  Set<String> _currentUserFollowing() => app_state.prismUser.following.map((e) => e.trim().toLowerCase()).toSet();

  @override
  Future<Result<({List<UserSummaryEntity> items, bool hasMore})>> fetchUserSummariesPage({
    required List<String> allEmails,
    required int page,
  }) async {
    final String owner = _snapshotOwner;
    final List<String> unique = _uniqueEmails(allEmails);
    try {
      final start = page * _summariesPageSize;
      if (start >= unique.length) {
        return Result.success((items: const <UserSummaryEntity>[], hasMore: false));
      }
      final end = math.min(start + _summariesPageSize, unique.length);
      final pageEmails = unique.sublist(start, end);
      final String pageIdentity = sha256.convert(utf8.encode(pageEmails.join(','))).toString();
      final String cacheKey = '$owner::summaries:$page:$pageIdentity';

      final lookupEmails = _lookupEmails(pageEmails, allEmails);
      // Firestore whereIn is limited to 10 items per query, so chunk the page.
      final chunkedResults = await Future.wait(<Future<List<_UserRow>>>[
        for (int i = 0; i < lookupEmails.length; i += 10)
          _firestoreClient.query<_UserRow>(
            FirestoreQuerySpec(
              collection: FirebaseCollections.usersV2,
              sourceTag: 'public_profile.fetch_user_summaries',
              filters: <FirestoreFilter>[
                FirestoreFilter(
                  field: 'email',
                  op: FirestoreFilterOp.whereIn,
                  value: lookupEmails.sublist(i, math.min(i + 10, lookupEmails.length)),
                ),
              ],
              limit: math.min(10, lookupEmails.length - i),
              cachePolicy: FirestoreCachePolicy.memoryFirst,
              dedupeWindowMs: _profileReadDedupeMs,
            ),
            (data, docId) => _UserRow(docId: docId, doc: PublicUserDocDto.fromJson(data)),
          ),
      ]);

      final followingSet = _currentUserFollowing();
      final Map<String, UserSummaryEntity> byEmail = <String, UserSummaryEntity>{};
      for (final row in chunkedResults.expand((rows) => rows)) {
        byEmail.putIfAbsent(row.doc.email.trim().toLowerCase(), () => _toSummary(row, followingSet));
      }
      // Preserve the original ordering of the input email list.
      final ordered = pageEmails.map((e) => byEmail[e]).whereType<UserSummaryEntity>().toList(growable: false);
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
          final cacheKey = '$owner::summaries:$page:$pageIdentity';
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
    required List<String> scopeEmails,
  }) async {
    final String q = query.trim().toLowerCase();
    if (q.isEmpty || scopeEmails.isEmpty) {
      return Result.success(const <UserSummaryEntity>[]);
    }

    try {
      final List<String> unique = _lookupEmails(_uniqueEmails(scopeEmails), scopeEmails);
      final Set<String> followingSet = _currentUserFollowing();

      // One scoped prefix query per 30 emails (the whereIn limit). Each chunk
      // is ordered by usernameLower, so its top [_searchLimit] covers the overall top.
      final List<List<_UserRow>> chunks = await Future.wait(<Future<List<_UserRow>>>[
        for (int i = 0; i < unique.length; i += _searchChunkSize)
          _firestoreClient.query<_UserRow>(
            FirestoreQuerySpec(
              collection: FirebaseCollections.usersV2,
              sourceTag: 'public_profile.search_by_username',
              filters: <FirestoreFilter>[
                FirestoreFilter(
                  field: 'email',
                  op: FirestoreFilterOp.whereIn,
                  value: unique.sublist(i, math.min(i + _searchChunkSize, unique.length)),
                ),
                FirestoreFilter(field: 'usernameLower', op: FirestoreFilterOp.isGreaterThanOrEqualTo, value: q),
                FirestoreFilter(field: 'usernameLower', op: FirestoreFilterOp.isLessThan, value: '$q\uf8ff'),
              ],
              orderBy: const <FirestoreOrderBy>[FirestoreOrderBy(field: 'usernameLower')],
              limit: _searchLimit,
            ),
            (data, docId) => _UserRow(docId: docId, doc: PublicUserDocDto.fromJson(data)),
          ),
      ]);

      final Set<String> seen = <String>{};
      final List<_UserRow> rows =
          chunks.expand((rows) => rows).where((row) => seen.add(row.doc.email.trim().toLowerCase())).toList()
            ..sort((a, b) => a.doc.username.toLowerCase().compareTo(b.doc.username.toLowerCase()));
      return Result.success(
        rows.take(_searchLimit).map((row) => _toSummary(row, followingSet)).toList(growable: false),
      );
    } catch (error) {
      return Result.error(ServerFailure('Unable to search users: $error'));
    }
  }

  PublicProfileWallEntity _mapWall(WallDocDto dto, String docId) {
    return PublicProfileWallEntity(
      id: dto.id.isNotEmpty ? dto.id : docId,
      by: dto.by,
      desc: dto.desc,
      size: dto.size,
      resolution: dto.resolution,
      email: dto.email,
      source: WallpaperSourceX.fromWire(dto.wallpaperProvider),
      wallpaperThumb: dto.wallpaperThumb,
      wallpaperUrl: dto.wallpaperUrl,
      collections: dto.collections,
      createdAt: dto.createdAt,
      review: dto.review,
      depthTier: WallDepthTier.parse(dto.depth['tier']),
    );
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
