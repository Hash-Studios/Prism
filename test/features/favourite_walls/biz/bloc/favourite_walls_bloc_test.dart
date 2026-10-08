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
}
