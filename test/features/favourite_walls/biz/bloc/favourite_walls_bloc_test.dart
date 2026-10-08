import 'dart:async';

import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/features/favourite_walls/biz/bloc/favourite_walls_bloc.j.dart';
import 'package:Prism/features/favourite_walls/domain/entities/favourite_wall_entity.dart';
import 'package:Prism/features/favourite_walls/domain/usecases/favourite_walls_usecases.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../support/fav_fixtures.dart';

class _MockFetchFavouriteWallsUseCase extends Mock implements FetchFavouriteWallsUseCase {}

class _MockToggleFavouriteWallUseCase extends Mock implements ToggleFavouriteWallUseCase {}

class _MockClearFavouriteWallsUseCase extends Mock implements ClearFavouriteWallsUseCase {}

void main() {
  setUpAll(() {
    registerFallbackValue(const FetchFavouriteWallsParams(userId: 'user_1'));
    registerFallbackValue(
      const ToggleFavouriteWallParams(
        userId: 'user_1',
        currentlyFavourited: false,
        wall: LegacyFavouriteWall(id: 'w1', source: WallpaperSource.prism, legacyPayload: <String, Object?>{}),
      ),
    );
    registerFallbackValue(const ClearFavouriteWallsParams(userId: 'user_1', wallIds: <String>['w1']));
  });

  late _MockFetchFavouriteWallsUseCase fetchUseCase;
  late _MockToggleFavouriteWallUseCase toggleUseCase;
  late _MockClearFavouriteWallsUseCase clearUseCase;

  setUp(() {
    fetchUseCase = _MockFetchFavouriteWallsUseCase();
    toggleUseCase = _MockToggleFavouriteWallUseCase();
    clearUseCase = _MockClearFavouriteWallsUseCase();

    when(() => fetchUseCase(any())).thenAnswer(
      (_) async => Result.success(const <FavouriteWallEntity>[
        LegacyFavouriteWall(id: 'w1', source: WallpaperSource.prism, legacyPayload: <String, Object?>{}),
      ]),
    );

    when(() => toggleUseCase(any())).thenAnswer((_) async => Result.success(true));

    when(() => clearUseCase(any())).thenAnswer((_) async => Result.success(true));
  });

  blocTest<FavouriteWallsBloc, FavouriteWallsState>(
    'loads favourites for user and toggles item',
    build: () => FavouriteWallsBloc(fetchUseCase, toggleUseCase, clearUseCase),
    act: (bloc) => bloc
      ..add(const FavouriteWallsEvent.started(userId: 'user_1'))
      ..add(
        const FavouriteWallsEvent.toggleRequested(
          wall: LegacyFavouriteWall(id: 'w2', source: WallpaperSource.pexels, legacyPayload: <String, Object?>{}),
        ),
      ),
    verify: (bloc) {
      expect(bloc.state.status, LoadStatus.success);
      expect(bloc.state.items.length, 2);
      expect(bloc.state.items.first.id, 'w2', reason: 'a new favourite sorts first');
    },
  );

  FavouriteWallsBloc build() => FavouriteWallsBloc(fetchUseCase, toggleUseCase, clearUseCase);

  ToggleFavouriteWallParams lastToggle() =>
      verify(() => toggleUseCase(captureAny())).captured.last as ToggleFavouriteWallParams;

  group('explicit intent', () {
    test('desired true never removes a wall the list already holds', () async {
      final bloc = build()..add(const FavouriteWallsEvent.started(userId: 'user_1'));
      await bloc.stream.firstWhere((state) => state.status == LoadStatus.success);

      bloc.add(FavouriteWallsEvent.toggleRequested(wall: legacyFav('w1'), desired: true, operationId: 1));
      await bloc.stream.firstWhere((state) => state.completedOperationId == 1);

      expect(lastToggle().currentlyFavourited, isFalse);
      await bloc.close();
    });

    test('desired false removes even when the list has not loaded the wall', () async {
      final bloc = build();
      bloc.add(FavouriteWallsEvent.toggleRequested(wall: legacyFav('w9'), desired: false, operationId: 1));
      await bloc.stream.firstWhere((state) => state.completedOperationId == 1);

      expect(lastToggle().currentlyFavourited, isTrue);
      await bloc.close();
    });

    test('without desired the bloc still infers the action from its list', () async {
      final bloc = build()..add(const FavouriteWallsEvent.started(userId: 'user_1'));
      await bloc.stream.firstWhere((state) => state.status == LoadStatus.success);

      bloc.add(FavouriteWallsEvent.toggleRequested(wall: legacyFav('w1'), operationId: 1));
      await bloc.stream.firstWhere((state) => state.completedOperationId == 1);

      expect(lastToggle().currentlyFavourited, isTrue);
      await bloc.close();
    });
  });

  group('favouritedAt', () {
    test('a new favourite without any date sorts first and carries the time it was saved', () async {
      when(
        () => fetchUseCase(any()),
      ).thenAnswer((_) async => Result.success(<FavouriteWallEntity>[prismFav('old', createdAt: DateTime.utc(2026))]));
      final bloc = build()..add(const FavouriteWallsEvent.started(userId: 'user_1'));
      await bloc.stream.firstWhere((state) => state.status == LoadStatus.success);

      bloc.add(FavouriteWallsEvent.toggleRequested(wall: pexelsFav('fresh'), desired: true, operationId: 1));
      await bloc.stream.firstWhere((state) => state.completedOperationId == 1);

      expect(bloc.state.items.map((wall) => wall.id), <String>['fresh', 'old']);
      expect(bloc.state.items.first.favouritedAt, isNotNull);
      expect(lastToggle().wall.favouritedAt, bloc.state.items.first.favouritedAt, reason: 'the doc and the list agree');
      await bloc.close();
    });

    test('undo keeps the saved date, falls back to the upload date, and stamps now only when it has neither', () async {
      final bloc = build()..add(const FavouriteWallsEvent.started(userId: 'user_1'));
      await bloc.stream.firstWhere((state) => state.status == LoadStatus.success);
      final DateTime saved = DateTime.utc(2026, 4);

      bloc.add(
        FavouriteWallsEvent.restoreRequested(
          walls: <FavouriteWallEntity>[
            pexelsFav('a').withFavouritedAt(saved),
            pexelsFav('b'),
            prismFav('c', createdAt: DateTime.utc(2020)),
          ],
          operationId: 1,
        ),
      );
      await bloc.stream.firstWhere((state) => state.completedOperationId == 1);

      final byId = {for (final wall in bloc.state.items) wall.id: wall};
      expect(byId['a']!.favouritedAt, saved);
      expect(byId['b']!.favouritedAt, isNotNull);
      expect(byId['c']!.favouritedAt, DateTime.utc(2020));
      expect(bloc.state.items.first.id, 'b', reason: 'the newly stamped wall is the most recent');
      await bloc.close();
    });
  });

  group('synced', () {
    test('an empty list from the server still moves the bloc to success for that user', () async {
      final bloc = build();

      bloc.add(const FavouriteWallsEvent.synced(userId: 'user_1', items: <FavouriteWallEntity>[]));
      await bloc.stream.first;

      expect(bloc.state.status, LoadStatus.success);
      expect(bloc.state.userId, 'user_1');
      expect(bloc.state.items, isEmpty);
      await bloc.close();
    });

    test('replaces the items, newest first', () async {
      final bloc = build();

      bloc.add(
        FavouriteWallsEvent.synced(
          userId: 'user_1',
          items: <FavouriteWallEntity>[
            prismFav('old', createdAt: DateTime.utc(2026)),
            prismFav('new', createdAt: DateTime.utc(2026, 2)),
          ],
        ),
      );
      await bloc.stream.first;

      expect(bloc.state.items.map((wall) => wall.id), <String>['new', 'old']);
      await bloc.close();
    });
  });

  group('clear all', () {
    test('fetches first, then removes what the server holds', () async {
      when(
        () => fetchUseCase(any()),
      ).thenAnswer((_) async => Result.success(<FavouriteWallEntity>[prismFav('a'), prismFav('from_other_device')]));
      final bloc = build()..add(const FavouriteWallsEvent.started(userId: 'user_1'));
      await bloc.stream.firstWhere((state) => state.status == LoadStatus.success);

      bloc.add(const FavouriteWallsEvent.clearRequested(operationId: 1));
      await bloc.stream.firstWhere((state) => state.completedOperationId == 1);

      final ClearFavouriteWallsParams params =
          verify(() => clearUseCase(captureAny())).captured.single as ClearFavouriteWallsParams;
      expect(params.wallIds, <String>['a', 'from_other_device']);
      expect(bloc.state.actionStatus, ActionStatus.success);
      await bloc.close();
    });

    test('a failed fetch aborts with a failure and never clears', () async {
      final bloc = build()..add(const FavouriteWallsEvent.started(userId: 'user_1'));
      await bloc.stream.firstWhere((state) => state.status == LoadStatus.success);
      when(() => fetchUseCase(any())).thenAnswer((_) async => Result.error(const ServerFailure('offline')));

      bloc.add(const FavouriteWallsEvent.clearRequested(operationId: 1));
      await bloc.stream.firstWhere((state) => state.completedOperationId == 1);

      expect(bloc.state.actionStatus, ActionStatus.failure);
      verifyNever(() => clearUseCase(any()));
      await bloc.close();
    });
  });

  test('a guest can load and toggle with no user id', () async {
    final bloc = build()..add(const FavouriteWallsEvent.started(userId: ''));
    await bloc.stream.firstWhere((state) => state.status == LoadStatus.success);

    bloc.add(FavouriteWallsEvent.toggleRequested(wall: pexelsFav('g'), desired: true, operationId: 1));
    await bloc.stream.firstWhere((state) => state.completedOperationId == 1);

    expect(lastToggle().userId, '');
    await bloc.close();
  });

  test('toggled walls get favouritedAt so recently added puts the latest first', () async {
    when(() => fetchUseCase(any())).thenAnswer((_) async => Result.success(const <FavouriteWallEntity>[]));
    final bloc = FavouriteWallsBloc(fetchUseCase, toggleUseCase, clearUseCase)
      ..add(const FavouriteWallsEvent.started(userId: 'user_1'));
    await bloc.stream.firstWhere((s) => s.status == LoadStatus.success);

    bloc.add(FavouriteWallsEvent.toggleRequested(wall: prismFav('first')));
    await bloc.stream.firstWhere((s) => s.items.length == 1);
    await Future<void>.delayed(const Duration(milliseconds: 5));
    bloc.add(FavouriteWallsEvent.toggleRequested(wall: wallhavenFav('second')));
    await bloc.stream.firstWhere((s) => s.items.length == 2);

    expect(bloc.state.items.every((w) => w.favouritedAt != null), isTrue);
    expect(applyFavouritesView(bloc.state.items).map((w) => w.id), <String>['second', 'first']);
    await bloc.close();
  });

  test('the timestamp sent to storage is the timestamp shown in state', () async {
    when(() => fetchUseCase(any())).thenAnswer((_) async => Result.success(const <FavouriteWallEntity>[]));
    final Completer<void> firstWrite = Completer<void>();
    final List<ToggleFavouriteWallParams> storedParams = <ToggleFavouriteWallParams>[];
    when(() => toggleUseCase(any())).thenAnswer((invocation) async {
      storedParams.add(invocation.positionalArguments.single as ToggleFavouriteWallParams);
      if (storedParams.length == 1) await firstWrite.future;
      return Result.success(true);
    });
    final bloc = FavouriteWallsBloc(fetchUseCase, toggleUseCase, clearUseCase)
      ..add(const FavouriteWallsEvent.started(userId: 'user_1'));
    await bloc.stream.firstWhere((s) => s.status == LoadStatus.success);

    bloc.add(FavouriteWallsEvent.toggleRequested(wall: prismFav('new')));
    await Future<void>.delayed(const Duration(milliseconds: 10));
    firstWrite.complete();
    await bloc.stream.firstWhere((s) => s.items.length == 1);
    bloc.add(FavouriteWallsEvent.toggleRequested(wall: wallhavenFav('newer')));
    await bloc.stream.firstWhere((s) => s.items.length == 2);

    expect(storedParams, hasLength(2));
    expect(storedParams.first.wall.favouritedAt, isNotNull);
    expect(bloc.state.items.singleWhere((wall) => wall.id == 'new').favouritedAt, storedParams.first.wall.favouritedAt);
    expect(
      bloc.state.items.singleWhere((wall) => wall.id == 'newer').favouritedAt,
      storedParams.last.wall.favouritedAt,
    );
    expect(applyFavouritesView(bloc.state.items).map((wall) => wall.id), <String>['newer', 'new']);
    await bloc.close();
  });

  test('restoring an old favourite supplies one timestamp to storage and state', () async {
    when(() => fetchUseCase(any())).thenAnswer((_) async => Result.success(const <FavouriteWallEntity>[]));
    ToggleFavouriteWallParams? storedParams;
    when(() => toggleUseCase(any())).thenAnswer((invocation) async {
      storedParams = invocation.positionalArguments.single as ToggleFavouriteWallParams;
      return Result.success(true);
    });
    final bloc = FavouriteWallsBloc(fetchUseCase, toggleUseCase, clearUseCase)
      ..add(const FavouriteWallsEvent.started(userId: 'user_1'));
    await bloc.stream.firstWhere((s) => s.status == LoadStatus.success);

    bloc.add(FavouriteWallsEvent.restoreRequested(walls: <FavouriteWallEntity>[prismFav('restored')]));
    await bloc.stream.firstWhere((s) => s.items.isNotEmpty);

    expect(storedParams!.wall.favouritedAt, isNotNull);
    expect(bloc.state.items.single.favouritedAt, storedParams!.wall.favouritedAt);
    await bloc.close();
  });

  test('restoring a favourite keeps its existing timestamp in storage and state', () async {
    when(() => fetchUseCase(any())).thenAnswer((_) async => Result.success(const <FavouriteWallEntity>[]));
    ToggleFavouriteWallParams? storedParams;
    when(() => toggleUseCase(any())).thenAnswer((invocation) async {
      storedParams = invocation.positionalArguments.single as ToggleFavouriteWallParams;
      return Result.success(true);
    });
    final DateTime originalStamp = DateTime.utc(2024, 2, 3);
    final bloc = FavouriteWallsBloc(fetchUseCase, toggleUseCase, clearUseCase)
      ..add(const FavouriteWallsEvent.started(userId: 'user_1'));
    await bloc.stream.firstWhere((s) => s.status == LoadStatus.success);

    bloc.add(
      FavouriteWallsEvent.restoreRequested(
        walls: <FavouriteWallEntity>[prismFav('restored', favouritedAt: originalStamp)],
      ),
    );
    await bloc.stream.firstWhere((s) => s.items.isNotEmpty);

    expect(storedParams!.wall.favouritedAt, originalStamp);
    expect(bloc.state.items.single.favouritedAt, originalStamp);
    await bloc.close();
  });

  test('restoring an old favourite keeps its place by using its own date as the favourite time', () async {
    when(() => fetchUseCase(any())).thenAnswer((_) async => Result.success(const <FavouriteWallEntity>[]));
    ToggleFavouriteWallParams? storedParams;
    when(() => toggleUseCase(any())).thenAnswer((invocation) async {
      storedParams = invocation.positionalArguments.single as ToggleFavouriteWallParams;
      return Result.success(true);
    });
    final bloc = FavouriteWallsBloc(fetchUseCase, toggleUseCase, clearUseCase)
      ..add(const FavouriteWallsEvent.started(userId: 'user_1'));
    await bloc.stream.firstWhere((s) => s.status == LoadStatus.success);
    final DateTime oldDate = DateTime.utc(2021, 2, 3);

    bloc.add(FavouriteWallsEvent.restoreRequested(walls: <FavouriteWallEntity>[prismFav('old', createdAt: oldDate)]));
    await bloc.stream.firstWhere((s) => s.items.isNotEmpty);

    expect(storedParams!.wall.favouritedAt, oldDate);
    expect(bloc.state.items.single.addedAt, oldDate);
    await bloc.close();
  });

  test('undoing an old favourite does not move it ahead of newer favourites', () async {
    final DateTime oldDate = DateTime.utc(2021, 2, 3);
    final FavouriteWallEntity oldWall = prismFav('old', createdAt: oldDate);
    when(() => fetchUseCase(any())).thenAnswer(
      (_) async => Result.success(<FavouriteWallEntity>[prismFav('recent', createdAt: DateTime.utc(2026)), oldWall]),
    );
    final bloc = FavouriteWallsBloc(fetchUseCase, toggleUseCase, clearUseCase)
      ..add(const FavouriteWallsEvent.started(userId: 'user_1'));
    await bloc.stream.firstWhere((s) => s.status == LoadStatus.success);

    bloc.add(const FavouriteWallsEvent.removeRequested(wallIds: <String>['old']));
    await bloc.stream.firstWhere((s) => s.items.length == 1);
    bloc.add(FavouriteWallsEvent.restoreRequested(walls: <FavouriteWallEntity>[oldWall]));
    await bloc.stream.firstWhere((s) => s.items.length == 2);

    expect(applyFavouritesView(bloc.state.items).map((wall) => wall.id), <String>['recent', 'old']);
    expect(bloc.state.items.singleWhere((wall) => wall.id == 'old').favouritedAt, oldDate);
    await bloc.close();
  });
}
