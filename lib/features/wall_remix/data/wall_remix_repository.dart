import 'package:Prism/core/firestore/firestore_client.dart';
import 'package:Prism/core/firestore/firestore_collections.dart';
import 'package:Prism/core/firestore/firestore_query_specs.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/features/prism_feed/data/dtos/prism_wall_doc_dto.dart';
import 'package:Prism/features/prism_feed/data/mappers/prism_wall_doc_mapper.dart';
import 'package:Prism/features/user_blocks/domain/repositories/user_block_repository.dart';
import 'package:injectable/injectable.dart';

/// Reads the remix links between approved walls. Callers filter the result with [WallViewer].
@lazySingleton
class WallRemixRepository {
  WallRemixRepository(this._firestoreClient, this._userBlockRepository);

  final FirestoreClient _firestoreClient;
  final UserBlockRepository _userBlockRepository;

  static const int remixLimit = 24;
  static const Duration _timeout = Duration(seconds: 10);

  /// Approved remixes of the wall with Firestore id [originalDocId], newest first. Pass the last row's Firestore id as
  /// [startAfterDocId] to read the next page.
  Future<List<PrismWallpaper>> fetchRemixes(String originalDocId, {String? startAfterDocId}) async {
    if (originalDocId.trim().isEmpty) return const <PrismWallpaper>[];
    return _firestoreClient
        .query<PrismWallpaper>(
          FirestoreQuerySpec(
            collection: FirebaseCollections.walls,
            sourceTag: 'WallRemixRepository.fetchRemixes',
            filters: <FirestoreFilter>[
              FirestoreFilter(field: 'remixOf', op: FirestoreFilterOp.isEqualTo, value: originalDocId),
              const FirestoreFilter(field: 'review', op: FirestoreFilterOp.isEqualTo, value: true),
            ],
            orderBy: const <FirestoreOrderBy>[FirestoreOrderBy(field: 'createdAt', descending: true)],
            limit: remixLimit,
            startAfterDocId: startAfterDocId,
            cachePolicy: FirestoreCachePolicy.serverOnly,
          ),
          (data, docId) => PrismWallDocDto.fromJson(data).toDomain(docId: docId),
        )
        .timeout(_timeout);
  }

  /// The approved wall with Firestore id [docId], or null when it is missing or not approved.
  Future<PrismWallpaper?> fetchApprovedWall(String docId) async {
    if (docId.trim().isEmpty) return null;
    final List<PrismWallpaper> rows = await _firestoreClient
        .query<PrismWallpaper>(
          FirestoreQuerySpec(
            collection: FirebaseCollections.walls,
            sourceTag: 'WallRemixRepository.fetchApprovedWall',
            filters: <FirestoreFilter>[
              FirestoreFilter(field: firestoreDocumentIdField, op: FirestoreFilterOp.isEqualTo, value: docId),
              const FirestoreFilter(field: 'review', op: FirestoreFilterOp.isEqualTo, value: true),
            ],
            limit: 1,
            cachePolicy: FirestoreCachePolicy.serverOnly,
          ),
          (data, id) => PrismWallDocDto.fromJson(data).toDomain(docId: id),
        )
        .timeout(_timeout);
    return rows.isEmpty ? null : rows.single;
  }

  Future<Set<String>> blockedCreatorUids({bool waitForInitialLoad = true}) =>
      _userBlockRepository.getBlockedCreatorUids(waitForInitialLoad: waitForInitialLoad);

  Stream<Set<String>> watchBlockedCreatorUids() => _userBlockRepository.watchBlockedCreatorUids();
}
