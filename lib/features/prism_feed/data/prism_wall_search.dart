import 'package:Prism/core/firestore/converters/firestore_json_converters.dart';
import 'package:Prism/core/firestore/firestore_client.dart';
import 'package:Prism/core/firestore/firestore_collections.dart';
import 'package:Prism/core/firestore/firestore_query_specs.dart';
import 'package:Prism/core/user_blocks/blocked_creators.dart';
import 'package:Prism/core/user_blocks/blocked_creators_filter.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/features/prism_feed/data/dtos/prism_wall_doc_dto.dart';
import 'package:Prism/features/prism_feed/data/mappers/prism_wall_doc_mapper.dart';
import 'package:Prism/features/prism_feed/data/wall_search_terms.dart';
import 'package:Prism/features/user_blocks/domain/repositories/user_block_repository.dart';
import 'package:Prism/features/user_search/data/photo_match_ranking.dart';
import 'package:Prism/features/user_search/data/search_filters.dart';
import 'package:Prism/features/user_search/domain/entities/photo_query.dart';
import 'package:Prism/logger/logger.dart';
import 'package:collection/collection.dart';
import 'package:injectable/injectable.dart';

/// Reviewed Prism walls whose search terms match a search query.
@lazySingleton
class PrismWallSearch {
  PrismWallSearch(this._firestoreClient, this._userBlockRepository);

  final FirestoreClient _firestoreClient;
  final UserBlockRepository _userBlockRepository;

  static const int _minQueryLength = 2;

  static const int _maxTerms = 10;

  /// A colour or a depth tier is checked after the query, so the query asks for more walls to keep enough matches.
  static const int _localFilterOverfetch = 4;
  static const String _failedPrecondition = 'failed-precondition';

  static const FirestoreFilter _depthFilter = FirestoreFilter(
    field: 'depth.tier',
    op: FirestoreFilterOp.whereIn,
    value: <String>['auto', 'menu'],
  );

  static const FirestoreFilter _spatialFilter = FirestoreFilter(
    field: 'spatial.tier',
    op: FirestoreFilterOp.whereIn,
    value: <String>['great', 'ok'],
  );

  static const List<FirestoreOrderBy> _newestFirst = <FirestoreOrderBy>[
    FirestoreOrderBy(field: 'createdAt', descending: true),
  ];

  /// The server query for a kind browse. A live wall is `kind == live`. A desktop wall has `desktopVariant.width`, so
  /// the widest desktop versions come first, then the newest. A light and dark browse lists the first wall of each
  /// colour variant set (`variantIndex == 0`), so each set shows one time.
  static ({FirestoreFilter filter, List<FirestoreOrderBy> orderBy}) _kindQuery(PrismWallKind kind) => switch (kind) {
    PrismWallKind.live => (
      filter: const FirestoreFilter(field: 'kind', op: FirestoreFilterOp.isEqualTo, value: 'live'),
      orderBy: _newestFirst,
    ),
    PrismWallKind.desktop => (
      filter: const FirestoreFilter(field: 'desktopVariant.width', op: FirestoreFilterOp.isGreaterThan, value: 0),
      orderBy: const <FirestoreOrderBy>[
        FirestoreOrderBy(field: 'desktopVariant.width', descending: true),
        FirestoreOrderBy(field: 'createdAt', descending: true),
      ],
    ),
    PrismWallKind.lightDark => (
      filter: const FirestoreFilter(field: 'variantIndex', op: FirestoreFilterOp.isEqualTo, value: 0),
      orderBy: _newestFirst,
    ),
  };

  /// `great` sorts before `ok`, and each tier lists its newest walls first.
  static const List<FirestoreOrderBy> _spatialStrongestThenNewest = <FirestoreOrderBy>[
    FirestoreOrderBy(field: 'spatial.tier'),
    FirestoreOrderBy(field: 'createdAt', descending: true),
  ];

