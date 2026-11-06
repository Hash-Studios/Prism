// Hash-Studios/Prism#542
import 'dart:async';

import 'package:Prism/core/constants/app_constants.dart' as app_constants;
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/features/favourite_walls/biz/bloc/favourite_walls_bloc.j.dart';
import 'package:Prism/features/favourite_walls/domain/entities/favourite_wall_entity.dart';
import 'package:Prism/features/favourite_walls/domain/usecases/favourite_walls_usecases.dart';
import 'package:Prism/features/favourite_walls/views/favourite_walls_bloc_adapter.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../support/favourite_test_scope.dart';
import 'support/fav_fixtures.dart';

class _MockFetch extends Mock implements FetchFavouriteWallsUseCase {}

class _MockToggle extends Mock implements ToggleFavouriteWallUseCase {}

class _MockClear extends Mock implements ClearFavouriteWallsUseCase {}

class _MockSetFavouritePinUseCase extends Mock implements SetFavouritePinUseCase {}

void main() {
  setUpFavouriteCounts();
  late _MockFetch fetch;
  late _MockToggle toggle;
  late _MockClear clear;
  late FavouriteWallsBloc bloc;
  late FavouriteWallsAdapter adapter;

  setUpAll(() {
    registerFallbackValue(const FetchFavouriteWallsParams(userId: 'u'));
    registerFallbackValue(ToggleFavouriteWallParams(userId: 'u', wall: legacyFav('x'), currentlyFavourited: false));
  });

  setUp(() {
    app_state.prismUser = app_constants.createGuestPrismUser()
      ..id = 'u'
      ..loggedIn = true;
    fetch = _MockFetch();
    toggle = _MockToggle();
    clear = _MockClear();
    when(() => fetch(any())).thenAnswer((_) async => Result.success(<FavouriteWallEntity>[]));
  });

  tearDown(() => app_state.prismUser = app_constants.createGuestPrismUser());

  Future<void> pumpAdapter(WidgetTester tester) async {
    bloc = FavouriteWallsBloc(fetch, toggle, clear, _MockSetFavouritePinUseCase());
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

  testWidgets('a favourite toggle whose use case throws still completes the heart tap', (tester) async {
    when(() => toggle(any())).thenThrow(StateError('boom'));
    await pumpAdapter(tester);

    bool? favourited;
    unawaited(adapter.favCheck(legacyFav('x')).then((bool value) => favourited = value));
    await tester.pump(const Duration(milliseconds: 50));

    expect(favourited, isFalse);
  });
}
