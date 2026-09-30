import 'dart:math';

import 'package:Prism/core/constants/app_constants.dart';
import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/firestore/firestore_client.dart';
import 'package:Prism/core/firestore/firestore_collections.dart';
import 'package:Prism/core/firestore/firestore_query_specs.dart';
import 'package:Prism/core/persistence/data_sources/feed_cache_local_data_source.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/personalization/personalized_interests_catalog.dart';
import 'package:Prism/core/personalization/taste_profile.dart';
import 'package:Prism/core/personalization/taste_signals.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/user_blocks/blocked_creators_filter.dart';
import 'package:Prism/core/utils/json_utils.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/favourite_walls/domain/entities/favourite_wall_entity.dart';
import 'package:Prism/features/favourite_walls/domain/repositories/favourite_walls_repository.dart';
import 'package:Prism/features/personalized_feed/data/feed_impression_store.dart';
import 'package:Prism/features/personalized_feed/data/personalized_ranking_service.dart';
import 'package:Prism/features/personalized_feed/domain/entities/personalized_feed_page.dart';
import 'package:Prism/features/personalized_feed/domain/repositories/personalized_feed_repository.dart';
import 'package:Prism/features/pexels_feed/domain/repositories/pexels_wallpaper_repository.dart';
import 'package:Prism/features/prism_feed/data/dtos/prism_wall_doc_dto.dart';
import 'package:Prism/features/prism_feed/data/mappers/prism_wall_doc_mapper.dart';
import 'package:Prism/features/user_blocks/domain/repositories/user_block_repository.dart';
import 'package:Prism/features/wallhaven_feed/domain/repositories/wallhaven_wallpaper_repository.dart';
import 'package:Prism/logger/logger.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:injectable/injectable.dart';

@LazySingleton(as: PersonalizedFeedRepository)
class PersonalizedFeedRepositoryImpl implements PersonalizedFeedRepository {
  PersonalizedFeedRepositoryImpl(
    this._firestoreClient,
    this._feedCacheLocal,
    this._settingsLocal,
    this._wallhavenRepository,
    this._pexelsRepository,
    this._userBlockRepository,
    this._favouriteWallsRepository,
    this._tasteSignals,
    this._impressions,
  );

  final FirestoreClient _firestoreClient;
  final FeedCacheLocalDataSource _feedCacheLocal;
  final SettingsLocalDataSource _settingsLocal;
  final WallhavenWallpaperRepository _wallhavenRepository;
  final PexelsWallpaperRepository _pexelsRepository;
  final UserBlockRepository _userBlockRepository;
  final FavouriteWallsRepository _favouriteWallsRepository;
  final TasteSignalStore _tasteSignals;
  final FeedImpressionStore _impressions;
  final PersonalizedRankingService _rankingService = const PersonalizedRankingService();
  final Random _random = Random();

  static const int _cacheTtlHours = 2;

  /// Values the `onWallCategorize` Cloud Function writes to `walls.category`.
  static const List<String> _wallCategories = <String>[
    'Nature', 'Architecture', 'Cars', 'Anime', 'Space', 'Ocean', 'Flowers', 'Neon', 'Dark', 'Abstract', //
    '3D Render', 'Minimal', 'Gradient', 'AI Art', 'Cyberpunk', 'Vintage', 'Landscape', 'Galaxy',
  ];

  /// Reused on `page > 1` to avoid Remote Config + Firestore user doc on every scroll page.
  String? _bootstrapScope;
  List<PersonalizedInterest> _catalog = const <PersonalizedInterest>[];
  List<String> _interests = const <String>[];
  List<String> _following = const <String>[];

  @override
  Future<void> lessLikeThis(FeedItemEntity item) async {
    final DateTime now = DateTime.now().toUtc();
    await _tasteSignals.record(
      TasteSignal(
        action: TasteAction.lessLikeThis,
        at: now,
        terms: RankingCandidate.termsOf(item),
        creator: tasteCreatorOf(item.wallpaperCore),
      ),
    );
    await _impressions.hide(PersonalizedRankingService.canonicalKey(item), now);
  }

