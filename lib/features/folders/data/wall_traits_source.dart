import 'package:Prism/core/firestore/firestore_client.dart';
import 'package:Prism/core/firestore/firestore_collections.dart';
import 'package:Prism/core/firestore/firestore_query_specs.dart';
import 'package:Prism/features/favourite_walls/domain/entities/favourite_wall_entity.dart';
import 'package:Prism/features/folders/domain/entities/folder_entity.dart';
import 'package:Prism/features/folders/domain/section_suggester.dart';
import 'package:Prism/features/moods/domain/wall_mood_rules.dart';
import 'package:collection/collection.dart';

/// Reads the mood, category and colour fields of a folder's Prism walls from `walls`, 30 ids per query. Wallhaven and
/// Pexels walls have no such fields, so they get none. Keyed by [folderItemKey].
class WallTraitsSource {
  const WallTraitsSource(this._firestore);

  static const int _whereInLimit = 30;

  final FirestoreClient _firestore;

  Future<Map<String, WallTraits>> traitsOf(List<FavouriteWallEntity> walls) async {
    final Map<String, String> keyById = <String, String>{
      for (final FavouriteWallEntity wall in walls)
        if (wall case PrismFavouriteWall(:final wallpaper) when wallpaper.id.isNotEmpty)
          wallpaper.id: folderItemKey(wall),
    };
    final List<List<MapEntry<String, WallTraits>>> batches = await Future.wait(
      keyById.keys
          .slices(_whereInLimit)
          .map(
            (batch) => _firestore.query<MapEntry<String, WallTraits>>(
              FirestoreQuerySpec(
                collection: FirebaseCollections.walls,
                sourceTag: 'folders.section_suggestions',
                filters: <FirestoreFilter>[
                  const FirestoreFilter(field: 'review', op: FirestoreFilterOp.isEqualTo, value: true),
                  FirestoreFilter(field: 'id', op: FirestoreFilterOp.whereIn, value: batch),
                ],
                limit: _whereInLimit,
              ),
              (data, docId) {
                final WallMoodFields fields = WallMoodFields.fromDoc(data);
                return MapEntry<String, WallTraits>(
                  data['id'] is String ? data['id'] as String : docId,
                  WallTraits(moods: wallMoodsOf(fields), category: fields.category, colours: fields.colors),
                );
              },
            ),
          ),
    );
    return <String, WallTraits>{
      for (final MapEntry<String, WallTraits> entry in batches.expand((batch) => batch))
        if (keyById[entry.key] case final String key) key: entry.value,
    };
  }
}
