import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/firestore/dtos/public_user_doc_dto.dart';
import 'package:Prism/core/firestore/dtos/setup_doc_dto.dart';
import 'package:Prism/core/firestore/dtos/wall_doc_dto.dart';
import 'package:Prism/core/firestore/firestore_client.dart';
import 'package:Prism/core/firestore/firestore_collections.dart';
import 'package:Prism/core/firestore/firestore_query_specs.dart';
import 'package:Prism/core/firestore/firestore_sentinels.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/features/public_profile/domain/entities/public_profile_entity.dart';
import 'package:Prism/features/public_profile/domain/entities/public_profile_page.dart';
import 'package:Prism/features/public_profile/domain/entities/public_profile_setup_entity.dart';
import 'package:Prism/features/public_profile/domain/entities/public_profile_wall_entity.dart';
import 'package:Prism/features/public_profile/domain/repositories/public_profile_repository.dart';
import 'package:injectable/injectable.dart';

@LazySingleton(as: PublicProfileRepository)
class PublicProfileRepositoryImpl implements PublicProfileRepository {
  PublicProfileRepositoryImpl(this._firestoreClient);

  final FirestoreClient _firestoreClient;
  final Map<String, String> _wallCursorByEmail = <String, String>{};
  final Map<String, String> _setupCursorByEmail = <String, String>{};
  static const int _profileReadDedupeMs = 30000;

  Future<_UserRow?> _findUser(String email) async {
    final usersv2 = await _firestoreClient.query<_UserRow>(
      FirestoreQuerySpec(
        collection: FirebaseCollections.usersV2,
        sourceTag: 'public_profile.find_user_v2',
        filters: <FirestoreFilter>[FirestoreFilter(field: 'email', op: FirestoreFilterOp.isEqualTo, value: email)],
        limit: 1,
        cachePolicy: FirestoreCachePolicy.memoryFirst,
        dedupeWindowMs: _profileReadDedupeMs,
      ),
      (data, docId) => _UserRow(docId: docId, doc: PublicUserDocDto.fromJson(data)),
    );
    if (usersv2.isNotEmpty) {
      return usersv2.first;
    }

    final users = await _firestoreClient.query<_UserRow>(
      FirestoreQuerySpec(
        collection: FirebaseCollections.users,
        sourceTag: 'public_profile.find_user_legacy',
        filters: <FirestoreFilter>[FirestoreFilter(field: 'email', op: FirestoreFilterOp.isEqualTo, value: email)],
        limit: 1,
        cachePolicy: FirestoreCachePolicy.memoryFirst,
        dedupeWindowMs: _profileReadDedupeMs,
      ),
      (data, docId) => _UserRow(docId: docId, doc: PublicUserDocDto.fromJson(data)),
    );
    if (users.isNotEmpty) {
      return users.first;
    }
    return null;
  }

  PublicProfileEntity _toEntity(PublicUserDocDto doc, String docId) {
    return PublicProfileEntity(
      id: doc.id.isNotEmpty ? doc.id : docId,
      name: doc.name,
      email: doc.email,
      username: doc.username,
      profilePhoto: doc.profilePhoto,
      bio: doc.bio,
      followers: doc.followers,
      following: doc.following,
      links: doc.links,
      premium: doc.premium,
      coverPhoto: doc.coverPhoto,
    );
  }

  @override
  Future<Result<PublicProfileEntity>> fetchProfile({required String email}) async {
    try {
      final row = await _findUser(email);
      if (row == null) {
        return Result.error(const ValidationFailure('Profile not found'));
      }
      return Result.success(_toEntity(row.doc, row.docId));
    } catch (error) {
      return Result.error(ServerFailure('Unable to fetch profile: $error'));
    }
  }

