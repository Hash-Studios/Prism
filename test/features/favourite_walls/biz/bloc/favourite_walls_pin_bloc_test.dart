import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/features/favourite_walls/biz/bloc/favourite_walls_bloc.j.dart';
import 'package:Prism/features/favourite_walls/domain/entities/favourite_wall_entity.dart';
import 'package:Prism/features/favourite_walls/domain/usecases/favourite_walls_usecases.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../support/fav_fixtures.dart';

class _MockFetchFavouriteWallsUseCase extends Mock implements FetchFavouriteWallsUseCase {}

class _MockToggleFavouriteWallUseCase extends Mock implements ToggleFavouriteWallUseCase {}

class _MockClearFavouriteWallsUseCase extends Mock implements ClearFavouriteWallsUseCase {}

class _MockSetFavouritePinUseCase extends Mock implements SetFavouritePinUseCase {}

void main() {
  setUpAll(() {
    registerFallbackValue(const FetchFavouriteWallsParams(userId: 'user_1'));
    registerFallbackValue(
      ToggleFavouriteWallParams(userId: 'user_1', wall: prismFav('fallback'), currentlyFavourited: false),
    );
    registerFallbackValue(const ClearFavouriteWallsParams(userId: 'user_1', wallIds: <String>['w1']));
    registerFallbackValue(SetFavouritePinParams(userId: 'user_1', wall: prismFav('fallback')));
  });

  late _MockFetchFavouriteWallsUseCase fetchUseCase;
  late _MockToggleFavouriteWallUseCase toggleUseCase;
  late _MockClearFavouriteWallsUseCase clearUseCase;
  late _MockSetFavouritePinUseCase setPinUseCase;

  setUp(() {
    fetchUseCase = _MockFetchFavouriteWallsUseCase();
    toggleUseCase = _MockToggleFavouriteWallUseCase();
    clearUseCase = _MockClearFavouriteWallsUseCase();
    setPinUseCase = _MockSetFavouritePinUseCase();
    // The real use case answers with the new state: a removal says false, a save says true.
    when(() => toggleUseCase(any())).thenAnswer((invocation) async {
      final params = invocation.positionalArguments.first as ToggleFavouriteWallParams;
      return Result.success(!params.currentlyFavourited);
    });
    when(() => clearUseCase(any())).thenAnswer((_) async => Result.success(true));
    when(() => setPinUseCase(any())).thenAnswer((_) async => Result.success(null));
  });

  FavouriteWallsBloc build() => FavouriteWallsBloc(fetchUseCase, toggleUseCase, clearUseCase, setPinUseCase);

  /// A bloc whose list already holds [items], loaded through the fetch use case.
  Future<FavouriteWallsBloc> loaded(List<FavouriteWallEntity> items) async {
    when(() => fetchUseCase(any())).thenAnswer((_) async => Result.success(List<FavouriteWallEntity>.of(items)));
    final FavouriteWallsBloc bloc = build()..add(const FavouriteWallsEvent.started(userId: 'user_1'));
    await bloc.stream.firstWhere((state) => state.status == LoadStatus.success);
    addTearDown(bloc.close);
    return bloc;
  }

  List<FavouriteWallEntity> manyPinned() => <FavouriteWallEntity>[
    for (int i = 0; i < maxPinnedFavourites; i++)
      prismFav('p$i', createdAt: DateTime.utc(2025)).withPinnedAt(DateTime.utc(2026, 1, 1, 0, i)),
  ];

  SetFavouritePinParams lastPin() => verify(() => setPinUseCase(captureAny())).captured.last as SetFavouritePinParams;

  test('pinning a favourite sets pinnedAt and sends a non-null pinnedAt to the use case', () async {
    final FavouriteWallsBloc bloc = await loaded(<FavouriteWallEntity>[prismFav('a')]);

    bloc.add(const FavouriteWallsEvent.pinRequested(wallId: 'a', pinned: true, operationId: 1));
    await bloc.stream.firstWhere((state) => state.completedOperationId == 1);

    expect(bloc.state.actionStatus, ActionStatus.success);
    expect(bloc.state.items.single.id, 'a');
    expect(bloc.state.items.single.pinnedAt, isNotNull);
    expect(bloc.state.items.single.pinned, isTrue);
    final SetFavouritePinParams pin = lastPin();
    expect(pin.wall.id, 'a');
    expect(pin.pinnedAt, isNotNull);
  });

  test('unpinning clears pinnedAt and sends null to the use case', () async {
    final FavouriteWallsBloc bloc = await loaded(<FavouriteWallEntity>[prismFav('a').withPinnedAt(DateTime.utc(2026))]);

    bloc.add(const FavouriteWallsEvent.pinRequested(wallId: 'a', pinned: false, operationId: 1));
    await bloc.stream.firstWhere((state) => state.completedOperationId == 1);

    expect(bloc.state.actionStatus, ActionStatus.success);
    expect(bloc.state.items.single.pinnedAt, isNull);
    expect(lastPin().pinnedAt, isNull);
  });

  test('a 13th pin fails with the limit and never reaches the use case, until one pin is freed', () async {
    final FavouriteWallsBloc bloc = await loaded(<FavouriteWallEntity>[...manyPinned(), prismFav('extra')]);
    expect(bloc.state.pinnedCount, maxPinnedFavourites);

    bloc.add(const FavouriteWallsEvent.pinRequested(wallId: 'extra', pinned: true, operationId: 1));
    await bloc.stream.firstWhere((state) => state.completedOperationId == 1);

    expect(bloc.state.actionStatus, ActionStatus.failure);
    expect(bloc.state.failure, isA<FavouritePinLimitFailure>());
    verifyNever(() => setPinUseCase(any()));
    expect(bloc.state.items.firstWhere((wall) => wall.id == 'extra').pinned, isFalse);

    bloc.add(const FavouriteWallsEvent.pinRequested(wallId: 'p0', pinned: false, operationId: 2));
    await bloc.stream.firstWhere((state) => state.completedOperationId == 2);
    expect(bloc.state.pinnedCount, maxPinnedFavourites - 1);

    bloc.add(const FavouriteWallsEvent.pinRequested(wallId: 'extra', pinned: true, operationId: 3));
    await bloc.stream.firstWhere((state) => state.completedOperationId == 3);

    expect(bloc.state.actionStatus, ActionStatus.success);
    expect(bloc.state.failure, isNull);
    expect(bloc.state.items.firstWhere((wall) => wall.id == 'extra').pinned, isTrue);
    expect(bloc.state.pinnedCount, maxPinnedFavourites);
  });

  test('pinning a wall id that is not in the list fails and does not call the use case', () async {
    final FavouriteWallsBloc bloc = await loaded(<FavouriteWallEntity>[prismFav('a')]);

    bloc.add(const FavouriteWallsEvent.pinRequested(wallId: 'missing', pinned: true, operationId: 1));
    await bloc.stream.firstWhere((state) => state.completedOperationId == 1);

    expect(bloc.state.actionStatus, ActionStatus.failure);
    expect(bloc.state.failure, isA<ValidationFailure>());
    expect(bloc.state.items.map((wall) => wall.id), <String>['a']);
    verifyNever(() => setPinUseCase(any()));
  });

  group('removing a favourite clears its pin', () {
    test('toggleRequested with desired false removes the pinned wall', () async {
      final FavouriteWallsBloc bloc = await loaded(<FavouriteWallEntity>[
        prismFav('a').withPinnedAt(DateTime.utc(2026)),
      ]);

      bloc.add(FavouriteWallsEvent.toggleRequested(wall: prismFav('a'), desired: false, operationId: 1));
      await bloc.stream.firstWhere((state) => state.completedOperationId == 1);

      expect(bloc.state.items, isEmpty);
    });

    test('removeRequested removes the pinned wall', () async {
      final FavouriteWallsBloc bloc = await loaded(<FavouriteWallEntity>[
        prismFav('a').withPinnedAt(DateTime.utc(2026)),
      ]);

      bloc.add(const FavouriteWallsEvent.removeRequested(wallIds: <String>['a'], operationId: 1));
      await bloc.stream.firstWhere((state) => state.completedOperationId == 1);

      expect(bloc.state.items, isEmpty);
    });

    test('favouriting the wall again from a fresh entity brings it back unpinned', () async {
      final FavouriteWallsBloc bloc = await loaded(<FavouriteWallEntity>[
        prismFav('a').withPinnedAt(DateTime.utc(2026)),
      ]);
      bloc.add(FavouriteWallsEvent.toggleRequested(wall: prismFav('a'), desired: false, operationId: 1));
      await bloc.stream.firstWhere((state) => state.completedOperationId == 1);

      bloc.add(FavouriteWallsEvent.toggleRequested(wall: prismFav('a'), desired: true, operationId: 2));
      await bloc.stream.firstWhere((state) => state.completedOperationId == 2);

      expect(bloc.state.items.map((wall) => wall.id), <String>['a']);
      expect(bloc.state.items.single.pinned, isFalse);
    });
  });

  test('restoring a pinned wall after undo brings it back unpinned', () async {
    when(() => fetchUseCase(any())).thenAnswer((_) async => Result.success(const <FavouriteWallEntity>[]));
    final FavouriteWallsBloc bloc = build()..add(const FavouriteWallsEvent.started(userId: 'user_1'));
    await bloc.stream.firstWhere((state) => state.status == LoadStatus.success);
    addTearDown(bloc.close);

    bloc.add(
      FavouriteWallsEvent.restoreRequested(
        walls: <FavouriteWallEntity>[prismFav('a', createdAt: DateTime.utc(2025)).withPinnedAt(DateTime.utc(2026))],
        operationId: 1,
      ),
    );
    await bloc.stream.firstWhere((state) => state.completedOperationId == 1);

    expect(bloc.state.actionStatus, ActionStatus.success);
    expect(bloc.state.items.map((wall) => wall.id), <String>['a']);
    expect(bloc.state.items.single.pinned, isFalse);
    final ToggleFavouriteWallParams restored =
        verify(() => toggleUseCase(captureAny())).captured.last as ToggleFavouriteWallParams;
    expect(restored.wall.pinned, isFalse);
  });

  test('a failed pin write leaves the wall unpinned and reports failure', () async {
    when(() => setPinUseCase(any())).thenAnswer((_) async => Result.error(const ServerFailure('write failed')));
    final FavouriteWallsBloc bloc = await loaded(<FavouriteWallEntity>[prismFav('a')]);

    bloc.add(const FavouriteWallsEvent.pinRequested(wallId: 'a', pinned: true, operationId: 1));
    await bloc.stream.firstWhere((state) => state.completedOperationId == 1);

    expect(lastPin().wall.id, 'a');
    expect(bloc.state.actionStatus, ActionStatus.failure);
    expect(bloc.state.failure, isA<ServerFailure>());
    expect(bloc.state.items.single.pinned, isFalse);
  });
}
