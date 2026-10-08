import 'dart:async';

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
      expect(bloc.state.items.first.id, 'w2');
    },
  );

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
