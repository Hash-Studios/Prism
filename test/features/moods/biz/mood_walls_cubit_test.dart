import 'dart:async';

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
  final StreamController<void> visibility = StreamController<void>.broadcast(sync: true);

  @override
  Stream<void> watchVisibilityChanges() => visibility.stream;

  List<MoodList> moods = const <MoodList>[];
  bool fail = false;
  final List<List<String>> requested = <List<String>>[];
  final Map<String, Completer<List<PrismWallpaper>>> pendingWalls = <String, Completer<List<PrismWallpaper>>>{};
  Completer<void>? firstWallRequest;
  Completer<void>? twoWallRequests;

  @override
  Future<List<MoodList>> fetchMoods() async {
    if (fail) throw StateError('offline');
    return moods;
  }

  @override
  Future<List<PrismWallpaper>> fetchMoodWalls(List<String> ids) async {
    requested.add(ids);
    if (requested.length == 1) firstWallRequest?.complete();
    if (requested.length == 2) twoWallRequests?.complete();
    final Completer<List<PrismWallpaper>>? pending = pendingWalls[ids.isEmpty ? null : ids.first];
    if (pending != null) return pending.future;
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

  test('does not let an older mood load overwrite a newer result', () async {
    final Completer<List<PrismWallpaper>> olderWalls = Completer<List<PrismWallpaper>>();
    final Completer<List<PrismWallpaper>> newerWalls = Completer<List<PrismWallpaper>>();
    repository
      ..pendingWalls['A'] = olderWalls
      ..pendingWalls['D'] = newerWalls;
    final MoodWallsCubit cubit = MoodWallsCubit(repository);
    addTearDown(cubit.close);

    final Future<void> olderLoad = cubit.load(WallMood.dreamy);
    final Completer<void> firstRequestStarted = Completer<void>();
    final Completer<void> secondRequestStarted = Completer<void>();
    repository
      ..firstWallRequest = firstRequestStarted
      ..twoWallRequests = secondRequestStarted;
    await firstRequestStarted.future;
    final Future<void> newerLoad = cubit.load(WallMood.minimal);
    await secondRequestStarted.future;
    newerWalls.complete(<PrismWallpaper>[_wall('NEW')]);
    await newerLoad;
    olderWalls.complete(<PrismWallpaper>[_wall('OLD')]);
    await olderLoad;

    expect(_idsOf(cubit.state), <String>['NEW']);
  });

  test('ignores visibility changes before the first load', () async {
    final MoodWallsCubit cubit = MoodWallsCubit(repository);
    addTearDown(cubit.close);

    repository.visibility.add(null);
    await pumpEventQueue();

    expect(repository.requested, isEmpty);

    await cubit.load(WallMood.minimal);

    expect(_idsOf(cubit.state), <String>['D']);
  });

  test('reloads each cubit with its own wall ids and limit', () async {
    final MoodWallsCubit first = MoodWallsCubit(repository);
    final MoodWallsCubit second = MoodWallsCubit(repository);
    addTearDown(first.close);
    addTearDown(second.close);

    await first.load(WallMood.dreamy, limit: 1, wallIds: <String>['A', 'B']);
    await second.load(WallMood.minimal, limit: 2, wallIds: <String>['D', 'E', 'F']);
    repository.requested.clear();

    repository.visibility.add(null);
    await pumpEventQueue();

    expect(repository.requested, hasLength(2));
    expect(
      repository.requested,
      containsAll(<List<String>>[
        <String>['A'],
        <String>['D', 'E'],
      ]),
    );
    expect(_idsOf(first.state), <String>['A']);
    expect(_idsOf(second.state), <String>['D', 'E']);
  });

  test('a visibility reload keeps the stale-load guard', () async {
    final Completer<List<PrismWallpaper>> oldWalls = Completer<List<PrismWallpaper>>();
    final Completer<void> firstRequest = Completer<void>();
    final Completer<void> reloadRequest = Completer<void>();
    repository
      ..pendingWalls['A'] = oldWalls
      ..firstWallRequest = firstRequest
      ..twoWallRequests = reloadRequest;
    final MoodWallsCubit cubit = MoodWallsCubit(repository);
    addTearDown(cubit.close);

    final Future<void> oldLoad = cubit.load(WallMood.dreamy);
    await firstRequest.future;

    repository.moods = const <MoodList>[
      MoodList(mood: WallMood.dreamy, wallIds: <String>['B']),
    ];
    repository.visibility.add(null);
    await reloadRequest.future;
    await pumpEventQueue();

    expect(_idsOf(cubit.state), <String>['B']);

    oldWalls.complete(<PrismWallpaper>[_wall('OLD')]);
    await oldLoad;

    expect(_idsOf(cubit.state), <String>['B']);
  });

  test('does not emit a pending wall result after close', () async {
    final Completer<List<PrismWallpaper>> pendingWalls = Completer<List<PrismWallpaper>>();
    final Completer<void> requestStarted = Completer<void>();
    repository
      ..pendingWalls['A'] = pendingWalls
      ..firstWallRequest = requestStarted;
    final MoodWallsCubit cubit = MoodWallsCubit(repository);
    final List<MoodWallsState> states = <MoodWallsState>[];
    final StreamSubscription<MoodWallsState> subscription = cubit.stream.listen(states.add);
    addTearDown(subscription.cancel);

    final Future<void> load = cubit.load(WallMood.dreamy);
    await requestStarted.future;
    await cubit.close();
    pendingWalls.complete(<PrismWallpaper>[_wall('A')]);
    await load;
    await pumpEventQueue();

    expect(states.whereType<MoodWallsLoaded>(), isEmpty);
    expect(cubit.state, isA<MoodWallsLoading>());
  });

  test('reloads the same walls when the user blocks or unblocks a creator, and stops after close', () async {
    final MoodWallsCubit cubit = MoodWallsCubit(repository);

    await cubit.load(WallMood.dreamy, limit: 2);
    expect(repository.requested, <List<String>>[
      <String>['A', 'B'],
    ]);

    repository.visibility.add(null);
    await pumpEventQueue();
    expect(repository.requested.last, <String>['A', 'B']);
    expect(repository.requested, hasLength(2));

    await cubit.close();
    repository.visibility.add(null);
    await pumpEventQueue();
    expect(repository.requested, hasLength(2));
  });
}
