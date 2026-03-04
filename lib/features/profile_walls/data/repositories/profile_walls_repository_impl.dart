import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/firestore/dtos/wall_doc_dto.dart';
import 'package:Prism/core/firestore/firestore_client.dart';
import 'package:Prism/core/firestore/firestore_collections.dart';
import 'package:Prism/core/firestore/firestore_query_specs.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/features/profile_walls/domain/entities/profile_wall_entity.dart';
import 'package:Prism/features/profile_walls/domain/entities/profile_walls_page.dart';
import 'package:Prism/features/profile_walls/domain/repositories/profile_walls_repository.dart';
import 'package:injectable/injectable.dart';

@LazySingleton(as: ProfileWallsRepository)
class ProfileWallsRepositoryImpl implements ProfileWallsRepository {
  ProfileWallsRepositoryImpl(this._firestoreClient);

  final FirestoreClient _firestoreClient;
  final Map<String, String> _cursorByEmail = {};

  @override
  Future<Result<ProfileWallsPage>> fetchProfileWalls({required String email, required bool refresh}) async {
    try {
      final cursor = _cursorByEmail[email];
      final rows = await _firestoreClient.query<_WallRow>(
        FirestoreQuerySpec(
          collection: FirebaseCollections.walls,
          sourceTag: 'profile_walls.fetch',
          filters: <FirestoreFilter>[
            const FirestoreFilter(field: 'review', op: FirestoreFilterOp.isEqualTo, value: true),
            FirestoreFilter(field: 'email', op: FirestoreFilterOp.isEqualTo, value: email),
          ],
          orderBy: const <FirestoreOrderBy>[FirestoreOrderBy(field: 'createdAt', descending: true)],
          limit: 12,
          startAfterDocId: refresh ? null : cursor,
        ),
        (data, docId) => _WallRow(docId: docId, doc: WallDocDto.fromJson(data)),
      );
      if (rows.isNotEmpty) {
        _cursorByEmail[email] = rows.last.docId;
      }

      final items = rows.map((row) => _mapWall(row.doc, row.docId)).toList(growable: false);

      return Result.success(
        ProfileWallsPage(items: items, hasMore: rows.length == 12, nextCursor: _cursorByEmail[email]),
      );
    } catch (error) {
      return Result.error(ServerFailure('Unable to load profile walls: $error'));
    }
  }

  ProfileWallEntity _mapWall(WallDocDto dto, String docId) {
    return ProfileWallEntity(
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

class _WallRow {
  const _WallRow({required this.docId, required this.doc});

  final String docId;
  final WallDocDto doc;
}