  @override
  Future<Result<PersonalizedFeedPage>> fetch(FetchPersonalizedFeedRequest request) async {
    final String userId = app_state.prismUser.id.trim();
    final bool isGuest = userId.isEmpty;
    final String cacheScope = isGuest ? 'guest' : userId.toLowerCase();

    try {
      if (request.refresh || _bootstrapScope != cacheScope) {
        final Map<String, dynamic> userDoc = isGuest
            ? const <String, dynamic>{}
            : await _resolveUserDoc(userId: userId);
        _catalog = await PersonalizedInterestsCatalog.load(
          remoteConfig: FirebaseRemoteConfig.instance,
          settingsLocal: _settingsLocal,
        );
        _interests = _resolveInterests(userDoc, _catalog);
        _following = isGuest ? const <String>[] : _resolveFollowing(userDoc);
        _bootstrapScope = cacheScope;
        if (!isGuest) {
          await _seedTasteFromFavourites(userId);
        }
      }

      final DateTime now = DateTime.now().toUtc();
      final TasteProfile profile = TasteProfile.build(
        interests: _interests,
        following: _following,
        signals: _tasteSignals.read(),
        now: now,
      );
      final FeedMix mix = FeedMix.parse(_settingsLocal.get<String>(personalizedFeedMixLocalKey, defaultValue: ''));

      final List<List<RankingCandidate>> pools = await Future.wait(<Future<List<RankingCandidate>>>[
        _pool(CandidatePool.following, _fetchCreatorItems(following: _following, page: request.page)),
        _pool(CandidatePool.fresh, _fetchFreshItems()),
        _pool(CandidatePool.gems, _randomWallSlice(sourceTag: 'personalized.gems', limit: 30)),
        _pool(CandidatePool.taste, _fetchTasteItems(profile)),
        _fetchExternal(WallpaperSource.wallhaven, refresh: request.refresh, maxQueries: 3),
        _fetchExternal(WallpaperSource.pexels, refresh: request.refresh, maxQueries: 2),
      ]);

      final Set<String> blocked = await _userBlockRepository.getBlockedCreatorEmails(waitForInitialLoad: true);
      final List<RankingCandidate> candidates = pools
          .expand((pool) => pool)
          .where((c) => !BlockedCreatorsFilter.hidesFeedItem(c.item, blocked))
          .toList(growable: false);

      final PersonalizedRankingResult ranking = _rankingService.rank(
        candidates: candidates,
        profile: profile,
        recentShows: _impressions.recentShows(now),
        excludedKeys: request.seenKeys.toSet(),
        mix: mix,
        random: _random,
        now: now,
      );
      await _impressions.recordShown(ranking.usedKeys, now);

      final List<FeedItemEntity> merged = _mergeCachedAndNew(
        request.refresh ? const <FeedItemEntity>[] : request.existingItems,
        ranking.items,
      );
      await _writeCachedItems(scope: cacheScope, cachedItems: merged);

      logger.i(
        '[PersonalizedFeed] fetch success',
        fields: <String, Object?>{
          'is_guest': isGuest,
          'refresh': request.refresh,
          'page': request.page,
          'mix': mix.name,
          'candidates': candidates.length,
          'items': ranking.items.length,
          'source_prism': ranking.sourceCounts[WallpaperSource.prism] ?? 0,
          'source_wallhaven': ranking.sourceCounts[WallpaperSource.wallhaven] ?? 0,
          'source_pexels': ranking.sourceCounts[WallpaperSource.pexels] ?? 0,
        },
      );

      return Result.success(
        PersonalizedFeedPage(
          items: ranking.items,
          hasMore: ranking.items.isNotEmpty,
          usedKeys: ranking.usedKeys,
          sourceCounts: ranking.sourceCounts,
        ),
      );
    } catch (error, stackTrace) {
      logger.e('[PersonalizedFeed] fetch failed', error: error, stackTrace: stackTrace);
      final List<FeedItemEntity> cachedItems = await _readCachedItems(scope: cacheScope);
      if (cachedItems.isNotEmpty) {
        return Result.success(
          PersonalizedFeedPage(
            items: cachedItems,
            hasMore: true,
            usedKeys: cachedItems.map(PersonalizedRankingService.canonicalKey).toList(growable: false),
            sourceCounts: _countSources(cachedItems),
          ),
        );
      }
      return Result.error(ServerFailure('Failed to fetch personalized feed: $error'));
    }
  }