  /// Never throws. A failed query, such as a missing index, counts as no match.
  ///
  /// [colorId] limits the walls to one palette colour. [depthOnly] keeps walls whose Depth Effect tier is `auto` or
  /// `menu`. An empty [query] with either one lists those walls. Firestore cannot combine the array filters, and the
  /// depth query has its own index, so the colour is always checked on the matches. With a text [query] the depth
  /// tier is checked on the matches too.
  ///
  /// [spatialOnly] keeps walls whose Spatial Scene tier is `great` or `ok`. An empty [query] lists those walls, the
  /// strongest first. Otherwise the tier is checked on the matches, like the depth tier.
  ///
  /// [kinds] keeps walls that have every kind. An empty [query] with kinds lists them through one kind's server
  /// query (see [_kindQuery]), unless depth or spatial owns the query. The other filters are checked on the matches.
  ///
  /// Every query keeps `review == true`, so a wall in review or waiting for its release time never matches.
  Future<List<PrismWallpaper>> search(
    String query, {
    int limit = 12,
    String? colorId,
    bool depthOnly = false,
    bool spatialOnly = false,
    Set<PrismWallKind> kinds = const <PrismWallKind>{},
  }) async {
    final String trimmed = query.trim();
    final bool duo = const <String>{'duo', 'duo-reveal', 'duo reveal'}.contains(trimmed.toLowerCase());
    final int filterCount = (colorId == null ? 0 : 1) + (depthOnly ? 1 : 0) + (spatialOnly ? 1 : 0) + kinds.length;
    final bool browseOnly = trimmed.isEmpty && filterCount > 0;
    if (trimmed.length < _minQueryLength && !browseOnly) {
      return const <PrismWallpaper>[];
    }
    // A browse query is exact for its one filter. The other filters, and every filter of a text query, are checked
    // on the matches.
    final bool checksMatches = browseOnly ? filterCount > 1 : filterCount > 0;
    final List<String> terms = searchTermsOf(trimmed).take(_maxTerms).toList(growable: false);
    // Ranking can only lift an older wall that matches more words when the query fetched it.
    final bool ranks = !browseOnly && terms.length > 1;
    final int fetchLimit = checksMatches || ranks ? limit * _localFilterOverfetch : limit;
    try {
      final List<PrismWallpaper> matches = browseOnly
          ? await _browse(fetchLimit, colorId: colorId, depthOnly: depthOnly, spatialOnly: spatialOnly, kinds: kinds)
          : duo
          ? await _run(
              'duo',
              fetchLimit,
              const FirestoreFilter(
                field: 'tags',
                op: FirestoreFilterOp.arrayContainsAny,
                value: <String>['duo', 'duo-reveal'],
              ),
              _toWall,
            )
          : await _rankedTextMatches(terms, fetchLimit);
      final BlockedCreators blocked = await _userBlockRepository.loadBlockedCreators();
      final Map<String, PrismWallpaper> unique = <String, PrismWallpaper>{};
      for (final PrismWallpaper wall in matches) {
        final bool hasColor = colorId == null || (wall.colors?.contains(colorId) ?? false);
        final bool hasDepth = !depthOnly || (wall.depthTier?.supportsDepth ?? false);
        final bool hasSpatial = !spatialOnly || (wall.spatial?.tier.suitsSpatialScene ?? false);
        if (hasColor &&
            hasDepth &&
            hasSpatial &&
            kinds.every((kind) => kind.matches(wall)) &&
            !BlockedCreatorsFilter.hidesCreatorUid(wall.core.authorUid, blocked)) {
          unique.putIfAbsent(wall.id, () => wall);
        }
      }
      return unique.values.take(limit).toList(growable: false);
    } catch (error, stackTrace) {
      logger.w('[PrismWallSearch] search failed', error: error, stackTrace: stackTrace);
      return const <PrismWallpaper>[];
    }
  }

  /// Reviewed walls that share the top colour of [query] or any of its label terms, newest first, without blocked
  /// creators. Each comes with its stored `searchTerms` so the caller can rank by label overlap. Never throws.
  Future<List<PhotoCandidate>> photoCandidates(PhotoQuery query, {int limit = 48}) async {
    final List<String> terms = photoQueryTerms(query).take(_maxTerms).toList(growable: false);
    PhotoCandidate toCandidate(Map<String, dynamic> data, String docId) =>
        (wall: _toWall(data, docId), terms: const FirestoreStringListConverter().fromJson(data['searchTerms']));
    try {
      final List<List<PhotoCandidate>> found = await Future.wait(<Future<List<PhotoCandidate>>>[
        _run(
          'photoColor',
          limit,
          FirestoreFilter(field: 'colors', op: FirestoreFilterOp.arrayContains, value: query.topColor.id),
          toCandidate,
        ),
        if (terms.isNotEmpty)
          _run(
            'photoTerms',
            limit,
            FirestoreFilter(field: 'searchTerms', op: FirestoreFilterOp.arrayContainsAny, value: terms),
            toCandidate,
          ),
      ]);
      final BlockedCreators blocked = await _userBlockRepository.loadBlockedCreators();
      final Map<String, PhotoCandidate> unique = <String, PhotoCandidate>{};
      for (final PhotoCandidate candidate in found.expand((list) => list)) {
        if (!BlockedCreatorsFilter.hidesCreatorUid(candidate.wall.core.authorUid, blocked)) {
          unique.putIfAbsent(candidate.wall.id, () => candidate);
        }
      }
      return unique.values.toList(growable: false);
    } catch (error, stackTrace) {
      logger.w('[PrismWallSearch] photo search failed', error: error, stackTrace: stackTrace);
      return const <PhotoCandidate>[];
    }
  }

