import 'dart:async';

import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/persistence/data_sources/favorites_local_data_source.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/personalization/taste_signals.dart';
import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/wallpaper_detail/biz/bloc/wallpaper_detail_bloc.dart';
import 'package:Prism/features/wallpaper_detail/biz/bloc/wallpaper_detail_event.dart';
import 'package:Prism/features/wallpaper_detail/biz/bloc/wallpaper_detail_state.dart';
import 'package:Prism/features/wallpaper_detail/views/pages/wallpaper_detail_screen.dart';
import 'package:Prism/features/wallpaper_detail/views/widgets/wallpaper_action_bar.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/favourite_test_scope.dart';
import '../../../../support/in_memory_local_store.dart';

class _DetailBloc extends MockBloc<WallpaperDetailEvent, WallpaperDetailState> implements WallpaperDetailBloc {}

const FeedItemEntity _wall = WallhavenFeedItem(
  id: 'w1',
  wallpaper: WallhavenWallpaper(
    core: WallpaperCore(
      id: 'w1',
      source: WallpaperSource.wallhaven,
      fullUrl: 'https://w.example/full.jpg',
      thumbnailUrl: 'https://w.example/thumb.jpg',
      authorName: 'Ana',
      width: 1080,
      height: 1920,
    ),
    favorites: 136,
  ),
);

void main() {
  setUpFavouriteCounts();
  setUp(() {
    getIt.registerSingleton<FavoritesLocalDataSource>(FavoritesLocalDataSource(InMemoryLocalStore()));
    getIt.registerSingleton<TasteSignalStore>(TasteSignalStore(SettingsLocalDataSource(InMemoryLocalStore())));
  });
  tearDown(() => getIt.reset());

  testWidgets('while Prism confirms the wall, what the tile knew shows at once and the rest crossfades in place', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final StreamController<WallpaperDetailState> states = StreamController<WallpaperDetailState>();
    addTearDown(states.close);
    final bloc = _DetailBloc();
    whenListen(bloc, states.stream, initialState: const WallpaperDetailLoading());
    await tester.pumpWidget(
      MaterialApp(
        builder: favouriteTestBuilder,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: BlocProvider<WallpaperDetailBloc>.value(
          value: bloc,
          child: const WallpaperDetailScreen(entity: _wall),
        ),
      ),
    );

    // First frame: creator, source and favourite count come from the tile, not a skeleton.
    expect(find.text('Ana'), findsOneWidget);
    expect(find.text('Wallhaven'), findsOneWidget);
    expect(find.text('136'), findsOneWidget);
    expect(find.byType(WallpaperActionBar), findsNothing, reason: 'actions wait for the confirmed wall');
    final double nameTop = tester.getRect(find.text('Ana')).top;

    states.add(const WallpaperDetailLoaded(entity: _wall, paletteLoading: false));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    // Mid crossfade both rows are on screen, and nothing under them moved.
    expect(find.byType(WallpaperActionBar), findsOneWidget);
    expect(find.text('136'), findsNWidgets(2));
    expect(tester.getRect(find.text('Ana')).top, nameTop);

    // The screen keeps a spinner going, so step past the crossfade rather than settle.
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('136'), findsOneWidget);
    expect(tester.getRect(find.text('Ana')).top, nameTop);
  });
  testWidgets('opening chrome cannot take taps before the route lands', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final bloc = _DetailBloc();
    whenListen(
      bloc,
      const Stream<WallpaperDetailState>.empty(),
      initialState: const WallpaperDetailLoaded(entity: _wall, paletteLoading: false),
    );
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigator,
        builder: favouriteTestBuilder,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(),
      ),
    );
    unawaited(
      navigator.currentState!.push<void>(
        PageRouteBuilder<void>(
          transitionDuration: const Duration(milliseconds: 260),
          pageBuilder: (_, _, _) => BlocProvider<WallpaperDetailBloc>.value(
            value: bloc,
            child: const WallpaperDetailScreen(entity: _wall),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 40));
    final back = find.byKey(const ValueKey<String>('detail-card-back'));
    expect(back, findsOneWidget);
    expect(back.hitTestable(), findsNothing);

    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
    expect(back.hitTestable(), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
