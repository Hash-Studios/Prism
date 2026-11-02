import 'dart:async';

import 'package:Prism/core/constants/app_functions.dart';
import 'package:Prism/core/firestore/firestore_client.dart';
import 'package:Prism/core/firestore/firestore_collections.dart';
import 'package:Prism/core/firestore/firestore_query_specs.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/user_blocks/blocked_creators.dart';
import 'package:Prism/core/user_blocks/blocked_creators_filter.dart';
import 'package:Prism/core/wallpaper/ai_content_filter.dart';
import 'package:Prism/core/wallpaper/anime_content_filter.dart';
import 'package:Prism/core/wallpaper/free_wall_eligibility.dart';
import 'package:Prism/core/wallpaper/prism_preview.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/features/editors_choice/domain/editors_choice_repository.dart';
import 'package:Prism/features/prism_feed/data/dtos/prism_wall_doc_dto.dart';
import 'package:Prism/features/prism_feed/data/mappers/prism_wall_doc_mapper.dart';
import 'package:Prism/features/user_blocks/domain/repositories/user_block_repository.dart';
import 'package:Prism/features/wallpaper_upload/domain/entities/wall_metadata.dart';
import 'package:cloud_functions/cloud_functions.dart' as cf;
import 'package:injectable/injectable.dart';

typedef EditorsChoiceCaller = Future<Object?> Function(String name, Map<String, Object?> data);

@LazySingleton(as: EditorsChoiceRepository)
class EditorsChoiceRepositoryImpl implements EditorsChoiceRepository {
  EditorsChoiceRepositoryImpl(
    this._firestoreClient,
    this._userBlockRepository,
    this._settingsLocal, {
    @ignoreParam EditorsChoiceCaller? caller,
  }) : _call = caller ?? _callable;

  final FirestoreClient _firestoreClient;
  final UserBlockRepository _userBlockRepository;
  final SettingsLocalDataSource _settingsLocal;
  final EditorsChoiceCaller _call;
  final StreamController<void> _pickChanges = StreamController<void>.broadcast();

  @override
  Stream<void> watchPickChanges() => _pickChanges.stream;

  static Future<Object?> _callable(String name, Map<String, Object?> data) async =>
      (await appFunctions
              .httpsCallable(name, options: cf.HttpsCallableOptions(timeout: const Duration(seconds: 30)))
              .call<Object?>(data))
          .data;

  @override
  Future<List<PrismWallpaper>> fetchPicks({required int limit}) async {
    final List<PrismWallpaper> picks = (await _firestoreClient.query<PrismWallpaper?>(
      FirestoreQuerySpec(
        collection: FirebaseCollections.walls,
        sourceTag: 'editors_choice.picks',
        filters: const <FirestoreFilter>[
          FirestoreFilter(field: 'review', op: FirestoreFilterOp.isEqualTo, value: true),
        ],
        orderBy: const <FirestoreOrderBy>[FirestoreOrderBy(field: 'editorsChoiceAt', descending: true)],
        limit: limit,
        cachePolicy: FirestoreCachePolicy.memoryFirst,
      ),
      (data, docId) => isFreeListableWallDoc(data) && data['editorsChoiceAt'] != null
          ? PrismWallDocDto.fromJson(data).toDomain(docId: docId)
          : null,
    )).whereType<PrismWallpaper>().toList(growable: false);
    final BlockedCreators blocked = await _userBlockRepository.loadBlockedCreators();
    return _visible(picks, blocked);
  }

  @override
  Future<void> setPick({required String wallDocId, required bool picked}) async {
    try {
      await _call('setEditorsChoice', <String, Object?>{
        'wallId': wallDocId,
        'picked': picked,
        'requestId': newWallMetadataOperationId(),
      });
    } on cf.FirebaseFunctionsException catch (error) {
      if (error.code == 'failed-precondition') throw const EditorsChoiceNotEligible();
      rethrow;
    }
    _firestoreClient.invalidateQueryCache();
    _pickChanges.add(null);
  }

  List<PrismWallpaper> _visible(List<PrismWallpaper> walls, BlockedCreators blocked) {
    final bool showAnime = AnimeContentFilter.showsAnime(_settingsLocal);
    final bool showAi = AiContentFilter.showsAi(_settingsLocal);
    return walls
        .where(
          (wall) =>
              hasPrismPreview(wall) &&
              !BlockedCreatorsFilter.hidesCreatorUid(wall.core.authorUid, blocked) &&
              (showAnime || !AnimeContentFilter.isAnime(wall)) &&
              (showAi || !AiContentFilter.isAi(wall)),
        )
        .toList(growable: false);
  }
}
