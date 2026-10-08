import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/features/favourite_walls/biz/bloc/favourite_walls_bloc.j.dart';
import 'package:Prism/features/favourite_walls/domain/entities/favourite_wall_entity.dart';
import 'package:Prism/features/favourite_walls/domain/usecases/favourite_walls_usecases.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../support/fav_fixtures.dart';

class _MockFetch extends Mock implements FetchFavouriteWallsUseCase {}

class _MockToggle extends Mock implements ToggleFavouriteWallUseCase {}

class _MockClear extends Mock implements ClearFavouriteWallsUseCase {}

void main() {
  late _MockFetch fetch;
  late _MockToggle toggle;
  late _MockClear clear;
  late List<FavouriteWallEntity> server;

  setUpAll(() {
    registerFallbackValue(const FetchFavouriteWallsParams(userId: 'u'));
    registerFallbackValue(ToggleFavouriteWallParams(userId: 'u', wall: legacyFav('x'), currentlyFavourited: false));
    registerFallbackValue(const ClearFavouriteWallsParams(userId: 'u', wallIds: <String>[]));
  });

  setUp(() {
    server = <FavouriteWallEntity>[
      prismFav('a', author: 'Ada', createdAt: DateTime.utc(2025, 1, 3)),
      pexelsFav('b', author: 'Grace', createdAt: DateTime.utc(2025, 1, 2)),
      wallhavenFav('c', createdAt: DateTime.utc(2025)),
    ];
    fetch = _MockFetch();
    toggle = _MockToggle();
    clear = _MockClear();
    when(() => fetch(any())).thenAnswer((_) async => Result.success(List<FavouriteWallEntity>.of(server)));
    when(() => toggle(any())).thenAnswer((_) async => Result.success(true));
    when(() => clear(any())).thenAnswer((_) async => Result.success(true));
  });

  Future<FavouriteWallsBloc> loaded() async {
    final bloc = FavouriteWallsBloc(fetch, toggle, clear);
    addTearDown(bloc.close);
    bloc.add(const FavouriteWallsEvent.started(userId: 'u'));
    await bloc.stream.firstWhere((state) => state.status == LoadStatus.success);
    return bloc;
  }

  List<String> visible(FavouriteWallsBloc bloc) => bloc.state.visibleItems.map((wall) => wall.id).toList();

  test('sort, source filter and search change the visible items only', () async {
    final bloc = await loaded();
    expect(visible(bloc), <String>['a', 'b', 'c']);

    bloc.add(const FavouriteWallsEvent.sortChanged(sort: FavouriteSort.oldest));
    await bloc.stream.firstWhere((state) => state.sort == FavouriteSort.oldest);
    expect(visible(bloc), <String>['c', 'b', 'a']);

    bloc.add(const FavouriteWallsEvent.sourceFilterChanged(source: WallpaperSource.pexels));
    await bloc.stream.firstWhere((state) => state.sourceFilter == WallpaperSource.pexels);
    expect(visible(bloc), <String>['b']);

    bloc.add(const FavouriteWallsEvent.sourceFilterChanged());
    bloc.add(const FavouriteWallsEvent.queryChanged(query: 'ada'));
    await bloc.stream.firstWhere((state) => state.query == 'ada' && state.sourceFilter == null);
    expect(visible(bloc), <String>['a']);
    expect(bloc.state.items, hasLength(3));
    expect(bloc.state.hasActiveFilter, isTrue);
  });

  test('removeRequested sends one batched clear for the ids and drops them from the list', () async {
    final bloc = await loaded();

    bloc.add(const FavouriteWallsEvent.removeRequested(wallIds: <String>['a', 'c']));
    await bloc.stream.firstWhere((state) => state.actionStatus == ActionStatus.success);

    final params = verify(() => clear(captureAny())).captured.single as ClearFavouriteWallsParams;
    expect(params.wallIds, <String>['a', 'c']);
    expect(bloc.state.items.map((wall) => wall.id), <String>['b']);
    verifyNever(() => toggle(any()));
  });

  test('restoreRequested puts removed walls back in date order', () async {
    final bloc = await loaded();
    final FavouriteWallEntity removed = bloc.state.items.first;
    bloc.add(FavouriteWallsEvent.removeRequested(wallIds: <String>[removed.id]));
    await bloc.stream.firstWhere((state) => state.items.length == 2);

    bloc.add(FavouriteWallsEvent.restoreRequested(walls: <FavouriteWallEntity>[removed]));
    await bloc.stream.firstWhere((state) => state.items.length == 3 && state.actionStatus == ActionStatus.success);

    expect(bloc.state.items.map((wall) => wall.id), <String>['a', 'b', 'c']);
    final params = verify(() => toggle(captureAny())).captured.single as ToggleFavouriteWallParams;
    expect(params.currentlyFavourited, isFalse);
    expect(params.wall.id, 'a');
  });

  test('a failed clear reports failure and refetches the real list', () async {
    when(() => clear(any())).thenAnswer((_) async => Result.error(const ServerFailure('boom')));
    final bloc = await loaded();
    final states = <FavouriteWallsState>[];
    final sub = bloc.stream.listen(states.add);
    addTearDown(sub.cancel);

    bloc.add(const FavouriteWallsEvent.clearRequested());
    await bloc.stream.firstWhere((state) => state.actionStatus == ActionStatus.success);

    expect(states.any((state) => state.actionStatus == ActionStatus.failure), isTrue);
    verify(() => fetch(any())).called(2);
    expect(bloc.state.items, hasLength(3));
  });
}
