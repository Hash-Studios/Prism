import 'dart:math';

import 'package:Prism/core/constants/app_constants.dart';
import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/firestore/firestore_client.dart';
import 'package:Prism/core/firestore/firestore_collections.dart';
import 'package:Prism/core/firestore/firestore_query_specs.dart';
import 'package:Prism/core/persistence/data_sources/feed_cache_local_data_source.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/personalization/personalized_interests_catalog.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/user_blocks/blocked_creators_filter.dart';
import 'package:Prism/core/utils/json_utils.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
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
  );

  final FirestoreClient _firestoreClient;
  final FeedCacheLocalDataSource _feedCacheLocal;
  final SettingsLocalDataSource _settingsLocal;
  final WallhavenWallpaperRepository _wallhavenRepository;
  final PexelsWallpaperRepository _pexelsRepository;
  final UserBlockRepository _userBlockRepository;
  final PersonalizedRankingService _rankingService = const PersonalizedRankingService();

  static const int _pageSize = 24;
  static const int _cacheTtlHours = 2;
  static const int _seenWindow = 300;

  /// Reused on `page > 1` to avoid Remote Config + Firestore user doc on every scroll page.
  String? _feedBootstrapScope;
  Map<String, dynamic>? _cachedUserDoc;
  List<PersonalizedInterest>? _cachedCatalog;
  List<String>? _cachedInterests;
  List<String>? _cachedFollowing;
  _SourceTargets? _cachedTargets;

  void _clearFeedBootstrapCache() {
    _feedBootstrapScope = null;
    _cachedUserDoc = null;
    _cachedCatalog = null;
    _cachedInterests = null;
    _cachedFollowing = null;
    _cachedTargets = null;
  }

  @override
  Future<List<String>> readPersistedSeenKeys() async {
    final userId = app_state.prismUser.id.trim();
    final cacheScope = userId.isEmpty ? 'guest' : userId.toLowerCase();
    final cached = await _readCacheState(scope: cacheScope);
    return cached.seenKeys;
  }

  @override
  Future<Result<PersonalizedFeedPage>> fetch(FetchPersonalizedFeedRequest request) async {
    final userId = app_state.prismUser.id.trim();
    final isGuest = userId.isEmpty;
    final cacheScope = isGuest ? 'guest' : userId.toLowerCase();

    try {
      if (request.refresh) {
        _clearFeedBootstrapCache();
      }

      final bool useBootstrapCache =
          !request.refresh &&
          request.page > 1 &&
          _feedBootstrapScope == cacheScope &&
          _cachedCatalog != null &&
          _cachedInterests != null &&
          _cachedFollowing != null &&
          _cachedTargets != null;

      late final Map<String, dynamic> userDoc;
      late final List<PersonalizedInterest> catalog;
      late final List<String> interests;
      late final List<String> following;
      late final _SourceTargets targets;

      if (useBootstrapCache) {
        userDoc = _cachedUserDoc ?? const <String, dynamic>{};
        catalog = _cachedCatalog!;
        interests = _cachedInterests!;
        following = _cachedFollowing!;
        targets = _cachedTargets!;
      } else {
        userDoc = isGuest ? const <String, dynamic>{} : await _resolveUserDoc(userId: userId);
        catalog = await PersonalizedInterestsCatalog.load(
          remoteConfig: FirebaseRemoteConfig.instance,
          settingsLocal: _settingsLocal,
        );
        interests = _resolveInterests(userDoc, catalog);
        following = isGuest ? const <String>[] : _resolveFollowing(userDoc);
        targets = _resolveTargets();
        _feedBootstrapScope = cacheScope;
        _cachedUserDoc = userDoc;
        _cachedCatalog = catalog;
        _cachedInterests = interests;
        _cachedFollowing = following;
        _cachedTargets = targets;
      }

      final creatorFuture = _fetchCreatorItems(following: following, page: request.page);
      final wallhavenFuture = _fetchWallhavenItems(interests: interests, catalog: catalog, refresh: request.refresh);
      final pexelsFuture = _fetchPexelsItems(interests: interests, catalog: catalog, refresh: request.refresh);
      final discoveryFuture = _fetchDiscoveryItems(interests: interests, catalog: catalog, followingEmails: following);

      final results = await Future.wait<List<FeedItemEntity>>([
        creatorFuture,
        wallhavenFuture,
        pexelsFuture,
        discoveryFuture,
      ]);

      final Set<String> blocked = _userBlockRepository.cachedBlockedCreatorEmails;
      final List<FeedItemEntity> creatorItems = _filterBlockedPrism(results[0], blocked);
      final wallhavenItems = results[1];
      final pexelsItems = results[2];
      final List<FeedItemEntity> discoveryItems = _filterBlockedPrism(results[3], blocked);

      final ranking = _rankingService.rankAndMix(
        creatorItems: creatorItems,
        wallhavenItems: wallhavenItems,
        pexelsItems: pexelsItems,
        discoveryItems: discoveryItems,
        blockedKeys: request.seenKeys.toSet(),
        interests: interests.toSet(),
        creatorTarget: targets.creator,
        discoveryTarget: targets.discovery,
        wallhavenTarget: targets.wallhaven,
        pexelsTarget: targets.pexels,
      );

      final feedSeed = cacheScope.hashCode;
      final feedItems = [...ranking.items]..shuffle(Random(feedSeed));

      final hasMore = feedItems.length >= _pageSize;
      final nextSeen = _trimSeen([...request.seenKeys, ...ranking.usedKeys]);
      final List<FeedItemEntity> merged = _mergeCachedAndNew(
        request.refresh ? const <FeedItemEntity>[] : request.existingItems,
        feedItems,
      );
      final List<FeedItemEntity> mergedFiltered = _filterBlockedPrism(merged, blocked);
      await _writeCacheState(scope: cacheScope, seenKeys: nextSeen, cachedItems: mergedFiltered);

      logger.i(
        '[PersonalizedFeed] fetch success',
        fields: <String, Object?>{
          'is_guest': isGuest,
          'refresh': request.refresh,
          'page': request.page,
          'items': feedItems.length,
          'source_prism': ranking.sourceCounts[WallpaperSource.prism] ?? 0,
          'source_wallhaven': ranking.sourceCounts[WallpaperSource.wallhaven] ?? 0,
          'source_pexels': ranking.sourceCounts[WallpaperSource.pexels] ?? 0,
          'source_discovery': ranking.discoveryCount,
        },
      );

      return Result.success(
        PersonalizedFeedPage(
          items: feedItems,
          hasMore: hasMore,
          usedKeys: ranking.usedKeys,
          sourceCounts: ranking.sourceCounts,
        ),
      );
    } catch (error, stackTrace) {
      logger.e('[PersonalizedFeed] fetch failed', error: error, stackTrace: stackTrace);
      final cachedState = await _readCacheState(scope: cacheScope);
      if (cachedState.cachedItems.isNotEmpty) {
        return Result.success(
          PersonalizedFeedPage(
            items: cachedState.cachedItems,
            hasMore: true,
            usedKeys: cachedState.seenKeys,
            sourceCounts: _countSources(cachedState.cachedItems),
          ),
        );
      }
      return Result.error(ServerFailure('Failed to fetch personalized feed: $error'));
    }
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

  Future<List<FeedItemEntity>> _fetchWallhavenItems({
    required List<String> interests,
    required List<PersonalizedInterest> catalog,
    required bool refresh,
  }) async {
    final active = _activeInterestsForSource(interests, catalog, WallpaperSource.wallhaven);
    final futures = active
        .map(
          (interest) => _wallhavenRepository.fetchFeed(
            categoryName: interest,
            refresh: refresh,
            categories: _settingsLocal.get<int>('WHcategories', defaultValue: 100),
            purity: _settingsLocal.get<int>('WHpurity', defaultValue: 100),
          ),
        )
        .toList(growable: false);

    final results = await Future.wait(futures);
    final items = <FeedItemEntity>[];
    for (final result in results) {
      if (result.isSuccess && result.data != null) {
        items.addAll(result.data!.map((wall) => WallhavenFeedItem(id: wall.id, wallpaper: wall)));
      }
    }
    final seed = app_state.prismUser.id.isEmpty ? 0 : app_state.prismUser.id.hashCode;
    items.shuffle(Random(seed));
    return items;
  }

  /// Fetches recent reviewed wallpapers from any Prism creator as a "discovery"
  /// source that surfaces new creators to the user.
  ///
  /// Rather than filtering by category (which is unreliably populated — most
  /// walls have category = "community"), we fetch the most recent reviewed
  /// walls and rely on the ranking service's interest-hit scoring on the
  /// `collections` and `tags` fields to surface relevant content.
  ///
  /// Requires a composite Firestore index on the `walls` collection:
  ///   Fields: review (ASC), createdAt (DESC)
  Future<List<FeedItemEntity>> _fetchDiscoveryItems({
    required List<String> interests,
    required List<PersonalizedInterest> catalog,
    required List<String> followingEmails,
  }) async {
    // Fetch recent reviewed walls — no category filter so we get a broad pool.
    // The ranking service scores them by interest-hit on collections/tags.
    final rows = await _firestoreClient.query<_CreatorWallRow>(
      const FirestoreQuerySpec(
        collection: FirebaseCollections.walls,
        sourceTag: 'personalized.discovery',
        filters: <FirestoreFilter>[FirestoreFilter(field: 'review', op: FirestoreFilterOp.isEqualTo, value: true)],
        orderBy: <FirestoreOrderBy>[FirestoreOrderBy(field: 'createdAt', descending: true)],
        limit: 40,
        cachePolicy: FirestoreCachePolicy.memoryFirst,
      ),
      (data, docId) => _CreatorWallRow(
        docId: docId,
        createdAt: DateTime.tryParse((data['createdAt'] ?? '').toString())?.toUtc(),
        dto: PrismWallDocDto.fromJson(data),
      ),
    );

    final dedupe = <String, FeedItemEntity>{};
    for (final row in rows) {
      final wall = row.dto.toDomain(docId: row.docId);
      final item = PrismFeedItem(id: wall.id, wallpaper: wall);
      dedupe[PersonalizedRankingService.canonicalKey(item)] = item;
    }

    return dedupe.values.toList(growable: false);
  }

  Future<List<FeedItemEntity>> _fetchPexelsItems({
    required List<String> interests,
    required List<PersonalizedInterest> catalog,
    required bool refresh,
  }) async {
    final active = _activeInterestsForSource(interests, catalog, WallpaperSource.pexels);
    final futures = active
        .map((interest) => _pexelsRepository.fetchFeed(categoryName: interest, refresh: refresh))
        .toList(growable: false);

    final results = await Future.wait(futures);
    final items = <FeedItemEntity>[];
    for (final result in results) {
      if (result.isSuccess && result.data != null) {
        items.addAll(result.data!.map((wall) => PexelsFeedItem(id: wall.id, wallpaper: wall)));
      }
    }
    final seed = app_state.prismUser.id.isEmpty ? 0 : app_state.prismUser.id.hashCode;
    items.shuffle(Random(seed));
    return items;
  }

  List<String> _activeInterestsForSource(
    List<String> interests,
    List<PersonalizedInterest> catalog,
    WallpaperSource source,
  ) {
    final byName = <String, PersonalizedInterest>{for (final entry in catalog) entry.name.toLowerCase(): entry};
    final matched = interests
        .map((interest) => byName[interest.toLowerCase()])
        .whereType<PersonalizedInterest>()
        .where((entry) => entry.supports(source))
        .map((entry) => entry.query)
        .where((entry) => entry.isNotEmpty)
        .toList(growable: false);
    if (matched.isNotEmpty) {
      return matched;
    }

    final fallbackFromCatalog = catalog
        .where((entry) => entry.supports(source))
        .map((entry) => entry.query)
        .where((entry) => entry.isNotEmpty)
        .toList(growable: false);
    if (fallbackFromCatalog.isNotEmpty) {
      return fallbackFromCatalog;
    }

    if (source == WallpaperSource.wallhaven) {
      return const <String>['Popular', 'Landscape'];
    }
    return const <String>['Curated', 'Nature'];
  }

  _SourceTargets _resolveTargets() {
    final mix = _settingsLocal.get<String>(personalizedFeedMixLocalKey, defaultValue: 'balanced').trim().toLowerCase();
    switch (mix) {
      case 'creators':
        // Creator-heavy: 14 following + 2 discovery + 4+4 external = 24
        return const _SourceTargets(creator: 14, discovery: 2, wallhaven: 4, pexels: 4);
      case 'discovery':
        // Discovery-heavy: 6 following + 8 discovery + 5+5 external = 24
        return const _SourceTargets(creator: 6, discovery: 8, wallhaven: 5, pexels: 5);
      default:
        // Balanced: 10 following + 4 discovery + 5+5 external = 24
        return const _SourceTargets(creator: 10, discovery: 4, wallhaven: 5, pexels: 5);
    }
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

  List<String> _trimSeen(List<String> seen) {
    if (seen.length <= _seenWindow) {
      return seen;
    }
    return seen.sublist(seen.length - _seenWindow);
  }

  Map<WallpaperSource, int> _countSources(List<FeedItemEntity> items) {
    return <WallpaperSource, int>{
      WallpaperSource.prism: items.where((e) => e.source == WallpaperSource.prism).length,
      WallpaperSource.wallhaven: items.where((e) => e.source == WallpaperSource.wallhaven).length,
      WallpaperSource.pexels: items.where((e) => e.source == WallpaperSource.pexels).length,
    };
  }

  Future<_CacheState> _readCacheState({required String scope}) async {
    final snapshot = await _feedCacheLocal.read(source: 'personalized', scope: scope);
    if (snapshot == null || snapshot.payload is! Map) {
      return const _CacheState.empty();
    }
    final payload = toJsonMap(snapshot.payload);
    final seen = _toStringList(payload['seenKeys']);
    final rawItems = payload['items'];
    if (rawItems is! List) {
      return _CacheState(seenKeys: seen, cachedItems: const <FeedItemEntity>[]);
    }

    final List<FeedItemEntity> items = rawItems
        .whereType<Map>()
        .map((entry) => _decodeFeedItem(toJsonMap(entry)))
        .whereType<FeedItemEntity>()
        .toList(growable: false);

    final Set<String> blocked = _userBlockRepository.cachedBlockedCreatorEmails;
    return _CacheState(seenKeys: seen, cachedItems: _filterBlockedPrism(items, blocked));
  }

  Future<void> _writeCacheState({
    required String scope,
    required List<String> seenKeys,
    required List<FeedItemEntity> cachedItems,
  }) {
    return _feedCacheLocal.write(
      source: 'personalized',
      scope: scope,
      ttlHours: _cacheTtlHours,
      payload: <String, Object?>{
        'seenKeys': seenKeys,
        'items': cachedItems.map(_encodeFeedItem).toList(growable: false),
      },
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

  List<FeedItemEntity> _filterBlockedPrism(List<FeedItemEntity> items, Set<String> blocked) {
    if (blocked.isEmpty) {
      return items;
    }
    return items
        .where(
          (FeedItemEntity e) => e.maybeWhen(
            prism: (_, w) => !BlockedCreatorsFilter.hidesCreatorEmail(w.core.authorEmail, blocked),
            orElse: () => true,
          ),
        )
        .toList(growable: false);
  }
}

class _CreatorWallRow {
  const _CreatorWallRow({required this.docId, required this.createdAt, required this.dto});

  final String docId;
  final DateTime? createdAt;
  final PrismWallDocDto dto;
}

class _CacheState {
  const _CacheState({required this.seenKeys, required this.cachedItems});

  const _CacheState.empty() : seenKeys = const <String>[], cachedItems = const <FeedItemEntity>[];

  final List<String> seenKeys;
  final List<FeedItemEntity> cachedItems;
}

class _SourceTargets {
  const _SourceTargets({required this.creator, required this.discovery, required this.wallhaven, required this.pexels});

  final int creator;
  final int discovery;
  final int wallhaven;
  final int pexels;
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
