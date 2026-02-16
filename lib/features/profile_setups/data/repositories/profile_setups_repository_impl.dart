import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/features/profile_setups/domain/entities/profile_setup_entity.dart';
import 'package:Prism/features/profile_setups/domain/entities/profile_setups_page.dart';
import 'package:Prism/features/profile_setups/domain/repositories/profile_setups_repository.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:injectable/injectable.dart';

@LazySingleton(as: ProfileSetupsRepository)
class ProfileSetupsRepositoryImpl implements ProfileSetupsRepository {
  ProfileSetupsRepositoryImpl(this._firestore);

  final FirebaseFirestore _firestore;
  final Map<String, DocumentSnapshot<Map<String, dynamic>>> _cursorByEmail = {};

  @override
  Future<Result<ProfileSetupsPage>> fetchProfileSetups({
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
        return ProfileSetupEntity(
            id: (data['id'] ?? doc.id).toString(), payload: data);
      }).toList(growable: false);

      return Result.success(
        ProfileSetupsPage(
          items: items,
          hasMore: snapshot.docs.length == 8,
          nextCursor: _cursorByEmail[email]?.id,
        ),
      );
    } catch (error) {
      return Result.error(
          ServerFailure('Unable to load profile setups: $error'));
    }
  }
}
