import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/features/moods/domain/entities/wall_mood.dart';
import 'package:Prism/features/moods/domain/repositories/mood_repository.dart';

/// No moods, for tests that pump Home without testing moods.
class EmptyMoodRepository implements MoodRepository {
  const EmptyMoodRepository();

  @override
  Future<List<MoodList>> fetchMoods() async => const <MoodList>[];

  @override
  Future<List<PrismWallpaper>> fetchMoodWalls(List<String> ids) async => const <PrismWallpaper>[];
}
