import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/constants/app_constants.dart' as app_constants;
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/persistence/data_sources/favorites_local_data_source.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/core/widgets/animated/favourite_icon.dart';
import 'package:Prism/core/widgets/menu_button/fav_wallpaper_button.dart';
import 'package:Prism/core/widgets/prism/prism_toast.dart';
import 'package:Prism/features/category_feed/views/widgets/wallpaper_hold_region.dart';
import 'package:Prism/features/favourite_walls/biz/bloc/favourite_walls_bloc.j.dart';
import 'package:Prism/features/favourite_walls/data/guest_favourites_store.dart';
import 'package:Prism/features/favourite_walls/domain/entities/favourite_wall_entity.dart';
import 'package:Prism/features/favourite_walls/domain/usecases/favourite_walls_usecases.dart';
import 'package:Prism/features/folders/views/widgets/folder_sheet.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/theme/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../support/fake_app_analytics.dart';
import '../../../support/favourite_test_scope.dart';
import '../../../support/in_memory_local_store.dart';
import '../../favourite_walls/support/guest_store_fixture.dart';

class _FetchFavourites extends Mock implements FetchFavouriteWallsUseCase {}

class _ToggleFavourite extends Mock implements ToggleFavouriteWallUseCase {}

class _ClearFavourites extends Mock implements ClearFavouriteWallsUseCase {}

void main() {
  setUpFavouriteCounts();

  testWidgets('a guest heart tap saves in the first frame; holding the heart asks for sign-in without another save', (
    tester,
  ) async {
    app_state.prismUser = app_constants.createGuestPrismUser();
    AnalyticsRuntime.instance = FakeAppAnalytics();
    final local = FavoritesLocalDataSource(InMemoryLocalStore());
    getIt.registerSingleton<FavoritesLocalDataSource>(local);
    getIt.registerSingleton<GuestFavouritesStore>(memoryGuestStore());
    const wall = PrismFavouriteWall(
      id: 'wall',
      wallpaper: PrismWallpaper(
        core: WallpaperCore(id: 'wall', source: WallpaperSource.prism, fullUrl: '', thumbnailUrl: ''),
      ),
    );
    final fetch = _FetchFavourites();
    final toggle = _ToggleFavourite();
    final clear = _ClearFavourites();
    registerFallbackValue(const FetchFavouriteWallsParams(userId: ''));
    registerFallbackValue(const ToggleFavouriteWallParams(userId: '', currentlyFavourited: false, wall: wall));
    when(() => fetch(any())).thenAnswer((_) async => Result.success(const <FavouriteWallEntity>[]));
    when(() => toggle(any())).thenAnswer((_) async {
      await local.setWallFavourite('', 'wall', true);
      return Result.success(true);
    });
    final bloc = FavouriteWallsBloc(fetch, toggle, clear);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('PonnamKarthik/fluttertoast'),
      (_) async => true,
    );
    addTearDown(() async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('PonnamKarthik/fluttertoast'),
        null,
      );
      await bloc.close();
      AnalyticsRuntime.reset();
      app_state.prismUser = app_constants.createGuestPrismUser();
      await getIt.reset();
    });
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: kLightTheme,
        builder: (context, child) => BlocProvider<FavouriteWallsBloc>.value(value: bloc, child: child),
        home: const Scaffold(
          body: Center(child: FavouriteWallpaperButton(wall: wall, trash: false)),
        ),
      ),
    );
    await tester.tap(find.byType(FavoriteIcon));
    await tester.pump();
    expect(local.isWallFavourite('', 'wall'), isTrue);
    expect(find.byType(FolderSheet), findsNothing);
    expect(find.text('Sign in to use folders'), findsNothing);
    verify(() => toggle(any())).called(1);

    await tester.pump(const Duration(seconds: 3));
    await tester.longPress(find.byType(FavoriteIcon));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Sign in to use folders'), findsOneWidget);
    verifyNever(() => toggle(any()));
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('the folder toast action can only open its picker once', (tester) async {
    final key = GlobalKey<NavigatorState>();
    var calls = 0;
    await tester.pumpWidget(MaterialApp(navigatorKey: key, home: const Scaffold()));
    showPrismToast(key.currentState!.overlay!, 'Saved', action: (label: 'Add to folder', onPressed: () => calls++));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Add to folder'));
    await tester.pump();
    await tester.tap(find.text('Add to folder'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(calls, 1);
    expect(find.text('Saved'), findsNothing);
  });

  testWidgets('all five hold actions have distinct targets and Save dispatches once on release', (tester) async {
    final actions = <WallpaperQuickAction>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 160,
              height: 200,
              child: WallpaperHoldRegion(
                identity: 'wall',
                favouriteLabel: 'Favourite',
                shareLabel: 'Share',
                showLessLabel: 'See less',
                resetOriginalLabel: 'Reset',
                saveToFolderLabel: 'Save to folder',
                onAction: actions.add,
                preview: const SizedBox.expand(),
                child: const SizedBox.expand(key: ValueKey<String>('source')),
              ),
            ),
          ),
        ),
      ),
    );
    final gesture = await tester.startGesture(tester.getCenter(find.byKey(const ValueKey<String>('source'))));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(milliseconds: 180));
    final targets = <Rect>[
      for (final label in <String>['Favourite', 'Share', 'See less', 'Reset', 'Save to folder'])
        tester.getRect(find.bySemanticsLabel(label)),
    ];
    for (var i = 0; i < targets.length; i++) {
      for (var j = i + 1; j < targets.length; j++) {
        expect(targets[i].overlaps(targets[j]), isFalse);
      }
    }
    await gesture.moveTo(targets.last.center);
    await tester.pump();
    expect(actions, isEmpty);
    await gesture.up();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 180));
    await tester.pump();
    expect(actions, <WallpaperQuickAction>[WallpaperQuickAction.saveToFolder]);
  });
}
