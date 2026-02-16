import 'package:Prism/core/utils/result.dart';
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/features/favourite_walls/domain/entities/favourite_wall_entity.dart';
import 'package:Prism/features/favourite_walls/domain/usecases/favourite_walls_usecases.dart';
import 'package:Prism/features/favourite_walls/presentation/bloc/favourite_walls_bloc.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockFetchFavouriteWallsUseCase extends Mock
    implements FetchFavouriteWallsUseCase {}

class _MockToggleFavouriteWallUseCase extends Mock
    implements ToggleFavouriteWallUseCase {}

class _MockRemoveFavouriteWallUseCase extends Mock
    implements RemoveFavouriteWallUseCase {}

class _MockClearFavouriteWallsUseCase extends Mock
    implements ClearFavouriteWallsUseCase {}

void main() {
  setUpAll(() {
    registerFallbackValue(const FetchFavouriteWallsParams(userId: 'user_1'));
    registerFallbackValue(
      const ToggleFavouriteWallParams(
        userId: 'user_1',
        wall: FavouriteWallEntity(
          id: 'w1',
          provider: 'Prism',
          payload: <String, dynamic>{},
        ),
      ),
    );
    registerFallbackValue(
      const RemoveFavouriteWallParams(userId: 'user_1', wallId: 'w1'),
    );
    registerFallbackValue(const ClearFavouriteWallsParams(userId: 'user_1'));
  });

  late _MockFetchFavouriteWallsUseCase fetchUseCase;
  late _MockToggleFavouriteWallUseCase toggleUseCase;
  late _MockRemoveFavouriteWallUseCase removeUseCase;
  late _MockClearFavouriteWallsUseCase clearUseCase;

  setUp(() {
    fetchUseCase = _MockFetchFavouriteWallsUseCase();
    toggleUseCase = _MockToggleFavouriteWallUseCase();
    removeUseCase = _MockRemoveFavouriteWallUseCase();
    clearUseCase = _MockClearFavouriteWallsUseCase();

    when(() => fetchUseCase(any())).thenAnswer(
      (_) async => Result.success(
        const <FavouriteWallEntity>[
          FavouriteWallEntity(
            id: 'w1',
            provider: 'Prism',
            payload: <String, dynamic>{},
          ),
        ],
      ),
    );

    when(() => toggleUseCase(any())).thenAnswer(
      (_) async => Result.success(
        const <FavouriteWallEntity>[
          FavouriteWallEntity(
            id: 'w1',
            provider: 'Prism',
            payload: <String, dynamic>{},
          ),
          FavouriteWallEntity(
            id: 'w2',
            provider: 'Pexels',
            payload: <String, dynamic>{},
          ),
        ],
      ),
    );

    when(() => removeUseCase(any())).thenAnswer(
      (_) async => Result.success(const <FavouriteWallEntity>[]),
    );

    when(() => clearUseCase(any())).thenAnswer(
      (_) async => Result.success(const <FavouriteWallEntity>[]),
    );
  });

  blocTest<FavouriteWallsBloc, FavouriteWallsState>(
    'loads favourites for user and toggles item',
    build: () => FavouriteWallsBloc(
      fetchUseCase,
      toggleUseCase,
      removeUseCase,
      clearUseCase,
    ),
    act: (bloc) => bloc
      ..add(const FavouriteWallsEvent.started(userId: 'user_1'))
      ..add(
        const FavouriteWallsEvent.toggleRequested(
          wall: FavouriteWallEntity(
            id: 'w2',
            provider: 'Pexels',
            payload: <String, dynamic>{},
          ),
        ),
      ),
    verify: (bloc) {
      expect(bloc.state.status, LoadStatus.success);
      expect(bloc.state.items.length, 2);
      expect(bloc.state.items.last.id, 'w2');
    },
  );
}
