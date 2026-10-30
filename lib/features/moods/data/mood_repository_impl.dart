import 'dart:async';
import 'dart:math';

import 'package:Prism/core/firestore/firestore_client.dart';
import 'package:Prism/core/firestore/firestore_collections.dart';
import 'package:Prism/core/firestore/firestore_query_specs.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/user_blocks/blocked_creators.dart';
import 'package:Prism/core/user_blocks/blocked_creators_filter.dart';
import 'package:Prism/core/wallpaper/ai_content_filter.dart';
import 'package:Prism/core/wallpaper/anime_content_filter.dart';
import 'package:Prism/core/wallpaper/prism_preview.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/moods/domain/entities/wall_mood.dart';
import 'package:Prism/features/moods/domain/repositories/mood_repository.dart';
import 'package:Prism/features/navigation/views/widgets/personalized_feed_settings_bottom_sheet.dart'
    show personalizedFeedSettingsRevision;
import 'package:Prism/features/personalized_feed/data/personalized_ranking_service.dart';
import 'package:Prism/features/personalized_feed/domain/entities/feed_mix.dart';
import 'package:Prism/features/personalized_feed/domain/repositories/personalized_feed_repository.dart';
import 'package:Prism/features/prism_feed/data/dtos/prism_wall_doc_dto.dart';
import 'package:Prism/features/prism_feed/data/mappers/prism_wall_doc_mapper.dart';
import 'package:Prism/features/user_blocks/domain/repositories/user_block_repository.dart';
import 'package:collection/collection.dart';
import 'package:injectable/injectable.dart';

const int _maxMoodWallIds = 60;

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

  bool _isEligible(Map<String, dynamic> data) {
    if (data['review'] != true ||
        data['originalProtected'] != true ||
        data['is_streak_exclusive'] == true ||
        data['dropReserved'] == true ||
        _isTruthy(data['dropWeek'])) {
      return false;
    }
    final Object? rawCollections = data['collections'];
    if (rawCollections is! List || rawCollections.any((value) => value is! String)) return false;
    final Set<String> premiumCollections = app_state.premiumCollections.toSet();
    return !rawCollections.cast<String>().any((collection) => premiumCollections.contains(collection.trim()));
  }

  bool _isTruthy(Object? value) => value != null && value != false && value != '' && value != 0;

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
      if (ids.isEmpty || moods.any((list) => list.mood == mood)) continue;
      moods.add(MoodList(mood: mood, wallIds: ids));
    }
    return moods;
  }

  @override
  Stream<void> watchVisibilityChanges() {
    return Stream<void>.multi((controller) {
      BlockedCreators blocked = _userBlockRepository.blockedCreators;
      bool showAi = AiContentFilter.showsAi(_settingsLocal);
      final StreamSubscription<BlockedCreators> subscription = _userBlockRepository.watchBlockedCreators().listen(
        (next) {
          if (next == blocked) return;
          blocked = next;
          controller.add(null);
        },
        onError: controller.addError,
        onDone: controller.close,
      );
      void onSettingsChanged() {
        final bool nextShowAi = AiContentFilter.showsAi(_settingsLocal);
        if (nextShowAi == showAi) return;
        showAi = nextShowAi;
        controller.add(null);
      }

      personalizedFeedSettingsRevision.addListener(onSettingsChanged);
      controller
        ..onPause = subscription.pause
        ..onResume = subscription.resume
        ..onCancel = () async {
          personalizedFeedSettingsRevision.removeListener(onSettingsChanged);
          await subscription.cancel();
        };
    }, isBroadcast: true);
  }

  @override
  Future<List<PrismWallpaper>> fetchMoodWalls(List<String> ids, {bool keepOrder = false}) async {
    if (ids.isEmpty) return const <PrismWallpaper>[];
    final List<PrismWallpaper> walls = await _loadWalls(ids);
    final BlockedCreators blocked = await _userBlockRepository.loadBlockedCreators();
    if (keepOrder) return _visible(walls, blocked);
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
    final List<List<PrismWallpaper?>> batches = await Future.wait(
      ids.slices(_whereInLimit).map((batch) {
        return _firestoreClient.query<PrismWallpaper?>(
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
          (data, docId) => _isEligible(data) ? PrismWallDocDto.fromJson(data).toDomain(docId: docId) : null,
        );
      }),
    );
    final Map<String, PrismWallpaper> byId = <String, PrismWallpaper>{
      for (final PrismWallpaper? wall in batches.expand((batch) => batch))
        if (wall != null) wall.id: wall,
    };
    return <PrismWallpaper>[for (final String id in ids) ?byId[id]];
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

/// Trims the ids and drops empty ones and repeats, keeping the stored order.
List<String> _moodWallIds(Object? value) {
  if (value is! List) return const <String>[];
  final Set<String> ids = <String>{};
  for (final Object? id in value) {
    if (id is! String) continue;
    final String trimmed = id.trim();
    if (trimmed.isNotEmpty) ids.add(trimmed);
    if (ids.length == _maxMoodWallIds) break;
  }
  return ids.toList(growable: false);
}
