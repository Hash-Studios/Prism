import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/firestore/firestore_client.dart';
import 'package:Prism/core/firestore/firestore_collections.dart';
import 'package:Prism/core/firestore/firestore_query_specs.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/features/prism_feed/data/dtos/prism_wall_doc_dto.dart';
import 'package:Prism/features/prism_feed/data/mappers/prism_wall_doc_mapper.dart';
import 'package:Prism/features/wallpaper_detail/domain/entities/variant_group.dart';
import 'package:Prism/features/wallpaper_detail/domain/repositories/wall_variant_repository.dart';

final class WallVariantRepositoryImpl implements WallVariantRepository {
  WallVariantRepositoryImpl({FirestoreClient Function()? firestore})
    : _firestore = firestore ?? (() => getIt<FirestoreClient>());

  final FirestoreClient Function() _firestore;

  @override
  Future<VariantGroup?> load(PrismWallpaper wall) async {
    final String groupId = wall.variantGroupId?.trim() ?? '';
    if (groupId.isEmpty || wall.firestoreDocumentId == null) return null;
    final List<({PrismWallpaper wall, int index})> rows = await _firestore().query(
      FirestoreQuerySpec(
        collection: FirebaseCollections.walls,
        sourceTag: 'WallVariantRepository.load',
        filters: <FirestoreFilter>[
          FirestoreFilter(field: 'variantGroupId', op: FirestoreFilterOp.isEqualTo, value: groupId),
          const FirestoreFilter(field: 'review', op: FirestoreFilterOp.isEqualTo, value: true),
        ],
        limit: VariantGroup.maxWalls,
      ),
      (data, docId) {
        final bool showable =
            data['review'] == true && data['originalProtected'] == true && (data['wallpaper_url'] ?? '') == '';
        final PrismWallpaper member = PrismWallDocDto.fromJson(data).toDomain(docId: docId);
        return (wall: member, index: showable ? member.variantIndex ?? -1 : -1);
      },
    );
    final List<PrismWallpaper> walls =
        (rows.where((row) => row.index >= 0).toList()..sort((a, b) => a.index.compareTo(b.index)))
            .map((row) => row.wall)
            .toList();
    final VariantGroup group = VariantGroup(id: groupId, walls: walls);
    return group.length >= 2 && group.indexOfDoc(wall.firestoreDocumentId) >= 0 ? group : null;
  }
}
