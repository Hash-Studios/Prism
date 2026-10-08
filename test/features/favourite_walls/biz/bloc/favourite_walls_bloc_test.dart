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
}
