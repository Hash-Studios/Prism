import 'dart:async';

import 'package:Prism/core/constants/app_constants.dart' as app_constants;
import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/features/favourite_walls/biz/bloc/favourite_walls_bloc.j.dart';
import 'package:Prism/features/favourite_walls/domain/entities/favourite_wall_entity.dart';
import 'package:Prism/features/favourite_walls/domain/usecases/favourite_walls_usecases.dart';
import 'package:Prism/features/favourite_walls/views/favourite_walls_bloc_adapter.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'support/fav_fixtures.dart';

class _MockFetch extends Mock implements FetchFavouriteWallsUseCase {}

class _MockToggle extends Mock implements ToggleFavouriteWallUseCase {}

class _MockClear extends Mock implements ClearFavouriteWallsUseCase {}

void main() {
  late _MockFetch fetch;
  late _MockToggle toggle;
  late _MockClear clear;
  late List<FavouriteWallEntity> server;
  late FavouriteWallsBloc bloc;
  late FavouriteWallsAdapter adapter;

  setUpAll(() {
    registerFallbackValue(const FetchFavouriteWallsParams(userId: 'u'));
    registerFallbackValue(ToggleFavouriteWallParams(userId: 'u', wall: legacyFav('x'), currentlyFavourited: false));
    registerFallbackValue(const ClearFavouriteWallsParams(userId: 'u', wallIds: <String>[]));
  });

  setUp(() {
    app_state.prismUser = app_constants.createGuestPrismUser()
      ..id = 'u'
      ..loggedIn = true;
    server = <FavouriteWallEntity>[prismFav('a'), prismFav('b'), prismFav('c')];
    fetch = _MockFetch();
    toggle = _MockToggle();
    clear = _MockClear();
    when(() => fetch(any())).thenAnswer((_) async => Result.success(List<FavouriteWallEntity>.of(server)));
    when(() => toggle(any())).thenAnswer((_) async => Result.success(true));
  });

  tearDown(() => app_state.prismUser = app_constants.createGuestPrismUser());

  Future<void> pumpAdapter(WidgetTester tester) async {
    bloc = FavouriteWallsBloc(fetch, toggle, clear);
    addTearDown(bloc.close);
    await tester.pumpWidget(
      BlocProvider<FavouriteWallsBloc>.value(
        value: bloc,
        child: Builder(
          builder: (BuildContext context) {
            adapter = context.favouriteWallsAdapter(listen: false);
            return const SizedBox();
          },
        ),
      ),
    );
    await adapter.getDataBase();
  }

  testWidgets('a refresh finishing during a slow removal does not report the removal early', (tester) async {
    final Completer<Result<bool>> slowClear = Completer<Result<bool>>();
    when(() => clear(any())).thenAnswer((_) => slowClear.future);
    await pumpAdapter(tester);

    bool? removed;
    unawaited(adapter.removeWalls(<String>['a']).then((bool value) => removed = value));
    await tester.pump();
    bloc.add(const FavouriteWallsEvent.refreshRequested());
    await tester.pump(const Duration(milliseconds: 50));

    expect(removed, isNull);

    server = <FavouriteWallEntity>[prismFav('b'), prismFav('c')];
    slowClear.complete(Result.success(true));
    await tester.pump(const Duration(milliseconds: 50));

    expect(removed, isTrue);
    await tester.pump(const Duration(milliseconds: 50));
    expect(bloc.state.items.map((FavouriteWallEntity wall) => wall.id), <String>['b', 'c']);
    expect(bloc.state.actionStatus, ActionStatus.success);
  });

  testWidgets('a failed removal reports failure even when a refresh finishes first', (tester) async {
    final Completer<Result<bool>> slowClear = Completer<Result<bool>>();
    when(() => clear(any())).thenAnswer((_) => slowClear.future);
    await pumpAdapter(tester);

    bool? removed;
    unawaited(adapter.removeWalls(<String>['a']).then((bool value) => removed = value));
    await tester.pump();
    bloc.add(const FavouriteWallsEvent.refreshRequested());
    await tester.pump(const Duration(milliseconds: 50));
    expect(removed, isNull);

    slowClear.complete(Result.error(const ServerFailure('boom')));
    await tester.pump(const Duration(milliseconds: 50));

    expect(removed, isFalse);
  });

  testWidgets('undo queued behind a pending removal restores the walls that removal drops', (tester) async {
    final Completer<Result<bool>> slowClear = Completer<Result<bool>>();
    when(() => clear(any())).thenAnswer((_) => slowClear.future);
    await pumpAdapter(tester);
    final List<FavouriteWallEntity> walls = <FavouriteWallEntity>[bloc.state.items.first];

    final Future<bool> removal = adapter.removeWalls(<String>[walls.first.id]);
    await tester.pump();
    final Future<bool> undo = adapter.restoreWalls(walls);
    await tester.pump(const Duration(milliseconds: 50));
    verifyNever(() => toggle(any()));

    slowClear.complete(Result.success(true));
    expect(await removal, isTrue);
    expect(await undo, isTrue);

    expect(bloc.state.items.map((FavouriteWallEntity wall) => wall.id), contains(walls.first.id));
    verify(() => toggle(any())).called(1);
  });
}