  /// One failing source must not empty the whole feed.
  Future<List<RankingCandidate>> _pool(CandidatePool pool, Future<List<FeedItemEntity>> items) async {
    try {
      return (await items).map((item) => RankingCandidate(item: item, pool: pool)).toList(growable: false);
    } catch (error) {
      logger.w('[PersonalizedFeed] ${pool.name} source failed: $error');
      return const <RankingCandidate>[];
    }
  }

  /// Existing users already told us their taste through favourites. Read them
  /// once so the feed is personal from the first open after this update.
  Future<void> _seedTasteFromFavourites(String userId) async {
    if (_tasteSignals.isSeeded) {
      return;
    }
    final Result<List<FavouriteWallEntity>> result = await _favouriteWallsRepository.fetchFavourites(userId: userId);
    if (result.isFailure) {
      return;
    }
    final DateTime now = DateTime.now().toUtc();
    final List<TasteSignal> signals = <TasteSignal>[
      for (final FavouriteWallEntity fav in result.data ?? const <FavouriteWallEntity>[])
        ?switch (fav) {
          PrismFavouriteWall(:final wallpaper) => TasteSignal.forWallpaper(
            TasteAction.favourite,
            wallpaper.core,
            tags: wallpaper.tags,
            collections: wallpaper.collections,
            at: fav.createdAt ?? now,
          ),
          WallhavenFavouriteWall(:final wallpaper) => TasteSignal.forWallpaper(
            TasteAction.favourite,
            wallpaper.core,
            tags: wallpaper.tags,
            at: now,
          ),
          PexelsFavouriteWall(:final wallpaper) => TasteSignal.forWallpaper(
            TasteAction.favourite,
            wallpaper.core,
            at: now,
          ),
          _ => null,
        },
    ];
    await _tasteSignals.recordAll(signals);
    await _tasteSignals.markSeeded();
  }

  Future<Map<String, dynamic>> _resolveUserDoc({required String userId}) async {
    final doc = await _firestoreClient.getById<Map<String, dynamic>>(
      FirebaseCollections.usersV2,
      userId,
      (data, _) => data,
      sourceTag: 'personalized.user_doc_by_id',
    );
    if (doc != null) {
      return doc;
    }

    final email = app_state.prismUser.email.trim();
    if (email.isEmpty) {
      return <String, dynamic>{};
    }

    final users = await _firestoreClient.query<Map<String, dynamic>>(
      FirestoreQuerySpec(
        collection: FirebaseCollections.usersV2,
        sourceTag: 'personalized.user_doc_by_email',
        filters: <FirestoreFilter>[FirestoreFilter(field: 'email', op: FirestoreFilterOp.isEqualTo, value: email)],
        limit: 1,
        cachePolicy: FirestoreCachePolicy.memoryFirst,
      ),
      (data, _) => data,
    );
    if (users.isEmpty) {
      return <String, dynamic>{};
    }
    return users.first;
  }

  List<String> _resolveInterests(Map<String, dynamic> userDoc, List<PersonalizedInterest> catalog) {
    final remote = _toStringList(userDoc['interestCategories']);
    if (remote.isNotEmpty) {
      return remote;
    }

    final localRaw = _settingsLocal.get<String>('onboarding_v2_interests', defaultValue: '');
    final local = localRaw.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList(growable: false);
    if (local.isNotEmpty) {
      return local;
    }

    return PersonalizedInterestsCatalog.defaultSelection(catalog);
  }

  List<String> _resolveFollowing(Map<String, dynamic> userDoc) {
    final fromSession = app_state.prismUser.following.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    if (fromSession.isNotEmpty) {
      return fromSession;
    }
    return _toStringList(userDoc['following']);
  }

