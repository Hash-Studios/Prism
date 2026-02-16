import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/features/setups/domain/entities/setup_entity.dart';
import 'package:Prism/features/setups/domain/entities/setups_page.dart';
import 'package:Prism/features/setups/domain/repositories/setups_repository.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:injectable/injectable.dart';

@LazySingleton(as: SetupsRepository)
class SetupsRepositoryImpl implements SetupsRepository {
  SetupsRepositoryImpl(this._firestore);

  final FirebaseFirestore _firestore;
  DocumentSnapshot<Map<String, dynamic>>? _cursor;

  @override
  Future<Result<SetupsPage>> fetchSetups({required bool refresh}) async {
    try {
      Query<Map<String, dynamic>> query = _firestore
          .collection('setups')
          .where('review', isEqualTo: true)
          .orderBy('created_at', descending: true)
          .limit(10);

      if (!refresh && _cursor != null) {
        query = query.startAfterDocument(_cursor!);
      }

      final snapshot = await query.get();
      if (snapshot.docs.isNotEmpty) {
        _cursor = snapshot.docs.last;
      }

      final items = snapshot.docs.map((doc) {
        final data = doc.data();
        return SetupEntity(
            id: (data['id'] ?? doc.id).toString(), payload: data);
      }).toList(growable: false);

      return Result.success(
        SetupsPage(
          items: items,
          hasMore: snapshot.docs.length == 10,
          nextCursor: _cursor?.id,
        ),
      );
    } catch (error) {
      return Result.error(ServerFailure('Failed to load setups: $error'));
    }
  }
}
