import 'dart:async';

import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/features/moods/biz/moods_cubit.dart';
import 'package:Prism/features/moods/domain/entities/wall_mood.dart';
import 'package:Prism/features/moods/domain/repositories/mood_repository.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeMoodRepository implements MoodRepository {
  @override
  Stream<void> watchVisibilityChanges() => const Stream<void>.empty();

  List<MoodList> moods = const <MoodList>[];
  bool fail = false;
  List<Future<List<MoodList>>>? pendingReads;
  int _readIndex = 0;

  @override
  Future<List<MoodList>> fetchMoods() async {
    if (fail) throw StateError('offline');
    final List<Future<List<MoodList>>>? reads = pendingReads;
    if (reads != null) return reads[_readIndex++];
    return moods;
  }

  @override
  Future<List<PrismWallpaper>> fetchMoodWalls(List<String> ids, {bool keepOrder = false}) async =>
      const <PrismWallpaper>[];
}

List<MoodList> _allMoods() => <MoodList>[
  for (final WallMood mood in WallMood.values) MoodList(mood: mood, wallIds: const <String>['A']),
];

List<WallMood> _shown(MoodsCubit cubit) => cubit.state.map((list) => list.mood).toList();

void main() {
  late _FakeMoodRepository repository;

  setUp(() {
    repository = _FakeMoodRepository()..moods = _allMoods();
  });

  test('hides the iOS-only moods on Android', () async {
    final MoodsCubit cubit = MoodsCubit(repository, iosMajor: () async => null);
    addTearDown(cubit.close);

    await cubit.load();

    expect(_shown(cubit), <WallMood>[WallMood.dreamy, WallMood.darkQuiet, WallMood.brightBold, WallMood.minimal]);
  });

  test('shows every mood on iOS 26', () async {
    final MoodsCubit cubit = MoodsCubit(repository, iosMajor: () async => 26);
    addTearDown(cubit.close);

    await cubit.load();

    expect(_shown(cubit), WallMood.values);
  });

  test('hides only spatial ready on iOS 18', () async {
    final MoodsCubit cubit = MoodsCubit(repository, iosMajor: () async => 18);
    addTearDown(cubit.close);

    await cubit.load();

    expect(_shown(cubit), <WallMood>[
      WallMood.dreamy,
      WallMood.darkQuiet,
      WallMood.brightBold,
      WallMood.minimal,
      WallMood.depthReady,
    ]);
  });

  test('keeps the moods on screen when a later read fails', () async {
    final MoodsCubit cubit = MoodsCubit(repository, iosMajor: () async => 26);
    addTearDown(cubit.close);
    await cubit.load();
    final List<MoodList> before = cubit.state;

    repository.fail = true;
    await cubit.load();

    expect(cubit.state, same(before));
  });

  test('does not let an older read overwrite a newer result', () async {
    final Completer<List<MoodList>> older = Completer<List<MoodList>>();
    final Completer<List<MoodList>> newer = Completer<List<MoodList>>();
    repository.pendingReads = <Future<List<MoodList>>>[older.future, newer.future];
    final MoodsCubit cubit = MoodsCubit(repository, iosMajor: () async => 26);
    addTearDown(cubit.close);

    final Future<void> olderLoad = cubit.load();
    final Future<void> newerLoad = cubit.load();
    newer.complete(<MoodList>[
      const MoodList(mood: WallMood.minimal, wallIds: <String>['NEW']),
    ]);
    await newerLoad;
    older.complete(<MoodList>[
      const MoodList(mood: WallMood.dreamy, wallIds: <String>['OLD']),
    ]);
    await olderLoad;

    expect(_shown(cubit), <WallMood>[WallMood.minimal]);
  });

  group('rowMoodsFor', () {
    test('returns two or fewer moods as they are', () {
      final List<MoodList> two = _allMoods().take(2).toList();

      expect(rowMoodsFor(two, DateTime.utc(2026, 10, 28)), two);
      expect(rowMoodsFor(const <MoodList>[], DateTime.utc(2026, 10, 28)), isEmpty);
    });

    test('moves the first mood one place each day and picks two distinct moods', () {
      final List<MoodList> moods = _allMoods().take(4).toList();

      final List<MoodList> today = rowMoodsFor(moods, DateTime.utc(2026, 10, 28, 9));
      final List<MoodList> tomorrow = rowMoodsFor(moods, DateTime.utc(2026, 10, 29, 23));

      expect(today, hasLength(2));
      expect(today.first.mood, isNot(today.last.mood));
      expect(tomorrow, hasLength(2));
      expect(tomorrow.first.mood, isNot(today.first.mood));
    });
  });
}
