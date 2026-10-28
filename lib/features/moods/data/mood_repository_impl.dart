import 'dart:math';

import 'package:Prism/core/firestore/firestore_client.dart';
import 'package:Prism/core/firestore/firestore_collections.dart';
import 'package:Prism/core/firestore/firestore_query_specs.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/user_blocks/blocked_creators_filter.dart';
import 'package:Prism/core/wallpaper/anime_content_filter.dart';
import 'package:Prism/core/wallpaper/prism_preview.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/moods/domain/entities/wall_mood.dart';
import 'package:Prism/features/moods/domain/repositories/mood_repository.dart';
import 'package:Prism/features/personalized_feed/data/personalized_ranking_service.dart';
import 'package:Prism/features/personalized_feed/domain/entities/feed_mix.dart';
import 'package:Prism/features/personalized_feed/domain/repositories/personalized_feed_repository.dart';
import 'package:Prism/features/prism_feed/data/dtos/prism_wall_doc_dto.dart';
import 'package:Prism/features/prism_feed/data/mappers/prism_wall_doc_mapper.dart';
import 'package:Prism/features/user_blocks/domain/repositories/user_block_repository.dart';
import 'package:collection/collection.dart';
import 'package:injectable/injectable.dart';

@LazySingleton(as: MoodRepository)
class MoodRepositoryImpl implements MoodRepository {
  MoodRepositoryImpl(
    this._firestoreClient,
    this._userBlockRepository,
    this._settingsLocal,
    this._feedRepository, {
    @ignoreParam Random? random,
    @ignoreParam DateTime Function()? now,
  }) : _random = random ?? Random(),
       _now = now ?? DateTime.now;

  final FirestoreClient _firestoreClient;
  final UserBlockRepository _userBlockRepository;
  final SettingsLocalDataSource _settingsLocal;
  final PersonalizedFeedRepository _feedRepository;
  final Random _random;
  final DateTime Function() _now;

  static const int _whereInLimit = 30;

  @override
  Future<List<MoodList>> fetchMoods() async {
    final Map<String, dynamic>? doc = await _firestoreClient.getById<Map<String, dynamic>>(
      FirebaseCollections.moods,
      'current',
      (data, _) => data,
      sourceTag: 'moods.current',
    );
    final Object? rawMoods = doc?['moods'];
    if (rawMoods is! List) return const <MoodList>[];
    final List<MoodList> moods = <MoodList>[];
    for (final Object? entry in rawMoods) {
      if (entry is! Map) continue;
      final WallMood? mood = WallMood.parse(entry['id']);
      if (mood == null) continue;
      final List<String> ids = _moodWallIds(entry['wallIds']);
      if (ids.isEmpty) continue;
      moods.add(MoodList(mood: mood, wallIds: ids));
    }
    return moods;
  }

  @override
  Future<List<PrismWallpaper>> fetchMoodWalls(List<String> ids) async {
    if (ids.isEmpty) return const <PrismWallpaper>[];
    final List<PrismWallpaper> walls = await _loadWalls(ids);
    final Set<String> blocked = await _userBlockRepository.getBlockedCreatorUids(waitForInitialLoad: true);
    final List<RankingCandidate> candidates = <RankingCandidate>[
      for (final PrismWallpaper wall in _visible(walls, blocked))
        RankingCandidate(
          item: PrismFeedItem(id: wall.id, wallpaper: wall),
          pool: CandidatePool.taste,
        ),
    ];
    final PersonalizedRankingResult ranked = const PersonalizedRankingService().rank(
      candidates: candidates,
      profile: _feedRepository.currentTasteProfile(),
      recentShows: const <String, int>{},
      excludedKeys: const <String>{},
      mix: FeedMix.familiar,
      random: _random,
      now: _now(),
      limit: candidates.length,
    );
    return ranked.items.whereType<PrismFeedItem>().map((item) => item.wallpaper).toList(growable: false);
  }

  /// Loads the walls by id in batches of 30. Ids match case-sensitively, as the daily job stores them.
  Future<List<PrismWallpaper>> _loadWalls(List<String> ids) async {
    final List<List<PrismWallpaper>> batches = await Future.wait(
      ids.slices(_whereInLimit).map((batch) {
        return _firestoreClient.query<PrismWallpaper>(
          FirestoreQuerySpec(
            collection: FirebaseCollections.walls,
            sourceTag: 'moods.walls',
            filters: <FirestoreFilter>[
              const FirestoreFilter(field: 'review', op: FirestoreFilterOp.isEqualTo, value: true),
              FirestoreFilter(field: 'id', op: FirestoreFilterOp.whereIn, value: batch),
            ],
            limit: _whereInLimit,
            cachePolicy: FirestoreCachePolicy.memoryFirst,
          ),
          (data, docId) => PrismWallDocDto.fromJson(data).toDomain(docId: docId),
        );
      }),
    );
    final Map<String, PrismWallpaper> byId = <String, PrismWallpaper>{
      for (final PrismWallpaper wall in batches.expand((batch) => batch)) wall.id: wall,
    };
    return <PrismWallpaper>[for (final String id in ids) ?byId[id]];
  }

  List<PrismWallpaper> _visible(List<PrismWallpaper> walls, Set<String> blocked) {
    final bool showAnime = AnimeContentFilter.showsAnime(_settingsLocal);
    return walls
        .where(
          (wall) =>
              hasPrismPreview(wall) &&
              !BlockedCreatorsFilter.hidesCreatorUid(wall.core.authorUid, blocked) &&
              (showAnime || !AnimeContentFilter.isAnime(wall)),
        )
        .toList(growable: false);
  }
}

/// Trims the ids and drops empty ones and repeats, keeping the stored order.
List<String> _moodWallIds(Object? value) {
  if (value is! List) return const <String>[];
  final Set<String> ids = <String>{};
  for (final Object? id in value) {
    if (id is! String) continue;
    final String trimmed = id.trim();
    if (trimmed.isNotEmpty) ids.add(trimmed);
  }
  return ids.toList(growable: false);
}