  Future<List<FeedItemEntity>> _fetchCreatorItems({required List<String> following, required int page}) async {
    if (following.isEmpty) {
      return const <FeedItemEntity>[];
    }

    final uniqueFollowing = following.toSet().toList(growable: false);
    final chunks = _chunks(uniqueFollowing, 10);
    final int perChunkLimit = ((12 * page) / chunks.length).ceil().clamp(10, 30);

    final futures = chunks
        .asMap()
        .entries
        .map((entry) {
          final chunkIndex = entry.key;
          final chunk = entry.value;
          return _firestoreClient.query<_CreatorWallRow>(
            FirestoreQuerySpec(
              collection: FirebaseCollections.walls,
              sourceTag: 'personalized.creator_chunk_${chunkIndex + 1}',
              filters: <FirestoreFilter>[
                const FirestoreFilter(field: 'review', op: FirestoreFilterOp.isEqualTo, value: true),
                FirestoreFilter(field: 'email', op: FirestoreFilterOp.whereIn, value: chunk),
              ],
              orderBy: const <FirestoreOrderBy>[FirestoreOrderBy(field: 'createdAt', descending: true)],
              limit: perChunkLimit,
              cachePolicy: FirestoreCachePolicy.memoryFirst,
            ),
            (data, docId) => _CreatorWallRow(
              docId: docId,
              createdAt: DateTime.tryParse((data['createdAt'] ?? '').toString())?.toUtc(),
              dto: PrismWallDocDto.fromJson(data),
            ),
          );
        })
        .toList(growable: false);

    final chunkedRows = await Future.wait(futures);
    final allRows = chunkedRows.expand((rows) => rows).toList(growable: false);
    allRows.sort((a, b) {
      final aAt = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
      final bAt = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
      return bAt.compareTo(aAt);
    });

    final dedupe = <String, FeedItemEntity>{};
    for (final row in allRows) {
      final wall = row.dto.toDomain(docId: row.docId);
      final item = PrismFeedItem(id: wall.id, wallpaper: wall);
      dedupe[PersonalizedRankingService.canonicalKey(item)] = item;
    }

    return dedupe.values.toList(growable: false);
  }

  /// Newest reviewed uploads, so rare new walls still surface. Fatigue sinks
  /// them once seen.
  Future<List<FeedItemEntity>> _fetchFreshItems() => _queryWalls(
    const FirestoreQuerySpec(
      collection: FirebaseCollections.walls,
      sourceTag: 'personalized.fresh',
      filters: <FirestoreFilter>[FirestoreFilter(field: 'review', op: FirestoreFilterOp.isEqualTo, value: true)],
      orderBy: <FirestoreOrderBy>[FirestoreOrderBy(field: 'createdAt', descending: true)],
      limit: 24,
      cachePolicy: FirestoreCachePolicy.memoryFirst,
    ),
  );

  /// Walls from the taste's top categories, from a random point in each.
  Future<List<FeedItemEntity>> _fetchTasteItems(TasteProfile profile) async {
    final List<String> categories = <String>{
      for (final String term in profile.topTerms(6))
        ?_wallCategories.where((c) => term.contains(c.toLowerCase()) || c.toLowerCase().contains(term)).firstOrNull,
    }.toList()..shuffle(_random);
    final List<List<FeedItemEntity>> slices = await Future.wait(
      categories
          .take(2)
          .map((category) => _randomWallSlice(sourceTag: 'personalized.taste', limit: 12, category: category)),
    );
    return slices.expand((slice) => slice).toList(growable: false);
  }

  /// A random window of the reviewed catalog: order by document id and start
  /// after a random id. Old walls get the same chance as new ones.
  Future<List<FeedItemEntity>> _randomWallSlice({
    required String sourceTag,
    required int limit,
    String? category,
  }) async {
    FirestoreQuerySpec spec(String? cursor, int take) => FirestoreQuerySpec(
      collection: FirebaseCollections.walls,
      sourceTag: sourceTag,
      filters: <FirestoreFilter>[
        const FirestoreFilter(field: 'review', op: FirestoreFilterOp.isEqualTo, value: true),
        if (category != null) FirestoreFilter(field: 'category', op: FirestoreFilterOp.isEqualTo, value: category),
      ],
      orderBy: const <FirestoreOrderBy>[FirestoreOrderBy(field: firestoreDocumentIdField)],
      startAfterFieldValues: cursor == null ? null : <Object?>[cursor],
      limit: take,
    );

    final List<FeedItemEntity> first = await _queryWalls(spec(_randomDocId(), limit));
    if (first.length >= limit) {
      return first;
    }
    // Past the last id: wrap around to the start of the key space.
    return <FeedItemEntity>[...first, ...await _queryWalls(spec(null, limit - first.length))];
  }

