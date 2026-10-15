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
import 'package:Prism/core/widgets/glint/glint.dart';
import 'package:Prism/core/widgets/menu_button/fav_wallpaper_button.dart';
import 'package:Prism/features/favourite_walls/biz/bloc/favourite_walls_bloc.j.dart';
import 'package:Prism/features/favourite_walls/data/guest_favourites_store.dart';
import 'package:Prism/features/favourite_walls/domain/entities/favourite_wall_entity.dart';
import 'package:Prism/features/favourite_walls/domain/usecases/favourite_walls_usecases.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../support/fake_app_analytics.dart';
import '../../support/in_memory_local_store.dart';
import 'support/guest_store_fixture.dart';

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
  late FavoritesLocalDataSource favorites;

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
    favorites = FavoritesLocalDataSource(InMemoryLocalStore());
    getIt.registerSingleton<FavoritesLocalDataSource>(favorites);
  });

  final List<MethodCall> toasts = <MethodCall>[];

  setUp(() {
    toasts.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('PonnamKarthik/fluttertoast'),
      (call) async {
        toasts.add(call);
        return true;
      },
    );
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('PonnamKarthik/fluttertoast'),
      null,
    );
    AnalyticsRuntime.reset();
    app_state.prismUser = app_constants.createGuestPrismUser();
    await getIt.reset();
  });

  Future<void> pumpButton(WidgetTester tester, FavouriteWallsBloc bloc, {VoidCallback? onFavourited}) async {
    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider<FavouriteWallsBloc>.value(
          value: bloc,
          child: Scaffold(
            body: FavouriteWallpaperButton(
              wall: const LegacyFavouriteWall(
                id: 'wall_1',
                source: WallpaperSource.prism,
                legacyPayload: <String, Object?>{},
              ),
              trash: false,
              onFavourited: onFavourited,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> tapFavourite(WidgetTester tester, FavouriteWallsBloc bloc, {VoidCallback? onFavourited}) async {
    await pumpButton(tester, bloc, onFavourited: onFavourited);
    await tester.tap(find.byType(FavoriteIcon));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 2));
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

  testWidgets('a tap on an empty heart saves even when the loaded list already holds the wall', (tester) async {
    const wall = LegacyFavouriteWall(id: 'wall_1', source: WallpaperSource.prism, legacyPayload: <String, Object?>{});
    when(() => fetchUseCase(any())).thenAnswer((_) async => Result.success(<FavouriteWallEntity>[wall]));
    var toggleSawFavourite = true;
    when(() => toggleUseCase(any())).thenAnswer((invocation) async {
      final params = invocation.positionalArguments.single as ToggleFavouriteWallParams;
      toggleSawFavourite = params.currentlyFavourited;
      await favorites.setWallFavourite('user_1', 'wall_1', true);
      return Result.success(true);
    });
    final bloc = FavouriteWallsBloc(fetchUseCase, toggleUseCase, clearUseCase);
    addTearDown(bloc.close);

    await tapFavourite(tester, bloc);

    expect(toggleSawFavourite, isFalse);
    expect(favorites.isWallFavourite('user_1', 'wall_1'), isTrue);
  });

  testWidgets('a tap on a filled heart removes it and tracks isFavourite false', (tester) async {
    await favorites.setWallFavourite('user_1', 'wall_1', true);
    var toggleSawFavourite = false;
    when(() => toggleUseCase(any())).thenAnswer((invocation) async {
      final params = invocation.positionalArguments.single as ToggleFavouriteWallParams;
      toggleSawFavourite = params.currentlyFavourited;
      await favorites.setWallFavourite('user_1', 'wall_1', false);
      return Result.success(false);
    });
    final bloc = FavouriteWallsBloc(fetchUseCase, toggleUseCase, clearUseCase);
    addTearDown(bloc.close);
    var callbackCount = 0;

    await tapFavourite(tester, bloc, onFavourited: () => callbackCount++);

    expect(toggleSawFavourite, isTrue);
    expect(callbackCount, 0);
    expect(recordingAnalytics.events.whereType<FavStatusChangedEvent>().single.isFavourite, isFalse);
    expect(find.byType(Glint), findsNothing, reason: 'only a new favourite earns a Glint');
  });

  testWidgets('a new favourite is tracked with isFavourite true and shows a Glint', (tester) async {
    when(() => toggleUseCase(any())).thenAnswer((_) async => Result.success(true));
    final bloc = FavouriteWallsBloc(fetchUseCase, toggleUseCase, clearUseCase);
    addTearDown(bloc.close);
    await pumpButton(tester, bloc);

    await tester.tap(find.byType(FavoriteIcon));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 450));

    expect(recordingAnalytics.events.whereType<FavStatusChangedEvent>().single.isFavourite, isTrue);
    expect(find.byType(Glint), findsOneWidget);
    await tester.pumpAndSettle(const Duration(seconds: 3));
  });

  testWidgets('a second tap within 300 ms is ignored', (tester) async {
    when(() => toggleUseCase(any())).thenAnswer((_) async => Result.success(true));
    final bloc = FavouriteWallsBloc(fetchUseCase, toggleUseCase, clearUseCase);
    addTearDown(bloc.close);
    await pumpButton(tester, bloc);

    await tester.tap(find.byType(FavoriteIcon));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.byType(FavoriteIcon));
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pumpAndSettle(const Duration(seconds: 3));

    verify(() => toggleUseCase(any())).called(1);
  });

  testWidgets('reports a successful add as a new favourite', (tester) async {
    when(() => toggleUseCase(any())).thenAnswer((_) async {
      await favorites.setWallFavourite('user_1', 'wall_1', true);
      return Result.success(true);
    });
    final bloc = FavouriteWallsBloc(fetchUseCase, toggleUseCase, clearUseCase);
    addTearDown(bloc.close);
    var callbackCount = 0;

    await tapFavourite(tester, bloc, onFavourited: () => callbackCount++);

    expect(favorites.isWallFavourite('user_1', 'wall_1'), isTrue);
    expect(callbackCount, 1);
  });

  Future<void> pumpOnTop(WidgetTester tester, FavouriteWallsBloc bloc, {required bool trash}) async {
    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider<FavouriteWallsBloc>.value(
          value: bloc,
          child: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => BlocProvider<FavouriteWallsBloc>.value(
                      value: bloc,
                      child: Scaffold(
                        body: FavouriteWallpaperButton(
                          wall: const LegacyFavouriteWall(
                            id: 'wall_1',
                            source: WallpaperSource.prism,
                            legacyPayload: <String, Object?>{},
                          ),
                          trash: trash,
                        ),
                      ),
                    ),
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(FavoriteIcon));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 2));
  }

  testWidgets('a failed save shows an error toast', (tester) async {
    when(() => toggleUseCase(any())).thenAnswer((_) async => Result.error(const ServerFailure('write failed')));
    final bloc = FavouriteWallsBloc(fetchUseCase, toggleUseCase, clearUseCase);
    addTearDown(bloc.close);

    await tapFavourite(tester, bloc);

    final shown = toasts.where((call) => call.method == 'showToast').map((call) => (call.arguments as Map)['msg']);
    expect(shown, contains("Couldn't update favourites. Try again."));
  });

  testWidgets('trash mode keeps the screen open when the removal fails', (tester) async {
    when(() => toggleUseCase(any())).thenAnswer((_) async => Result.error(const ServerFailure('write failed')));
    final bloc = FavouriteWallsBloc(fetchUseCase, toggleUseCase, clearUseCase);
    addTearDown(bloc.close);

    await pumpOnTop(tester, bloc, trash: true);

    expect(find.byType(FavouriteWallpaperButton), findsOneWidget);
  });

  testWidgets('trash mode closes the screen after the removal succeeds', (tester) async {
    when(() => toggleUseCase(any())).thenAnswer((_) async => Result.success(false));
    final bloc = FavouriteWallsBloc(fetchUseCase, toggleUseCase, clearUseCase);
    addTearDown(bloc.close);

    await pumpOnTop(tester, bloc, trash: true);

    expect(find.byType(FavouriteWallpaperButton), findsNothing);
  });

  group('as a guest', () {
    late GuestFavouritesStore guests;

    setUp(() {
      app_state.prismUser = app_constants.createGuestPrismUser();
      guests = memoryGuestStore();
      getIt.registerSingleton<GuestFavouritesStore>(guests);
      when(() => toggleUseCase(any())).thenAnswer((_) async {
        await favorites.setWallFavourite('', 'wall_1', true);
        return Result.success(true);
      });
    });

    Iterable<Object?> shownToasts() =>
        toasts.where((call) => call.method == 'showToast').map((call) => (call.arguments as Map)['msg']);

    testWidgets('the heart saves without asking for a sign-in', (tester) async {
      final bloc = FavouriteWallsBloc(fetchUseCase, toggleUseCase, clearUseCase);
      addTearDown(bloc.close);

      await tapFavourite(tester, bloc);

      final params = verify(() => toggleUseCase(captureAny())).captured.single as ToggleFavouriteWallParams;
      expect(params.userId, '');
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(BottomSheet), findsNothing);
      expect(recordingAnalytics.events.whereType<FavouriteSavedAsGuestEvent>(), hasLength(1));
      expect(recordingAnalytics.events.whereType<FavStatusChangedEvent>().single.isFavourite, isTrue);
    });

    testWidgets('the third guest save shows the sign-in nudge once', (tester) async {
      await guests.put('a', <String, dynamic>{'id': 'a'});
      await guests.put('b', <String, dynamic>{'id': 'b'});
      await guests.put('wall_1', <String, dynamic>{'id': 'wall_1'});
      final bloc = FavouriteWallsBloc(fetchUseCase, toggleUseCase, clearUseCase);
      addTearDown(bloc.close);

      await tapFavourite(tester, bloc);

      expect(shownToasts(), <Object?>['Sign in to keep your favourites on every device']);
    });

    testWidgets('the second guest save shows no nudge', (tester) async {
      await guests.put('a', <String, dynamic>{'id': 'a'});
      await guests.put('wall_1', <String, dynamic>{'id': 'wall_1'});
      final bloc = FavouriteWallsBloc(fetchUseCase, toggleUseCase, clearUseCase);
      addTearDown(bloc.close);

      await tapFavourite(tester, bloc);

      expect(shownToasts(), isEmpty);
    });
  });
}
