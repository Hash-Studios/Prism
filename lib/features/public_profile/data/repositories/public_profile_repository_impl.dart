import 'dart:math' as math;

import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/firestore/dtos/public_user_doc_dto.dart';
import 'package:Prism/core/firestore/dtos/wall_doc_dto.dart';
import 'package:Prism/core/firestore/firestore_client.dart';
import 'package:Prism/core/firestore/firestore_collections.dart';
import 'package:Prism/core/firestore/firestore_query_specs.dart';
import 'package:Prism/core/firestore/firestore_sentinels.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/user_blocks/blocked_creators_filter.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/features/public_profile/domain/entities/public_profile_entity.dart';
import 'package:Prism/features/public_profile/domain/entities/public_profile_wall_entity.dart';
import 'package:Prism/features/public_profile/domain/entities/user_summary_entity.dart';
import 'package:Prism/features/public_profile/domain/repositories/public_profile_repository.dart';
import 'package:Prism/features/user_blocks/domain/repositories/user_block_repository.dart';
import 'package:injectable/injectable.dart';

@LazySingleton(as: PublicProfileRepository)
class PublicProfileRepositoryImpl implements PublicProfileRepository {
  PublicProfileRepositoryImpl(this._firestoreClient, this._userBlockRepository);

  final FirestoreClient _firestoreClient;
  final UserBlockRepository _userBlockRepository;
  final Map<String, String> _wallCursorByEmail = <String, String>{};
  static const int _profileReadDedupeMs = 30000;
  static const int _searchChunkSize = 30;
  static const int _summariesPageSize = 20;
  static const int _searchLimit = 5;

  @override
  Stream<PublicProfileEntity?> watchProfile(String identifier) {
    final String value = identifier.trim();
    return _firestoreClient
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
          );
        });
  }

  @override
  Future<Result<({List<PublicProfileWallEntity> items, bool hasMore})>> fetchWalls({
    required String email,
    required bool refresh,
  }) async {
    final Set<String> blocked = await _userBlockRepository.getBlockedCreatorEmails(waitForInitialLoad: true);
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
      if (rows.isNotEmpty) {
        _wallCursorByEmail[email] = rows.last.docId;
      }

      final items = rows.map((row) => _mapWall(row.doc, row.docId)).toList(growable: false);

      return Result.success((items: items, hasMore: rows.length == 12));
    } catch (error) {
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
      await _firestoreClient.updateDoc(FirebaseCollections.usersV2, currentUserId, <String, dynamic>{
        'following': change(<Object?>[targetUserEmail]),
      }, sourceTag: 'public_profile.$verb.current_user');
      await _firestoreClient.updateDoc(FirebaseCollections.usersV2, targetUserId, <String, dynamic>{
        'followers': change(<Object?>[currentUserEmail]),
      }, sourceTag: 'public_profile.$verb.target_user');
      return Result.success<void>(null);
    } catch (error) {
      return Result.error(ServerFailure('Unable to $verb user: $error'));
    }
  }

  List<String> _uniqueEmails(List<String> emails) =>
      emails.map((e) => e.trim().toLowerCase()).where((e) => e.isNotEmpty).toSet().toList(growable: false);

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
    try {
      final unique = _uniqueEmails(allEmails);
      final start = page * _summariesPageSize;
      if (start >= unique.length) {
        return Result.success((items: const <UserSummaryEntity>[], hasMore: false));
      }
      final end = math.min(start + _summariesPageSize, unique.length);
      final pageEmails = unique.sublist(start, end);

      // Firestore whereIn is limited to 10 items per query, so chunk the page.
      final chunkedResults = await Future.wait(<Future<List<_UserRow>>>[
        for (int i = 0; i < pageEmails.length; i += 10)
          _firestoreClient.query<_UserRow>(
            FirestoreQuerySpec(
              collection: FirebaseCollections.usersV2,
              sourceTag: 'public_profile.fetch_user_summaries',
              filters: <FirestoreFilter>[
                FirestoreFilter(
                  field: 'email',
                  op: FirestoreFilterOp.whereIn,
                  value: pageEmails.sublist(i, math.min(i + 10, pageEmails.length)),
                ),
              ],
              limit: math.min(10, pageEmails.length - i),
              cachePolicy: FirestoreCachePolicy.memoryFirst,
              dedupeWindowMs: _profileReadDedupeMs,
            ),
            (data, docId) => _UserRow(docId: docId, doc: PublicUserDocDto.fromJson(data)),
          ),
      ]);

      final followingSet = _currentUserFollowing();
      final Map<String, UserSummaryEntity> byEmail = <String, UserSummaryEntity>{
        for (final row in chunkedResults.expand((rows) => rows))
          row.doc.email.trim().toLowerCase(): _toSummary(row, followingSet),
      };
      // Preserve the original ordering of the input email list.
      final ordered = pageEmails.map((e) => byEmail[e]).whereType<UserSummaryEntity>().toList(growable: false);

      return Result.success((items: ordered, hasMore: end < unique.length));
    } catch (error) {
      return Result.error(ServerFailure('Unable to fetch user summaries page: $error'));
    }
  }

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
      final List<String> unique = _uniqueEmails(scopeEmails);
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

      final List<_UserRow> rows = chunks.expand((rows) => rows).toList()
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