  String _randomDocId() {
    const String alphabet = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz';
    return String.fromCharCodes(List<int>.generate(20, (_) => alphabet.codeUnitAt(_random.nextInt(alphabet.length))));
  }

  Future<List<FeedItemEntity>> _queryWalls(FirestoreQuerySpec spec) async {
    final List<PrismWallpaper> walls = await _firestoreClient.query<PrismWallpaper>(
      spec,
      (data, docId) => PrismWallDocDto.fromJson(data).toDomain(docId: docId),
    );
    return walls.map((wall) => PrismFeedItem(id: wall.id, wallpaper: wall)).toList(growable: false);
  }

  /// A few of the user's interests per page, each from a random start page,
  /// so external walls change between opens.
  Future<List<RankingCandidate>> _fetchExternal(
    WallpaperSource source, {
    required bool refresh,
    required int maxQueries,
  }) async {
    final Set<String> picked = _interests.map((e) => e.toLowerCase()).toSet();
    List<PersonalizedInterest> entries = _catalog
        .where((e) => e.supports(source) && picked.contains(e.name.toLowerCase()))
        .toList();
    if (entries.isEmpty) {
      entries = _catalog.where((e) => e.supports(source)).toList();
    }
    entries.shuffle(_random);

    final CandidatePool pool = source == WallpaperSource.wallhaven ? CandidatePool.wallhaven : CandidatePool.pexels;
    final List<List<RankingCandidate>> results = await Future.wait(
      entries.take(maxQueries).map((entry) async {
        try {
          final List<FeedItemEntity> items = await _fetchExternalPage(source, entry.query, refresh: refresh);
          return items
              .map((item) => RankingCandidate(item: item, pool: pool, extraTerms: <String>[entry.name]))
              .toList(growable: false);
        } catch (error) {
          logger.w('[PersonalizedFeed] ${source.name} "${entry.query}" failed: $error');
          return const <RankingCandidate>[];
        }
      }),
    );
    return results.expand((e) => e).toList(growable: false);
  }

  Future<List<FeedItemEntity>> _fetchExternalPage(WallpaperSource source, String query, {required bool refresh}) async {
    Future<List<FeedItemEntity>> load(int startPage) async {
      if (source == WallpaperSource.wallhaven) {
        final result = await _wallhavenRepository.fetchFeed(
          categoryName: query,
          refresh: refresh,
          startPage: startPage,
          categories: _settingsLocal.get<int>('WHcategories', defaultValue: 100),
          purity: _settingsLocal.get<int>('WHpurity', defaultValue: 100),
        );
        return (result.data ?? const <WallhavenWallpaper>[])
            .map((wall) => WallhavenFeedItem(id: wall.id, wallpaper: wall))
            .toList(growable: false);
      }
      final result = await _pexelsRepository.fetchFeed(categoryName: query, refresh: refresh, startPage: startPage);
      return (result.data ?? const <PexelsWallpaper>[])
          .map((wall) => PexelsFeedItem(id: wall.id, wallpaper: wall))
          .toList(growable: false);
    }

    final int startPage = refresh ? 1 + _random.nextInt(4) : 1;
    final List<FeedItemEntity> items = await load(startPage);
    if (items.isEmpty && refresh && startPage > 1) {
      // Small queries may have fewer pages than the random start.
      return load(1);
    }
    return items;
  }

  List<FeedItemEntity> _mergeCachedAndNew(List<FeedItemEntity> cachedItems, List<FeedItemEntity> newItems) {
    final merged = <String, FeedItemEntity>{
      for (final item in cachedItems) PersonalizedRankingService.canonicalKey(item): item,
    };
    for (final item in newItems) {
      merged[PersonalizedRankingService.canonicalKey(item)] = item;
    }
    return merged.values.toList(growable: false);
  }

  Map<WallpaperSource, int> _countSources(List<FeedItemEntity> items) {
    return <WallpaperSource, int>{
      WallpaperSource.prism: items.where((e) => e.source == WallpaperSource.prism).length,
      WallpaperSource.wallhaven: items.where((e) => e.source == WallpaperSource.wallhaven).length,
      WallpaperSource.pexels: items.where((e) => e.source == WallpaperSource.pexels).length,
    };
  }

