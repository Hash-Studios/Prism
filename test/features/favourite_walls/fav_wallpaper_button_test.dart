import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/constants/app_constants.dart' as app_constants;
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/persistence/data_sources/favorites_local_data_source.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/widgets/animated/favourite_icon.dart';
import 'package:Prism/core/widgets/menu_button/fav_wallpaper_button.dart';
import 'package:Prism/features/favourite_walls/biz/bloc/favourite_walls_bloc.j.dart';
import 'package:Prism/features/favourite_walls/domain/entities/favourite_wall_entity.dart';
import 'package:Prism/features/favourite_walls/domain/usecases/favourite_walls_usecases.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../support/fake_app_analytics.dart';
import '../../support/in_memory_local_store.dart';

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
        wall: LegacyFavouriteWall(id: 'wall_1', source: WallpaperSource.prism, legacyPayload: <String, Object?>{}),
      ),
    );
    registerFallbackValue(const ClearFavouriteWallsParams(userId: 'user_1', wallIds: <String>[]));
  });

  late _MockFetchFavouriteWallsUseCase fetchUseCase;
  late _MockToggleFavouriteWallUseCase toggleUseCase;
  late _MockClearFavouriteWallsUseCase clearUseCase;
  late FakeAppAnalytics recordingAnalytics;

  setUp(() {
    fetchUseCase = _MockFetchFavouriteWallsUseCase();
    toggleUseCase = _MockToggleFavouriteWallUseCase();
    clearUseCase = _MockClearFavouriteWallsUseCase();
    recordingAnalytics = FakeAppAnalytics();
    AnalyticsRuntime.instance = recordingAnalytics;
    when(() => fetchUseCase(any())).thenAnswer((_) async => Result.success(const <FavouriteWallEntity>[]));
    when(() => clearUseCase(any())).thenAnswer((_) async => Result.success(true));
    app_state.prismUser = app_constants.createGuestPrismUser()
      ..id = 'user_1'
      ..loggedIn = true;
    getIt.registerSingleton<FavoritesLocalDataSource>(FavoritesLocalDataSource(InMemoryLocalStore()));
  });

  tearDown(() async {
    AnalyticsRuntime.reset();
    app_state.prismUser = app_constants.createGuestPrismUser();
    await getIt.reset();
  });

  Future<void> tapFavourite(WidgetTester tester, FavouriteWallsBloc bloc) async {
    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider<FavouriteWallsBloc>.value(
          value: bloc,
          child: const Scaffold(
            body: FavouriteWallpaperButton(
              wall: LegacyFavouriteWall(
                id: 'wall_1',
                source: WallpaperSource.prism,
                legacyPayload: <String, Object?>{},
              ),
              trash: false,
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byType(FavoriteIcon));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pumpAndSettle();
  }

  testWidgets('does not track favourite status when the save fails', (tester) async {
    when(() => toggleUseCase(any())).thenAnswer((_) async => Result.error(const ServerFailure('write failed')));
    final bloc = FavouriteWallsBloc(fetchUseCase, toggleUseCase, clearUseCase);
    addTearDown(bloc.close);

    await tapFavourite(tester, bloc);

    expect(recordingAnalytics.events.whereType<FavStatusChangedEvent>(), isEmpty);
  });

  testWidgets('tracks favourite status when the save succeeds', (tester) async {
    when(() => toggleUseCase(any())).thenAnswer((_) async => Result.success(true));
    final bloc = FavouriteWallsBloc(fetchUseCase, toggleUseCase, clearUseCase);
    addTearDown(bloc.close);

    await tapFavourite(tester, bloc);

    expect(recordingAnalytics.events.whereType<FavStatusChangedEvent>(), hasLength(1));
  });
}