  @override
  Future<Result<PublicProfilePage<PublicProfileWallEntity>>> fetchWalls({
    required String email,
    required bool refresh,
  }) async {
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

      return Result.success(
        PublicProfilePage<PublicProfileWallEntity>(
          items: items,
          hasMore: rows.length == 12,
          nextCursor: _wallCursorByEmail[email],
        ),
      );
    } catch (error) {
      return Result.error(ServerFailure('Unable to fetch profile walls: $error'));
    }
  }

  @override
  Future<Result<PublicProfilePage<PublicProfileSetupEntity>>> fetchSetups({
    required String email,
    required bool refresh,
  }) async {
    try {
      final rows = await _firestoreClient.query<_SetupRow>(
        FirestoreQuerySpec(
          collection: FirebaseCollections.setups,
          sourceTag: 'public_profile.fetch_setups',
          filters: <FirestoreFilter>[
            const FirestoreFilter(field: 'review', op: FirestoreFilterOp.isEqualTo, value: true),
            FirestoreFilter(field: 'email', op: FirestoreFilterOp.isEqualTo, value: email),
          ],
          orderBy: const <FirestoreOrderBy>[FirestoreOrderBy(field: 'created_at', descending: true)],
          limit: 8,
          startAfterDocId: refresh ? null : _setupCursorByEmail[email],
          cachePolicy: refresh ? FirestoreCachePolicy.networkOnly : FirestoreCachePolicy.memoryFirst,
          dedupeWindowMs: refresh ? 0 : _profileReadDedupeMs,
        ),
        (data, docId) => _SetupRow(docId: docId, doc: SetupDocDto.fromJson(data)),
      );
      if (rows.isNotEmpty) {
        _setupCursorByEmail[email] = rows.last.docId;
      }

      final items = rows.map((row) => _mapSetup(row.doc, row.docId)).toList(growable: false);

      return Result.success(
        PublicProfilePage<PublicProfileSetupEntity>(
          items: items,
          hasMore: rows.length == 8,
          nextCursor: _setupCursorByEmail[email],
        ),
      );
    } catch (error) {
      return Result.error(ServerFailure('Unable to fetch profile setups: $error'));
    }
  }

  @override
  Future<Result<PublicProfileEntity>> follow({
    required String currentUserId,
    required String currentUserEmail,
    required String targetUserId,
    required String targetUserEmail,
  }) async {
    try {
      await _firestoreClient.updateDoc(FirebaseCollections.usersV2, currentUserId, <String, dynamic>{
        'following': FirestoreSentinels.arrayUnion(<Object?>[targetUserEmail]),
      }, sourceTag: 'public_profile.follow.current_user');
      await _firestoreClient.updateDoc(FirebaseCollections.usersV2, targetUserId, <String, dynamic>{
        'followers': FirestoreSentinels.arrayUnion(<Object?>[currentUserEmail]),
      }, sourceTag: 'public_profile.follow.target_user');
      return fetchProfile(email: targetUserEmail);
    } catch (error) {
      return Result.error(ServerFailure('Unable to follow user: $error'));
    }
  }

  @override
  Future<Result<PublicProfileEntity>> unfollow({
    required String currentUserId,
    required String currentUserEmail,
    required String targetUserId,
    required String targetUserEmail,
  }) async {
    try {
      await _firestoreClient.updateDoc(FirebaseCollections.usersV2, currentUserId, <String, dynamic>{
        'following': FirestoreSentinels.arrayRemove(<Object?>[targetUserEmail]),
      }, sourceTag: 'public_profile.unfollow.current_user');
      await _firestoreClient.updateDoc(FirebaseCollections.usersV2, targetUserId, <String, dynamic>{
        'followers': FirestoreSentinels.arrayRemove(<Object?>[currentUserEmail]),
      }, sourceTag: 'public_profile.unfollow.target_user');
      return fetchProfile(email: targetUserEmail);
    } catch (error) {
      return Result.error(ServerFailure('Unable to unfollow user: $error'));
    }
  }

  @override
  Future<Result<PublicProfileEntity>> updateLinks({required String userId, required Map<String, String> links}) async {
    try {
      await _firestoreClient.updateDoc(FirebaseCollections.usersV2, userId, <String, dynamic>{
        'links': links,
      }, sourceTag: 'public_profile.update_links');
      final updated = await _firestoreClient.getById<_UserRow>(
        FirebaseCollections.usersV2,
        userId,
        (data, docId) => _UserRow(docId: docId, doc: PublicUserDocDto.fromJson(data)),
        sourceTag: 'public_profile.update_links.read_back',
      );
      if (updated == null) {
        return Result.error(const ValidationFailure('Profile not found'));
      }
      return Result.success(_toEntity(updated.doc, updated.docId));
    } catch (error) {
      return Result.error(ServerFailure('Unable to update links: $error'));
    }
  }

  PublicProfileSetupEntity _mapSetup(SetupDocDto dto, String docId) {
    return PublicProfileSetupEntity(
      id: dto.id.isNotEmpty ? dto.id : docId,
      by: dto.by,
      icon: dto.icon,
      iconUrl: dto.iconUrl,
      createdAt: dto.createdAt,
      desc: dto.desc,
      email: dto.email,
      image: dto.image,
      name: dto.name,
      userPhoto: dto.userPhoto,
      wallId: dto.wallId,
      source: WallpaperSourceX.fromWire(dto.wallpaperProvider),
      wallpaperThumb: dto.wallpaperThumb,
      wallpaperUrl: dto.wallpaperUrl,
      widget: dto.widget,
      widget2: dto.widget2,
      widgetUrl: dto.widgetUrl,
      widgetUrl2: dto.widgetUrl2,
      link: dto.link,
      review: dto.review,
      resolution: dto.resolution,
      size: dto.size,
    );
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

class _SetupRow {
  const _SetupRow({required this.docId, required this.doc});

  final String docId;
  final SetupDocDto doc;
}

class _WallRow {
  const _WallRow({required this.docId, required this.doc});

  final String docId;
  final WallDocDto doc;
}
