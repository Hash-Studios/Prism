import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/firestore/firestore_client.dart';
import 'package:Prism/core/firestore/firestore_collections.dart';
import 'package:Prism/core/firestore/firestore_query_specs.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/features/setups/domain/entities/setup_entity.dart';
import 'package:Prism/features/setups/domain/entities/setups_page.dart';
import 'package:Prism/features/setups/domain/repositories/setups_repository.dart';
import 'package:injectable/injectable.dart';

@LazySingleton(as: SetupsRepository)
class SetupsRepositoryImpl implements SetupsRepository {
  SetupsRepositoryImpl(this._firestoreClient);

  final FirestoreClient _firestoreClient;
  String? _cursorDocId;
  static const int _setupsReadDedupeMs = 30000;

  @override
  Future<Result<SetupsPage>> fetchSetups({required bool refresh}) async {
    try {
      final rows = await _firestoreClient.query<Map<String, dynamic>>(
        FirestoreQuerySpec(
          collection: FirebaseCollections.setups,
          sourceTag: 'setups.fetch_setups',
          filters: const <FirestoreFilter>[
            FirestoreFilter(field: 'review', op: FirestoreFilterOp.isEqualTo, value: true),
          ],
          orderBy: const <FirestoreOrderBy>[FirestoreOrderBy(field: 'created_at', descending: true)],
          limit: 10,
          startAfterDocId: refresh ? null : _cursorDocId,
          cachePolicy: refresh ? FirestoreCachePolicy.networkOnly : FirestoreCachePolicy.memoryFirst,
          dedupeWindowMs: refresh ? 0 : _setupsReadDedupeMs,
        ),
        (data, docId) => <String, dynamic>{...data, '__docId': docId},
      );
      if (rows.isNotEmpty) {
        _cursorDocId = rows.last['__docId']?.toString();
      }

      final items = rows
          .map((data) {
            final payload = <String, dynamic>{...data};
            payload.remove('__docId');
            return SetupEntity(id: (payload['id'] ?? data['__docId']).toString(), payload: payload);
          })
          .toList(growable: false);

      return Result.success(SetupsPage(items: items, hasMore: rows.length == 10, nextCursor: _cursorDocId));
    } catch (error) {
      return Result.error(ServerFailure('Failed to load setups: $error'));
    }
  }
}
