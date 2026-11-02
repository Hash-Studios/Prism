import 'dart:async';

import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/features/moods/biz/gallery_walls_cubit.dart';
import 'package:Prism/features/moods/domain/entities/wall_mood.dart';
import 'package:Prism/features/moods/domain/repositories/mood_repository.dart';
import 'package:flutter_test/flutter_test.dart';

PrismWallpaper _wall(String id) => PrismWallpaper(
  core: WallpaperCore(id: id, source: WallpaperSource.prism, fullUrl: 'https://example.com/$id.jpg', thumbnailUrl: 't'),
);

class _GalleryRepository implements MoodRepository {
  final StreamController<void> visibility = StreamController<void>.broadcast(sync: true);
  final List<List<String>> requests = <List<String>>[];
  final List<bool> orderFlags = <bool>[];
  final Map<String, Completer<List<PrismWallpaper>>> pending = <String, Completer<List<PrismWallpaper>>>{};
  bool fail = false;

  @override
  Future<List<MoodList>> fetchMoods() async => const <MoodList>[];

  @override
  Future<List<PrismWallpaper>> fetchMoodWalls(List<String> ids, {bool keepOrder = false}) async {
    requests.add(List<String>.of(ids));
    orderFlags.add(keepOrder);
    if (fail) throw StateError('offline');
    return pending[ids.first]?.future ?? ids.map(_wall).toList(growable: false);
  }

  @override
  Stream<void> watchVisibilityChanges() => visibility.stream;
}

List<String> _ids(GalleryWallsState state) =>
    (state as GalleryWallsLoaded).walls.map((wall) => wall.id).toList(growable: false);

void main() {
  late _GalleryRepository repository;
  late GalleryWallsCubit cubit;

  setUp(() {
    repository = _GalleryRepository();
    cubit = GalleryWallsCubit(repository);
  });

  tearDown(() async {
    await cubit.close();
    await repository.visibility.close();
  });

  test('loads exact gallery ids in order and refreshes on visibility changes', () async {
    await cubit.load(<String>['W3', 'W1', 'W2']);

    expect(repository.requests, <List<String>>[
      <String>['W3', 'W1', 'W2'],
    ]);
    expect(repository.orderFlags, <bool>[true]);
    expect(_ids(cubit.state), <String>['W3', 'W1', 'W2']);

    repository.visibility.add(null);
    await pumpEventQueue();

    expect(repository.requests, <List<String>>[
      <String>['W3', 'W1', 'W2'],
      <String>['W3', 'W1', 'W2'],
    ]);
    expect(_ids(cubit.state), <String>['W3', 'W1', 'W2']);
  });

  test('shows loading for a newer request and ignores an older result', () async {
    final Completer<List<PrismWallpaper>> oldResult = Completer<List<PrismWallpaper>>();
    final Completer<List<PrismWallpaper>> newResult = Completer<List<PrismWallpaper>>();
    repository
      ..pending['OLD'] = oldResult
      ..pending['NEW'] = newResult;

    final Future<void> oldLoad = cubit.load(<String>['OLD', 'OLDER']);
    final Future<void> newLoad = cubit.load(<String>['NEW', 'NEWER']);
    expect(cubit.state, isA<GalleryWallsLoading>());

    newResult.complete(<PrismWallpaper>[_wall('NEW')]);
    await newLoad;
    oldResult.complete(<PrismWallpaper>[_wall('OLD')]);
    await oldLoad;

    expect(_ids(cubit.state), <String>['NEW']);
  });

  test('reports read errors and can retry', () async {
    repository.fail = true;

    await cubit.load(<String>['W1', 'W2']);

    expect(cubit.state, isA<GalleryWallsFailed>());
    repository.fail = false;
    await cubit.load(<String>['W1', 'W2']);

    expect(_ids(cubit.state), <String>['W1', 'W2']);
  });
}
