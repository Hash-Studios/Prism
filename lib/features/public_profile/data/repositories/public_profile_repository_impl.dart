import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/firestore/firestore_client.dart';
import 'package:Prism/core/firestore/firestore_collections.dart';
import 'package:Prism/core/firestore/firestore_query_specs.dart';
import 'package:Prism/core/firestore/firestore_sentinels.dart';
import 'package:Prism/core/utils/result.dart';
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

  Future<Map<String, dynamic>?> _findUser(String email) async {
    final usersv2 = await _firestoreClient.query<Map<String, dynamic>>(
      FirestoreQuerySpec(
        collection: FirebaseCollections.usersV2,
        sourceTag: 'public_profile.find_user_v2',
        filters: <FirestoreFilter>[
          FirestoreFilter(field: 'email', op: FirestoreFilterOp.isEqualTo, value: email),
        ],
        limit: 1,
      ),
      (data, docId) => <String, dynamic>{...data, '__docId': docId},
    );
    if (usersv2.isNotEmpty) {
      return usersv2.first;
    }

    final users = await _firestoreClient.query<Map<String, dynamic>>(
      FirestoreQuerySpec(
        collection: FirebaseCollections.users,
        sourceTag: 'public_profile.find_user_legacy',
        filters: <FirestoreFilter>[
          FirestoreFilter(field: 'email', op: FirestoreFilterOp.isEqualTo, value: email),
        ],
        limit: 1,
      ),
      (data, docId) => <String, dynamic>{...data, '__docId': docId},
    );
    if (users.isNotEmpty) {
      return users.first;
    }
    return null;
  }

  PublicProfileEntity _toEntity(Map<String, dynamic> data) {
    return PublicProfileEntity(
      id: (data['id'] ?? data['__docId'] ?? '').toString(),
      name: (data['name'] ?? '').toString(),
      email: (data['email'] ?? '').toString(),
      username: (data['username'] ?? '').toString(),
      profilePhoto: (data['profilePhoto'] ?? '').toString(),
      bio: (data['bio'] ?? '').toString(),
      followers: data['followers'] as List<dynamic>? ?? const <dynamic>[],
      following: data['following'] as List<dynamic>? ?? const <dynamic>[],
      links: data['links'] as Map<String, dynamic>? ?? const <String, dynamic>{},
      premium: (data['premium'] ?? false) as bool,
      coverPhoto: (data['coverPhoto'] ?? '').toString(),
    );
  }

  @override
  Future<Result<PublicProfileEntity>> fetchProfile({required String email}) async {
    try {
      final doc = await _findUser(email);
      if (doc == null) {
        return Result.error(const ValidationFailure('Profile not found'));
      }
      return Result.success(_toEntity(doc));
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
      final rows = await _firestoreClient.query<Map<String, dynamic>>(
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
        ),
        (data, docId) => <String, dynamic>{...data, '__docId': docId},
      );
      if (rows.isNotEmpty) {
        _wallCursorByEmail[email] = rows.last['__docId']?.toString() ?? '';
      }

      final items = rows.map((data) {
        final payload = <String, dynamic>{...data};
        payload.remove('__docId');
        return PublicProfileWallEntity(
          id: (payload['id'] ?? data['__docId']).toString(),
          payload: payload,
        );
      }).toList(growable: false);

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
      final rows = await _firestoreClient.query<Map<String, dynamic>>(
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
        ),
        (data, docId) => <String, dynamic>{...data, '__docId': docId},
      );
      if (rows.isNotEmpty) {
        _setupCursorByEmail[email] = rows.last['__docId']?.toString() ?? '';
      }

      final items = rows.map((data) {
        final payload = <String, dynamic>{...data};
        payload.remove('__docId');
        return PublicProfileSetupEntity(
          id: (payload['id'] ?? data['__docId']).toString(),
          payload: payload,
        );
      }).toList(growable: false);

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
      await _firestoreClient.updateDoc(
        FirebaseCollections.usersV2,
        currentUserId,
        <String, dynamic>{
          'following': FirestoreSentinels.arrayUnion(<Object?>[targetUserEmail]),
        },
        sourceTag: 'public_profile.follow.current_user',
      );
      await _firestoreClient.updateDoc(
        FirebaseCollections.usersV2,
        targetUserId,
        <String, dynamic>{
          'followers': FirestoreSentinels.arrayUnion(<Object?>[currentUserEmail]),
        },
        sourceTag: 'public_profile.follow.target_user',
      );
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
      await _firestoreClient.updateDoc(
        FirebaseCollections.usersV2,
        currentUserId,
        <String, dynamic>{
          'following': FirestoreSentinels.arrayRemove(<Object?>[targetUserEmail]),
        },
        sourceTag: 'public_profile.unfollow.current_user',
      );
      await _firestoreClient.updateDoc(
        FirebaseCollections.usersV2,
        targetUserId,
        <String, dynamic>{
          'followers': FirestoreSentinels.arrayRemove(<Object?>[currentUserEmail]),
        },
        sourceTag: 'public_profile.unfollow.target_user',
      );
      return fetchProfile(email: targetUserEmail);
    } catch (error) {
      return Result.error(ServerFailure('Unable to unfollow user: $error'));
    }
  }

  @override
  Future<Result<PublicProfileEntity>> updateLinks({
    required String userId,
    required Map<String, String> links,
  }) async {
    try {
      await _firestoreClient.updateDoc(
        FirebaseCollections.usersV2,
        userId,
        <String, dynamic>{'links': links},
        sourceTag: 'public_profile.update_links',
      );
      final updated = await _firestoreClient.getById<Map<String, dynamic>>(
        FirebaseCollections.usersV2,
        userId,
        (data, docId) => <String, dynamic>{...data, '__docId': docId},
        sourceTag: 'public_profile.update_links.read_back',
      );
      if (updated == null) {
        return Result.error(const ValidationFailure('Profile not found'));
      }
      return Result.success(_toEntity(updated));
    } catch (error) {
      return Result.error(ServerFailure('Unable to update links: $error'));
    }
  }
}
