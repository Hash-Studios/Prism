import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/firestore/dtos/setup_doc_dto.dart';
import 'package:Prism/core/firestore/firestore_client.dart';
import 'package:Prism/core/firestore/firestore_collections.dart';
import 'package:Prism/core/firestore/firestore_query_specs.dart';
import 'package:Prism/core/user_blocks/blocked_creators_filter.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/features/profile_setups/domain/entities/profile_setup_entity.dart';
import 'package:Prism/features/profile_setups/domain/entities/profile_setups_page.dart';
import 'package:Prism/features/profile_setups/domain/repositories/profile_setups_repository.dart';
import 'package:Prism/features/user_blocks/domain/repositories/user_block_repository.dart';
import 'package:injectable/injectable.dart';

@LazySingleton(as: ProfileSetupsRepository)
class ProfileSetupsRepositoryImpl implements ProfileSetupsRepository {
  ProfileSetupsRepositoryImpl(this._firestoreClient, this._userBlockRepository);

  final FirestoreClient _firestoreClient;
  final UserBlockRepository _userBlockRepository;
  final Map<String, String> _cursorByEmail = {};

  @override
  Future<Result<ProfileSetupsPage>> fetchProfileSetups({required String email, required bool refresh}) async {
    if (BlockedCreatorsFilter.hidesCreatorEmail(email, _userBlockRepository.cachedBlockedCreatorEmails)) {
      return Result.success(const ProfileSetupsPage(items: <ProfileSetupEntity>[], hasMore: false, nextCursor: null));
    }
    try {
      final cursor = _cursorByEmail[email];
      final rows = await _firestoreClient.query<_SetupRow>(
        FirestoreQuerySpec(
          collection: FirebaseCollections.setups,
          sourceTag: 'profile_setups.fetch',
          filters: <FirestoreFilter>[
            const FirestoreFilter(field: 'review', op: FirestoreFilterOp.isEqualTo, value: true),
            FirestoreFilter(field: 'email', op: FirestoreFilterOp.isEqualTo, value: email),
          ],
          orderBy: const <FirestoreOrderBy>[FirestoreOrderBy(field: 'created_at', descending: true)],
          limit: 8,
          startAfterDocId: refresh ? null : cursor,
        ),
        (data, docId) => _SetupRow(docId: docId, doc: SetupDocDto.fromJson(data)),
      );
      if (rows.isNotEmpty) {
        _cursorByEmail[email] = rows.last.docId;
      }

      final items = rows.map((row) => _mapSetup(row.doc, row.docId)).toList(growable: false);

      return Result.success(
        ProfileSetupsPage(items: items, hasMore: rows.length == 8, nextCursor: _cursorByEmail[email]),
      );
    } catch (error) {
      return Result.error(ServerFailure('Unable to load profile setups: $error'));
    }
  }

  ProfileSetupEntity _mapSetup(SetupDocDto dto, String docId) {
    return ProfileSetupEntity(
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
      firestoreDocumentId: docId,
    );
  }
}

class _SetupRow {
  const _SetupRow({required this.docId, required this.doc});

  final String docId;
  final SetupDocDto doc;
}
