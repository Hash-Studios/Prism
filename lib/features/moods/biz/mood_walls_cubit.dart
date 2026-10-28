import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/features/moods/domain/entities/wall_mood.dart';
import 'package:Prism/features/moods/domain/repositories/mood_repository.dart';
import 'package:Prism/logger/logger.dart';
import 'package:collection/collection.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

sealed class MoodWallsState {
  const MoodWallsState();
}

final class MoodWallsLoading extends MoodWallsState {
  const MoodWallsLoading();
}

/// [walls] is empty when the mood has no walls the user can see.
final class MoodWallsLoaded extends MoodWallsState {
  const MoodWallsLoaded(this.walls);

  final List<PrismWallpaper> walls;
}

final class MoodWallsFailed extends MoodWallsState {
  const MoodWallsFailed();
}

/// The walls of one mood, ordered by the user's taste.
@injectable
class MoodWallsCubit extends Cubit<MoodWallsState> {
  MoodWallsCubit(this._repository) : super(const MoodWallsLoading());

  final MoodRepository _repository;

  /// Loads the first [limit] wall ids of [mood], or all of them when [limit] is null.
  Future<void> load(WallMood mood, {int? limit}) async {
    emit(const MoodWallsLoading());
    try {
      final List<MoodList> moods = await _repository.fetchMoods();
      final List<String> ids = moods.firstWhereOrNull((list) => list.mood == mood)?.wallIds ?? const <String>[];
      final List<PrismWallpaper> walls = await _repository.fetchMoodWalls(
        limit == null ? ids : ids.take(limit).toList(growable: false),
      );
      if (!isClosed) emit(MoodWallsLoaded(walls));
    } catch (error, stackTrace) {
      logger.w('[MoodWallsCubit] load failed for ${mood.id}', error: error, stackTrace: stackTrace);
      if (!isClosed) emit(const MoodWallsFailed());
    }
  }
}
