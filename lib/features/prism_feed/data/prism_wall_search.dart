import 'package:Prism/core/firestore/firestore_client.dart';
import 'package:Prism/core/firestore/firestore_collections.dart';
import 'package:Prism/core/firestore/firestore_query_specs.dart';
import 'package:Prism/core/user_blocks/blocked_creators_filter.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/data/categories/categories.dart' as category_data;
import 'package:Prism/features/prism_feed/data/dtos/prism_wall_doc_dto.dart';
import 'package:Prism/features/prism_feed/data/mappers/prism_wall_doc_mapper.dart';
import 'package:Prism/features/user_blocks/domain/repositories/user_block_repository.dart';
import 'package:Prism/logger/logger.dart';
import 'package:injectable/injectable.dart';

/// Reviewed Prism walls whose tags or category match a search query.
@lazySingleton
class PrismWallSearch {
  PrismWallSearch(this._firestoreClient, this._userBlockRepository);

  final FirestoreClient _firestoreClient;
  final UserBlockRepository _userBlockRepository;

  static const int _minQueryLength = 2;

  /// `array-contains-any` and `whereIn` take at most 30 values: 10 words with 3 spellings each.
  static const int _maxTokens = 10;
  static const int _maxFilterValues = 30;
  static const String _failedPrecondition = 'failed-precondition';

  /// Never throws. A failed query, such as a missing index, counts as no match.
  Future<List<PrismWallpaper>> search(String query, {int limit = 12}) async {
    final String trimmed = query.trim();
    if (trimmed.length < _minQueryLength) {
      return const <PrismWallpaper>[];
    }
    try {
      final List<List<PrismWallpaper>> matches = await Future.wait(<Future<List<PrismWallpaper>>>[
        _run(
          'tags',
          limit,
          FirestoreFilter(field: 'tags', op: FirestoreFilterOp.arrayContainsAny, value: _tagVariants(trimmed)),
        ),
        _run(
          'category',
          limit,
          FirestoreFilter(field: 'category', op: FirestoreFilterOp.whereIn, value: _categoryVariants(trimmed)),
        ),
      ]);
      final Set<String> blocked = await _userBlockRepository.getBlockedCreatorEmails();
      final Map<String, PrismWallpaper> unique = <String, PrismWallpaper>{};
      for (final PrismWallpaper wall in matches.expand((List<PrismWallpaper> walls) => walls)) {
        if (!BlockedCreatorsFilter.hidesCreatorEmail(wall.core.authorEmail, blocked)) {
          unique.putIfAbsent(wall.id, () => wall);
        }
      }
      return unique.values.take(limit).toList(growable: false);
    } catch (error, stackTrace) {
      logger.w('[PrismWallSearch] search failed', error: error, stackTrace: stackTrace);
      return const <PrismWallpaper>[];
    }
  }

  Future<List<PrismWallpaper>> _run(String kind, int limit, FirestoreFilter match) async {
    try {
      return await _firestoreClient.query<PrismWallpaper>(
        FirestoreQuerySpec(
          collection: FirebaseCollections.walls,
          sourceTag: 'PrismWallSearch.$kind',
          filters: <FirestoreFilter>[
            const FirestoreFilter(field: 'review', op: FirestoreFilterOp.isEqualTo, value: true),
            match,
          ],
          orderBy: const <FirestoreOrderBy>[FirestoreOrderBy(field: 'createdAt', descending: true)],
          limit: limit,
          cachePolicy: FirestoreCachePolicy.memoryFirst,
        ),
        (data, docId) => PrismWallDocDto.fromJson(data).toDomain(docId: docId),
      );
    } catch (error, stackTrace) {
      final bool missingIndex = error.toString().contains(_failedPrecondition);
      logger.w(
        missingIndex ? '[PrismWallSearch] $kind index is not deployed yet' : '[PrismWallSearch] $kind query failed',
        error: error,
        stackTrace: stackTrace,
      );
      return const <PrismWallpaper>[];
    }
  }

  /// Each word of the query as a tag, in the spellings creators use. The whole phrase fills what is left.
  List<String> _tagVariants(String query) {
    final Set<String> variants = <String>{};
    for (final String token in _tokens(query)) {
      variants.addAll(<String>[token.toLowerCase(), token, _titleCase(token)]);
    }
    for (final String phrase in <String>[query.toLowerCase(), query, _titleCase(query)]) {
      if (variants.length < _maxFilterValues) variants.add(phrase);
    }
    return variants.take(_maxFilterValues).toList(growable: false);
  }

  List<String> _tokens(String query) =>
      query.split(RegExp(r'\s+')).where((String word) => word.isNotEmpty).toSet().take(_maxTokens).toList();

  /// `walls.category` holds the catalogue's category names, so a known name matches exactly.
  List<String> _categoryVariants(String query) {
    final Set<String> words = <String>{query.toLowerCase(), ..._tokens(query).map((String t) => t.toLowerCase())};
    return <String>{
      _titleCase(query),
      for (final definition in category_data.categoryDefinitions)
        if (words.contains(definition.name.toLowerCase())) definition.name,
    }.take(_maxFilterValues).toList(growable: false);
  }

  String _titleCase(String value) => value
      .split(RegExp(r'\s+'))
      .where((String word) => word.isNotEmpty)
      .map((String word) => '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}')
      .join(' ');
}
