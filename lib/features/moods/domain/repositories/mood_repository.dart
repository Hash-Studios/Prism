import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/features/moods/domain/entities/wall_mood.dart';

abstract class MoodRepository {
  /// The moods in `moods/current`, in the stored order. Unknown mood ids and malformed entries are skipped.
  /// Throws when the read fails.
  Future<List<MoodList>> fetchMoods();

  /// The walls with these [ids] that the user can see, ordered by the user's taste. Throws when the read fails.
  Future<List<PrismWallpaper>> fetchMoodWalls(List<String> ids);

  /// Emits when the walls the user can see change, for example when they block or unblock a creator.
  Stream<void> watchVisibilityChanges();
}
