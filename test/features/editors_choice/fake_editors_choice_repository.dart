import 'dart:async';

import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/features/editors_choice/domain/editors_choice_repository.dart';

PrismWallpaper pickWall(String id) => PrismWallpaper(
  core: WallpaperCore(id: id, source: WallpaperSource.prism, fullUrl: '', thumbnailUrl: '', authorName: id),
);

List<PrismWallpaper> pickWalls(int count) => <PrismWallpaper>[for (int i = 0; i < count; i++) pickWall('pick-$i')];

class FakeEditorsChoiceRepository implements EditorsChoiceRepository {
  FakeEditorsChoiceRepository({this.walls = const <PrismWallpaper>[], this.fail = false, this.gate});

  final List<PrismWallpaper> walls;
  final bool fail;

  /// Holds [fetchPicks] until it completes, so a test can see the loading state.
  final Future<void>? gate;

  final List<int> requestedLimits = <int>[];

  @override
  Future<List<PrismWallpaper>> fetchPicks({required int limit}) async {
    requestedLimits.add(limit);
    if (gate != null) await gate;
    if (fail) throw StateError('offline');
    return walls;
  }

  @override
  Future<void> setPick({required String wallDocId, required bool picked}) =>
      Future<void>.error(UnimplementedError('setPick is not used by these tests'));
}
