import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/features/moods/biz/moods_cubit.dart';
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
  MoodWallsCubit(this._repository, {@ignoreParam Future<int?> Function()? iosMajor})
    : _iosMajor = iosMajor ?? deviceIosMajor,
      super(const MoodWallsLoading());

  final MoodRepository _repository;
  final Future<int?> Function() _iosMajor;
  int _loadVersion = 0;

  /// Loads the first [limit] wall ids of [mood], or all of them when [limit] is null. A mood that this device does not
  /// show, for example from a link, loads no walls.
  Future<void> load(WallMood mood, {int? limit, List<String>? wallIds}) async {
    if (isClosed) return;
    final int loadVersion = ++_loadVersion;
    emit(const MoodWallsLoading());
    try {
      final int? iosMajor = await _iosMajor();
      if (isClosed || loadVersion != _loadVersion) return;
      if (!mood.shownOn(iosMajor: iosMajor)) {
        emit(const MoodWallsLoaded(<PrismWallpaper>[]));
        return;
      }
      final List<String> ids;
      if (wallIds != null) {
        ids = wallIds;
      } else {
        final List<MoodList> moods = await _repository.fetchMoods();
        if (isClosed || loadVersion != _loadVersion) return;
        ids = moods.firstWhereOrNull((list) => list.mood == mood)?.wallIds ?? const <String>[];
      }
      final List<PrismWallpaper> walls = await _repository.fetchMoodWalls(
        limit == null ? ids : ids.take(limit).toList(growable: false),
      );
      if (!isClosed && loadVersion == _loadVersion) emit(MoodWallsLoaded(walls));
    } catch (error, stackTrace) {
      if (loadVersion != _loadVersion) return;
      logger.w('[MoodWallsCubit] load failed for ${mood.id}', error: error, stackTrace: stackTrace);
      if (!isClosed) emit(const MoodWallsFailed());
    }
  }
}