  Future<List<FeedItemEntity>> _readCachedItems({required String scope}) async {
    final snapshot = await _feedCacheLocal.read(source: 'personalized', scope: scope);
    if (snapshot == null || snapshot.payload is! Map) {
      return const <FeedItemEntity>[];
    }
    final Object? rawItems = toJsonMap(snapshot.payload)['items'];
    if (rawItems is! List) {
      return const <FeedItemEntity>[];
    }
    final List<FeedItemEntity> items = rawItems
        .whereType<Map>()
        .map((entry) => _decodeFeedItem(toJsonMap(entry)))
        .whereType<FeedItemEntity>()
        .toList(growable: false);
    final Set<String> blocked = await _userBlockRepository.getBlockedCreatorEmails(waitForInitialLoad: true);
    return BlockedCreatorsFilter.filterFeedItems(items, blocked);
  }

  Future<void> _writeCachedItems({required String scope, required List<FeedItemEntity> cachedItems}) {
    return _feedCacheLocal.write(
      source: 'personalized',
      scope: scope,
      ttlHours: _cacheTtlHours,
      payload: <String, Object?>{'items': cachedItems.map(_encodeFeedItem).toList(growable: false)},
    );
  }

  List<List<String>> _chunks(List<String> list, int size) {
    final out = <List<String>>[];
    for (int i = 0; i < list.length; i += size) {
      final end = (i + size < list.length) ? i + size : list.length;
      out.add(list.sublist(i, end));
    }
    return out;
  }
}

class _CreatorWallRow {
  const _CreatorWallRow({required this.docId, required this.createdAt, required this.dto});

  final String docId;
  final DateTime? createdAt;
  final PrismWallDocDto dto;
}

List<String> _toStringList(Object? value) {
  if (value is! List) {
    return const <String>[];
  }
  return value.map((e) => e?.toString().trim() ?? '').where((e) => e.isNotEmpty).toSet().toList(growable: false);
}

Map<String, Object?> _encodeFeedItem(FeedItemEntity item) => item.when(
  prism: (id, wall) => <String, Object?>{'type': 'prism', 'id': id, 'wall': _encodePrism(wall)},
  wallhaven: (id, wall) => <String, Object?>{'type': 'wallhaven', 'id': id, 'wall': _encodeWallhaven(wall)},
  pexels: (id, wall) => <String, Object?>{'type': 'pexels', 'id': id, 'wall': _encodePexels(wall)},
);

FeedItemEntity? _decodeFeedItem(Map<String, dynamic> map) {
  final type = map['type']?.toString();
  final id = map['id']?.toString() ?? '';
  final wallMap = toJsonMap(map['wall']);
  if (id.isEmpty || wallMap.isEmpty) {
    return null;
  }

  switch (type) {
    case 'prism':
      return PrismFeedItem(id: id, wallpaper: _decodePrism(wallMap));
    case 'wallhaven':
      return WallhavenFeedItem(id: id, wallpaper: _decodeWallhaven(wallMap));
    case 'pexels':
      return PexelsFeedItem(id: id, wallpaper: _decodePexels(wallMap));
  }
  return null;
}

Map<String, Object?> _encodeWallpaperCore(WallpaperCore core) {
  return <String, Object?>{
    'id': core.id,
    'source': core.source.wireValue,
    'fullUrl': core.fullUrl,
    'thumbnailUrl': core.thumbnailUrl,
    'resolution': core.resolution,
    'sizeBytes': core.sizeBytes,
    'authorName': core.authorName,
    'authorEmail': core.authorEmail,
    'authorPhoto': core.authorPhoto,
    'authorId': core.authorId,
    'category': core.category,
    'createdAt': core.createdAt?.toUtc().toIso8601String(),
    'width': core.width,
    'height': core.height,
    'favourites': core.favourites,
  };
}

