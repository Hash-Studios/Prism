import 'package:Prism/core/firestore/converters/firestore_json_converters.dart';
import 'package:Prism/core/firestore/firestore_client.dart';
import 'package:Prism/core/firestore/firestore_collections.dart';
import 'package:Prism/core/firestore/firestore_query_specs.dart';
import 'package:Prism/core/user_blocks/blocked_creators_filter.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/features/prism_feed/data/dtos/prism_wall_doc_dto.dart';
import 'package:Prism/features/prism_feed/data/mappers/prism_wall_doc_mapper.dart';
import 'package:Prism/features/prism_feed/data/wall_search_terms.dart';
import 'package:Prism/features/user_blocks/domain/repositories/user_block_repository.dart';
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
  Future<List<PrismWallpaper>> search(
    String query, {
    int limit = 12,
    String? colorId,
    bool depthOnly = false,
    bool spatialOnly = false,
  }) async {
    final String trimmed = query.trim();
    final bool browseOnly = trimmed.isEmpty && (colorId != null || depthOnly || spatialOnly);
    if (trimmed.length < _minQueryLength && !browseOnly) {
      return const <PrismWallpaper>[];
    }
    // The query itself is exact for a lone colour or a lone depth or spatial tier. The rest is checked on the matches.
    final bool checksMatches = browseOnly
        ? (depthOnly || spatialOnly) && colorId != null
        : colorId != null || depthOnly || spatialOnly;
    final List<String> terms = searchTermsOf(trimmed).take(_maxTerms).toList(growable: false);
    // Ranking can only lift an older wall that matches more words when the query fetched it.
    final bool ranks = !browseOnly && terms.length > 1;
    final int fetchLimit = checksMatches || ranks ? limit * _localFilterOverfetch : limit;
    try {
      final List<PrismWallpaper> matches = switch ((browseOnly, depthOnly, spatialOnly)) {
        (true, true, _) => await _run('depth', fetchLimit, _depthFilter, _toWall),
        (true, false, true) => await _run(
          'spatial',
          fetchLimit,
          _spatialFilter,
          _toWall,
          orderBy: _spatialStrongestThenNewest,
        ),
        (true, false, false) => await _run(
          'color',
          fetchLimit,
          FirestoreFilter(field: 'colors', op: FirestoreFilterOp.arrayContains, value: colorId),
          _toWall,
        ),
        _ => await _rankedTextMatches(terms, fetchLimit),
      };
      final Set<String> blocked = await _userBlockRepository.getBlockedCreatorUids();
      final Map<String, PrismWallpaper> unique = <String, PrismWallpaper>{};
      for (final PrismWallpaper wall in matches) {
        final bool hasColor = colorId == null || (wall.colors?.contains(colorId) ?? false);
        final bool hasDepth = !depthOnly || (wall.depthTier?.supportsDepth ?? false);
        final bool hasSpatial = !spatialOnly || (wall.spatial?.tier.suitsSpatialScene ?? false);
        if (hasColor &&
            hasDepth &&
            hasSpatial &&
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
