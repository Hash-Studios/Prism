import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/features/moods/biz/mood_walls_cubit.dart';
import 'package:Prism/features/moods/domain/entities/wall_mood.dart';
import 'package:Prism/features/moods/domain/repositories/mood_repository.dart';
import 'package:flutter_test/flutter_test.dart';

PrismWallpaper _wall(String id) => PrismWallpaper(
  core: WallpaperCore(id: id, source: WallpaperSource.prism, fullUrl: 'https://example.com/$id.jpg', thumbnailUrl: 't'),
);

class _FakeMoodRepository implements MoodRepository {
  List<MoodList> moods = const <MoodList>[];
  bool fail = false;
  final List<List<String>> requested = <List<String>>[];

  @override
  Future<List<MoodList>> fetchMoods() async {
    if (fail) throw StateError('offline');
    return moods;
  }

  @override
  Future<List<PrismWallpaper>> fetchMoodWalls(List<String> ids) async {
    requested.add(ids);
    return ids.map(_wall).toList(growable: false);
  }
}

List<String> _idsOf(MoodWallsState state) => (state as MoodWallsLoaded).walls.map((wall) => wall.id).toList();

void main() {
  late _FakeMoodRepository repository;

  setUp(() {
    repository = _FakeMoodRepository()
      ..moods = const <MoodList>[
        MoodList(mood: WallMood.dreamy, wallIds: <String>['A', 'B', 'C']),
        MoodList(mood: WallMood.minimal, wallIds: <String>['D']),
      ];
  });

  test('loads the walls of the requested mood', () async {
    final MoodWallsCubit cubit = MoodWallsCubit(repository);
    addTearDown(cubit.close);

    await cubit.load(WallMood.minimal);

    expect(cubit.state, isA<MoodWallsLoaded>());
    expect(_idsOf(cubit.state), <String>['D']);
  });

  test('loads only the first limit ids when a limit is given', () async {
    final MoodWallsCubit cubit = MoodWallsCubit(repository);
    addTearDown(cubit.close);

    await cubit.load(WallMood.dreamy, limit: 2);

    expect(repository.requested, <List<String>>[
      <String>['A', 'B'],
    ]);
    expect(_idsOf(cubit.state), <String>['A', 'B']);
  });

  test('loads an empty list for a mood that is not stored', () async {
    final MoodWallsCubit cubit = MoodWallsCubit(repository);
    addTearDown(cubit.close);

    await cubit.load(WallMood.spatialReady);

    expect(cubit.state, isA<MoodWallsLoaded>());
    expect(_idsOf(cubit.state), isEmpty);
  });

  test('fails when the read throws', () async {
    repository.fail = true;
    final MoodWallsCubit cubit = MoodWallsCubit(repository);
    addTearDown(cubit.close);

    await cubit.load(WallMood.dreamy);

    expect(cubit.state, isA<MoodWallsFailed>());
  });

  test('loads no walls for a platform-only mood on the wrong platform', () async {
    repository.moods = const <MoodList>[
      MoodList(mood: WallMood.spatialReady, wallIds: <String>['S']),
    ];
    final MoodWallsCubit android = MoodWallsCubit(repository, iosMajor: () async => null);
    final MoodWallsCubit ios18 = MoodWallsCubit(repository, iosMajor: () async => 18);
    final MoodWallsCubit ios26 = MoodWallsCubit(repository, iosMajor: () async => 26);
    addTearDown(android.close);
    addTearDown(ios18.close);
    addTearDown(ios26.close);

    await android.load(WallMood.spatialReady);
    await ios18.load(WallMood.spatialReady);
    expect(_idsOf(android.state), isEmpty);
    expect(_idsOf(ios18.state), isEmpty);
    expect(repository.requested, isEmpty);

    await ios26.load(WallMood.spatialReady);
    expect(_idsOf(ios26.state), <String>['S']);
  });
}