WallpaperCore _decodeWallpaperCore(Map<String, dynamic> map) {
  return WallpaperCore(
    id: map['id']?.toString() ?? '',
    source: WallpaperSourceX.fromWire(map['source']),
    fullUrl: map['fullUrl']?.toString() ?? '',
    thumbnailUrl: map['thumbnailUrl']?.toString() ?? '',
    resolution: map['resolution']?.toString(),
    sizeBytes: (map['sizeBytes'] as num?)?.toInt(),
    authorName: map['authorName']?.toString(),
    authorEmail: map['authorEmail']?.toString(),
    authorPhoto: map['authorPhoto']?.toString(),
    authorId: map['authorId']?.toString(),
    category: map['category']?.toString(),
    createdAt: DateTime.tryParse(map['createdAt']?.toString() ?? '')?.toUtc(),
    width: (map['width'] as num?)?.toInt(),
    height: (map['height'] as num?)?.toInt(),
    favourites: (map['favourites'] as num?)?.toInt(),
  );
}

Map<String, Object?> _encodePrism(PrismWallpaper wall) {
  return <String, Object?>{
    'core': _encodeWallpaperCore(wall.core),
    'collections': wall.collections,
    'review': wall.review,
    'tags': wall.tags,
    'aiMetadata': wall.aiMetadata,
    if (wall.firestoreDocumentId != null) 'firestoreDocumentId': wall.firestoreDocumentId,
  };
}

PrismWallpaper _decodePrism(Map<String, dynamic> map) {
  final String? fsId = map['firestoreDocumentId']?.toString();
  return PrismWallpaper(
    core: _decodeWallpaperCore(toJsonMap(map['core'])),
    collections: _toStringList(map['collections']),
    review: map['review'] == true,
    tags: _toStringList(map['tags']),
    aiMetadata: toJsonMap(map['aiMetadata']),
    firestoreDocumentId: (fsId != null && fsId.isNotEmpty) ? fsId : null,
  );
}

Map<String, Object?> _encodeWallhaven(WallhavenWallpaper wall) {
  return <String, Object?>{
    'core': _encodeWallpaperCore(wall.core),
    'views': wall.views,
    'favorites': wall.favorites,
    'dimensionX': wall.dimensionX,
    'dimensionY': wall.dimensionY,
    'colors': wall.colors,
    'thumbs': wall.thumbs,
    'tags': wall.tags,
    'sizeBytes': wall.sizeBytes,
  };
}

WallhavenWallpaper _decodeWallhaven(Map<String, dynamic> map) {
  return WallhavenWallpaper(
    core: _decodeWallpaperCore(toJsonMap(map['core'])),
    views: (map['views'] as num?)?.toInt(),
    favorites: (map['favorites'] as num?)?.toInt(),
    dimensionX: (map['dimensionX'] as num?)?.toInt(),
    dimensionY: (map['dimensionY'] as num?)?.toInt(),
    colors: _toStringList(map['colors']),
    thumbs: toJsonMap(map['thumbs']).map((key, value) => MapEntry(key, value.toString())),
    tags: _toStringList(map['tags']),
    sizeBytes: (map['sizeBytes'] as num?)?.toInt(),
  );
}

Map<String, Object?> _encodePexels(PexelsWallpaper wall) {
  return <String, Object?>{
    'core': _encodeWallpaperCore(wall.core),
    'photographer': wall.photographer,
    'photographerUrl': wall.photographerUrl,
    'src': wall.src == null
        ? null
        : <String, Object?>{
            'original': wall.src!.original,
            'large2x': wall.src!.large2x,
            'large': wall.src!.large,
            'medium': wall.src!.medium,
            'small': wall.src!.small,
            'portrait': wall.src!.portrait,
            'landscape': wall.src!.landscape,
            'tiny': wall.src!.tiny,
          },
  };
}

PexelsWallpaper _decodePexels(Map<String, dynamic> map) {
  final src = toJsonMap(map['src']);
  final pexelsSrc = src.isEmpty
      ? null
      : PexelsSrc(
          original: src['original']?.toString() ?? '',
          large2x: src['large2x']?.toString(),
          large: src['large']?.toString(),
          medium: src['medium']?.toString(),
          small: src['small']?.toString(),
          portrait: src['portrait']?.toString(),
          landscape: src['landscape']?.toString(),
          tiny: src['tiny']?.toString(),
        );

  return PexelsWallpaper(
    core: _decodeWallpaperCore(toJsonMap(map['core'])),
    photographer: map['photographer']?.toString(),
    photographerUrl: map['photographerUrl']?.toString(),
    src: pexelsSrc,
  );
}
