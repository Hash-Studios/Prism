import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/features/profile_walls/domain/entities/profile_wall_entity.dart';
import 'package:Prism/features/profile_walls/domain/entities/profile_walls_page.dart';
import 'package:Prism/features/profile_walls/domain/repositories/profile_walls_repository.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:injectable/injectable.dart';

@LazySingleton(as: ProfileWallsRepository)
class ProfileWallsRepositoryImpl implements ProfileWallsRepository {
  ProfileWallsRepositoryImpl(this._firestore);

  final FirebaseFirestore _firestore;
  final Map<String, DocumentSnapshot<Map<String, dynamic>>> _cursorByEmail = {};

  @override
  Future<Result<ProfileWallsPage>> fetchProfileWalls({
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

      final cursor = _cursorByEmail[email];
      if (!refresh && cursor != null) {
        query = query.startAfterDocument(cursor);
      }

      final snapshot = await query.get();
      if (snapshot.docs.isNotEmpty) {
        _cursorByEmail[email] = snapshot.docs.last;
      }

      final items = snapshot.docs.map((doc) {
        final data = doc.data();
        return ProfileWallEntity(id: (data['id'] ?? doc.id).toString(), payload: data);
      }).toList(growable: false);

      return Result.success(
        ProfileWallsPage(
          items: items,
          hasMore: snapshot.docs.length == 12,
          nextCursor: _cursorByEmail[email]?.id,
        ),
      );
    } catch (error) {
      return Result.error(ServerFailure('Unable to load profile walls: $error'));
    }
  }
}
