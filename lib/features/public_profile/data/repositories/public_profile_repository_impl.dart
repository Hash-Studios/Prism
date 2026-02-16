import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/features/public_profile/domain/entities/public_profile_entity.dart';
import 'package:Prism/features/public_profile/domain/entities/public_profile_page.dart';
import 'package:Prism/features/public_profile/domain/entities/public_profile_setup_entity.dart';
import 'package:Prism/features/public_profile/domain/entities/public_profile_wall_entity.dart';
import 'package:Prism/features/public_profile/domain/repositories/public_profile_repository.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:injectable/injectable.dart';

@LazySingleton(as: PublicProfileRepository)
class PublicProfileRepositoryImpl implements PublicProfileRepository {
  PublicProfileRepositoryImpl(this._firestore);

  final FirebaseFirestore _firestore;
  final Map<String, DocumentSnapshot<Map<String, dynamic>>> _wallCursorByEmail =
      {};
  final Map<String, DocumentSnapshot<Map<String, dynamic>>>
      _setupCursorByEmail = {};

  Future<DocumentSnapshot<Map<String, dynamic>>?> _findUser(
      String email) async {
    final usersv2 = await _firestore
        .collection('usersv2')
        .where('email', isEqualTo: email)
        .limit(1)
        .get();

    if (usersv2.docs.isNotEmpty) {
      return usersv2.docs.first;
    }

    final users = await _firestore
        .collection('users')
        .where('email', isEqualTo: email)
        .limit(1)
        .get();
    if (users.docs.isNotEmpty) {
      return users.docs.first;
    }

    return null;
  }

  PublicProfileEntity _toEntity(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return PublicProfileEntity(
      id: (data['id'] ?? doc.id).toString(),
      name: (data['name'] ?? '').toString(),
      email: (data['email'] ?? '').toString(),
      username: (data['username'] ?? '').toString(),
      profilePhoto: (data['profilePhoto'] ?? '').toString(),
      bio: (data['bio'] ?? '').toString(),
      followers: data['followers'] as List<dynamic>? ?? const <dynamic>[],
      following: data['following'] as List<dynamic>? ?? const <dynamic>[],
      links:
          data['links'] as Map<String, dynamic>? ?? const <String, dynamic>{},
      premium: (data['premium'] ?? false) as bool,
      coverPhoto: (data['coverPhoto'] ?? '').toString(),
    );
  }

  @override
  Future<Result<PublicProfileEntity>> fetchProfile(
      {required String email}) async {
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
      Query<Map<String, dynamic>> query = _firestore
          .collection('walls')
          .where('review', isEqualTo: true)
          .where('email', isEqualTo: email)
          .orderBy('createdAt', descending: true)
          .limit(12);

      final cursor = _wallCursorByEmail[email];
      if (!refresh && cursor != null) {
        query = query.startAfterDocument(cursor);
      }

      final snapshot = await query.get();
      if (snapshot.docs.isNotEmpty) {
        _wallCursorByEmail[email] = snapshot.docs.last;
      }

      final items = snapshot.docs.map((doc) {
        final data = doc.data();
        return PublicProfileWallEntity(
          id: (data['id'] ?? doc.id).toString(),
          payload: data,
        );
      }).toList(growable: false);

      return Result.success(
        PublicProfilePage<PublicProfileWallEntity>(
          items: items,
          hasMore: snapshot.docs.length == 12,
          nextCursor: _wallCursorByEmail[email]?.id,
        ),
      );
    } catch (error) {
      return Result.error(
          ServerFailure('Unable to fetch profile walls: $error'));
    }
  }

  @override
  Future<Result<PublicProfilePage<PublicProfileSetupEntity>>> fetchSetups({
    required String email,
    required bool refresh,
  }) async {
    try {
      Query<Map<String, dynamic>> query = _firestore
          .collection('setups')
          .where('review', isEqualTo: true)
          .where('email', isEqualTo: email)
          .orderBy('created_at', descending: true)
          .limit(8);

      final cursor = _setupCursorByEmail[email];
      if (!refresh && cursor != null) {
        query = query.startAfterDocument(cursor);
      }

      final snapshot = await query.get();
      if (snapshot.docs.isNotEmpty) {
        _setupCursorByEmail[email] = snapshot.docs.last;
      }

      final items = snapshot.docs.map((doc) {
        final data = doc.data();
        return PublicProfileSetupEntity(
          id: (data['id'] ?? doc.id).toString(),
          payload: data,
        );
      }).toList(growable: false);

      return Result.success(
        PublicProfilePage<PublicProfileSetupEntity>(
          items: items,
          hasMore: snapshot.docs.length == 8,
          nextCursor: _setupCursorByEmail[email]?.id,
        ),
      );
    } catch (error) {
      return Result.error(
          ServerFailure('Unable to fetch profile setups: $error'));
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
      await _firestore.collection('usersv2').doc(currentUserId).update({
        'following': FieldValue.arrayUnion(<String>[targetUserEmail]),
      });
      await _firestore.collection('usersv2').doc(targetUserId).update({
        'followers': FieldValue.arrayUnion(<String>[currentUserEmail]),
      });

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
      await _firestore.collection('usersv2').doc(currentUserId).update({
        'following': FieldValue.arrayRemove(<String>[targetUserEmail]),
      });
      await _firestore.collection('usersv2').doc(targetUserId).update({
        'followers': FieldValue.arrayRemove(<String>[currentUserEmail]),
      });

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
      await _firestore
          .collection('usersv2')
          .doc(userId)
          .update({'links': links});

      final updated = await _firestore.collection('usersv2').doc(userId).get();
      return Result.success(_toEntity(updated));
    } catch (error) {
      return Result.error(ServerFailure('Unable to update links: $error'));
    }
  }
}
