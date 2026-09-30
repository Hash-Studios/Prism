import 'dart:async';

import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/constants/app_constants.dart' as app_constants;
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/core/widgets/home/wallpapers/loading.dart';
import 'package:Prism/core/widgets/sign_in_prompt.dart';
import 'package:Prism/features/favourite_walls/biz/bloc/favourite_walls_bloc.j.dart';
import 'package:Prism/features/favourite_walls/domain/entities/favourite_wall_entity.dart';
import 'package:Prism/features/favourite_walls/domain/usecases/favourite_walls_usecases.dart';
import 'package:Prism/features/favourite_walls/views/pages/favourite_wall_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../support/fake_app_analytics.dart';

class _MockFetchFavouriteWallsUseCase extends Mock implements FetchFavouriteWallsUseCase {}

class _MockToggleFavouriteWallUseCase extends Mock implements ToggleFavouriteWallUseCase {}

class _MockClearFavouriteWallsUseCase extends Mock implements ClearFavouriteWallsUseCase {}

void main() {
  setUpAll(() {
    registerFallbackValue(const FetchFavouriteWallsParams(userId: 'user_1'));
  });

  setUp(() {
    AnalyticsRuntime.instance = FakeAppAnalytics();
  });

  tearDown(() {
    AnalyticsRuntime.reset();
    app_state.prismUser = app_constants.createGuestPrismUser();
  });

  FavouriteWallsBloc createBloc(WidgetTester tester, _MockFetchFavouriteWallsUseCase fetch) {
    final bloc = FavouriteWallsBloc(fetch, _MockToggleFavouriteWallUseCase(), _MockClearFavouriteWallsUseCase());
    addTearDown(bloc.close);
    return bloc;
  }

  testWidgets('signed in: title above the favourites', (tester) async {
    app_state.prismUser = app_constants.createGuestPrismUser()
      ..id = 'user_1'
      ..loggedIn = true;
    final fetch = _MockFetchFavouriteWallsUseCase();
    final pending = Completer<Result<List<FavouriteWallEntity>>>();
    when(() => fetch(any())).thenAnswer((_) => pending.future);
    final bloc = createBloc(tester, fetch);

    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider<FavouriteWallsBloc>.value(value: bloc, child: const FavouriteWallpaperScreen()),
      ),
    );
    await tester.pump();

    expect(find.text('Favourites'), findsOneWidget);
    expect(find.byTooltip('Back'), findsOneWidget);
    expect(find.byType(LoadingCards), findsOneWidget);

    pending.complete(Result.success(const <FavouriteWallEntity>[]));
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('No favourites yet'), findsOneWidget);
  });

  testWidgets('signed out: a sign-in prompt instead of a skeleton that never ends', (tester) async {
    app_state.prismUser = app_constants.createGuestPrismUser();
    final bloc = createBloc(tester, _MockFetchFavouriteWallsUseCase());

    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider<FavouriteWallsBloc>.value(value: bloc, child: const FavouriteWallpaperScreen()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(SignInPrompt), findsOneWidget);
    expect(find.byType(LoadingCards), findsNothing);
  });
}
