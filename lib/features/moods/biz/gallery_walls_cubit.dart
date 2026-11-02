import 'dart:async';

import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/features/moods/domain/repositories/mood_repository.dart';
import 'package:Prism/logger/logger.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

sealed class GalleryWallsState {
  const GalleryWallsState();
}

final class GalleryWallsLoading extends GalleryWallsState {
  const GalleryWallsLoading();
}

final class GalleryWallsLoaded extends GalleryWallsState {
  const GalleryWallsLoaded(this.walls);

  final List<PrismWallpaper> walls;
}

final class GalleryWallsFailed extends GalleryWallsState {
  const GalleryWallsFailed();
}

@injectable
class GalleryWallsCubit extends Cubit<GalleryWallsState> {
  GalleryWallsCubit(this._repository) : super(const GalleryWallsLoading()) {
    _visibility = _repository.watchVisibilityChanges().listen((_) => _reload());
  }

  final MoodRepository _repository;
  late final StreamSubscription<void> _visibility;
  List<String>? _wallIds;
  int _loadVersion = 0;

  void _reload() {
    final List<String>? wallIds = _wallIds;
    if (wallIds != null) unawaited(load(wallIds));
  }

  @override
  Future<void> close() async {
    await _visibility.cancel();
    return super.close();
  }

  Future<void> load(List<String> wallIds) async {
    if (isClosed) return;
    final List<String> request = List<String>.unmodifiable(wallIds);
    _wallIds = request;
    final int loadVersion = ++_loadVersion;
    emit(const GalleryWallsLoading());
    try {
      final List<PrismWallpaper> walls = await _repository.fetchMoodWalls(request, keepOrder: true);
      if (!isClosed && loadVersion == _loadVersion) emit(GalleryWallsLoaded(walls));
    } catch (error, stackTrace) {
      if (loadVersion != _loadVersion) return;
      logger.w('[GalleryWallsCubit] load failed', error: error, stackTrace: stackTrace);
      if (!isClosed) emit(const GalleryWallsFailed());
    }
  }
}