  /// One server query for an empty-query list. Depth, then spatial, then a kind, then the colour owns the query.
  /// Light and dark with a colour leaves the query to the colour.
  Future<List<PrismWallpaper>> _browse(
    int limit, {
    required String? colorId,
    required bool depthOnly,
    required bool spatialOnly,
    required Set<PrismWallKind> kinds,
  }) {
    if (depthOnly) return _run('depth', limit, _depthFilter, _toWall);
    if (spatialOnly) return _run('spatial', limit, _spatialFilter, _toWall, orderBy: _spatialStrongestThenNewest);
    // The members of a colour variant set have different colours, so with a colour the colour query lists every
    // member and the set is checked on the device.
    final Iterable<PrismWallKind> serverKinds = PrismWallKind.values.where(
      (kind) => kinds.contains(kind) && !(kind == PrismWallKind.lightDark && colorId != null),
    );
    if (serverKinds.isNotEmpty) {
      final PrismWallKind kind = serverKinds.first;
      final query = _kindQuery(kind);
      return _run('kind.${kind.name}', limit, query.filter, _toWall, orderBy: query.orderBy);
    }
    return _run(
      'color',
      limit,
      FirestoreFilter(field: 'colors', op: FirestoreFilterOp.arrayContains, value: colorId),
      _toWall,
    );
  }

  Future<List<PrismWallpaper>> _rankedTextMatches(List<String> terms, int limit) async {
    if (terms.isEmpty) return const <PrismWallpaper>[];
    final List<_ScoredWall> scored = <_ScoredWall>[
      ...await _run<_ScoredWall>(
        'terms',
        limit,
        FirestoreFilter(field: 'searchTerms', op: FirestoreFilterOp.arrayContainsAny, value: terms),
        (data, docId) => (
          wall: _toWall(data, docId),
          score: _matchedTerms(const FirestoreStringListConverter().fromJson(data['searchTerms']), terms),
        ),
      ),
    ];
    mergeSort(scored, compare: (_ScoredWall a, _ScoredWall b) => b.score.compareTo(a.score));
    return <PrismWallpaper>[for (final _ScoredWall match in scored) match.wall];
  }

  int _matchedTerms(List<String> stored, List<String> terms) => terms.where(stored.contains).length;

  PrismWallpaper _toWall(Map<String, dynamic> data, String docId) =>
      PrismWallDocDto.fromJson(data).toDomain(docId: docId);

  Future<List<T>> _run<T>(
    String kind,
    int limit,
    FirestoreFilter match,
    T Function(Map<String, dynamic> data, String docId) map, {
    List<FirestoreOrderBy> orderBy = _newestFirst,
  }) async {
    try {
      return await _firestoreClient.query<T>(
        FirestoreQuerySpec(
          collection: FirebaseCollections.walls,
          sourceTag: 'PrismWallSearch.$kind',
          filters: <FirestoreFilter>[
            const FirestoreFilter(field: 'review', op: FirestoreFilterOp.isEqualTo, value: true),
            match,
          ],
          orderBy: orderBy,
          limit: limit,
          cachePolicy: FirestoreCachePolicy.memoryFirst,
        ),
        map,
      );
    } catch (error, stackTrace) {
      final bool missingIndex = error.toString().contains(_failedPrecondition);
      logger.w(
        missingIndex ? '[PrismWallSearch] $kind index is not deployed yet' : '[PrismWallSearch] $kind query failed',
        error: error,
        stackTrace: stackTrace,
      );
      return <T>[];
    }
  }
}

typedef _ScoredWall = ({PrismWallpaper wall, int score});
