import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/firestore/dtos/setup_doc_dto.dart';
import 'package:Prism/core/firestore/firestore_client.dart';
import 'package:Prism/core/firestore/firestore_collections.dart';
import 'package:Prism/core/firestore/firestore_query_specs.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
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
      final rows = await _firestoreClient.query<_SetupRow>(
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
        (data, docId) => _SetupRow(docId: docId, doc: SetupDocDto.fromJson(data)),
      );
      if (rows.isNotEmpty) {
        _cursorDocId = rows.last.docId;
      }

      final items = rows.map((row) => _mapSetup(row.doc, row.docId)).toList(growable: false);

      return Result.success(SetupsPage(items: items, hasMore: rows.length == 10, nextCursor: _cursorDocId));
    } catch (error) {
      return Result.error(ServerFailure('Failed to load setups: $error'));
    }
  }

  SetupEntity _mapSetup(SetupDocDto dto, String docId) {
    return SetupEntity(
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
}

class _SetupRow {
  const _SetupRow({required this.docId, required this.doc});

  final String docId;
  final SetupDocDto doc;
}
